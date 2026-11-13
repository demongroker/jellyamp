package com.unicornsonlsd.finamp

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.util.Log
import android.util.LruCache
import androidx.core.net.toUri
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.File
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.IOException
import java.net.URL

class MediaItemContentProvider : ContentProvider() {

    private val coroutineScope = CoroutineScope(Dispatchers.Default)

    private lateinit var memoryCache: LruCache<String, ByteArray>

    /**
     * Security (audit J-P0-2): this provider is exported, so every app on the phone can call it.
     * Before this guard it (a) opened ANY app-private path read-only and (b) fetched ANY URL into
     * its cache — i.e. arbitrary local file read plus SSRF from the app's network identity.
     * Now a local path must resolve inside an allowed media directory, and a remote URL must be
     * https (or an explicit private/loopback host, for people running Jellyfin on their LAN) and
     * stay under a size cap instead of being read into memory unbounded.
     */
    private val maxRemoteBytes = 16L * 1024 * 1024

    private fun allowedLocalRoots(): List<String> {
        val ctx = context ?: return emptyList()
        return listOfNotNull(
            ctx.filesDir?.resolve("images"),
            ctx.filesDir?.resolve("downloads"),
            ctx.cacheDir?.resolve("images"),
            ctx.getExternalFilesDir(null)?.resolve("images"),
            ctx.getExternalFilesDir(null)?.resolve("downloads"),
        ).map { dir -> runCatching { dir.canonicalPath }.getOrElse { dir.absolutePath } }
    }

    private fun localFileOrNull(path: String?): File? {
        if (path.isNullOrBlank()) return null
        val f = runCatching { File(path).canonicalFile }.getOrNull() ?: return null
        val canonical = f.canonicalPath
        val allowed = allowedLocalRoots().any { root ->
            canonical == root || canonical.startsWith(root + File.separator)
        }
        if (!allowed) {
            Log.w("MediaItemContentProvider", "refused local read outside allowed dirs")
            return null
        }
        return f.takeIf { it.isFile }
    }

    private fun remoteAllowed(u: String): Boolean {
        val parsed = runCatching { URL(u) }.getOrNull() ?: return false
        val scheme = parsed.protocol.lowercase()
        if (scheme == "https") return true
        if (scheme != "http") return false
        // Plain http only for an explicit private/loopback literal (house LAN server).
        val host = parsed.host.orEmpty()
        return host == "localhost" || host.startsWith("127.") || host.startsWith("10.") ||
            host.startsWith("192.168.") || Regex("""^172\.(1[6-9]|2\d|3[01])\.""").containsMatchIn(host)
    }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor? {
        val fragment = uri.encodedFragment
        if (fragment != null) {
            // We store the original scheme://host in fragment since it should be unused
            val origin = fragment.toUri()
            val fixedUri = uri.buildUpon()
                .fragment(null)
                .scheme(origin.scheme)
                .encodedAuthority(origin.encodedAuthority)
                .toString()

            // Check if we already cached the image
            val bytes = memoryCache.get(fixedUri)
            if (bytes != null) {
                return openSafePipeHelper(
                    uri,
                    "application/octet-stream",
                    null,
                    bytes,
                ) { output, _, _, _, b ->
                    FileOutputStream(output.fileDescriptor).write(b)
                }
            }

            if (!remoteAllowed(fixedUri)) {
                Log.w("MediaItemContentProvider", "refused remote fetch (scheme/host)")
                throw FileNotFoundException("host not allowed")
            }
            val response = URL(fixedUri).openConnection().run {
                connectTimeout = 15_000
                readTimeout = 30_000
                val len = contentLengthLong
                if (len > maxRemoteBytes) throw FileNotFoundException("remote file too large")
                inputStream.use { it.readBytes().also { b ->
                    if (b.size > maxRemoteBytes) throw FileNotFoundException("remote file too large")
                } }
            }
            memoryCache.put(fixedUri, response)
            return openSafePipeHelper(
                uri,
                "application/octet-stream",
                null,
                response,
            ) { output, _, _, _, b ->
                FileOutputStream(output.fileDescriptor).write(b)
            }
        }

        // this means it's a local image (downloaded or placeholder art)
        val file = localFileOrNull(uri.path) ?: throw FileNotFoundException("path not allowed")
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun onCreate(): Boolean {
        // Get max available VM memory, exceeding this amount will throw an
        // OutOfMemory exception. Stored in kilobytes as LruCache takes an
        // int in its constructor.
        val maxMemory = (Runtime.getRuntime().maxMemory() / 1024).toInt()

        // Use 1/8th of the available memory for this memory cache.
        val cacheSize = maxMemory / 8
        memoryCache = object : LruCache<String, ByteArray>(cacheSize) {

            override fun sizeOf(key: String, value: ByteArray): Int {
                // The cache size will be measured in kilobytes rather than
                // number of items.
                return value.size / 1024
            }
        }

        return true
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? {
        return null
    }

    override fun getType(uri: Uri): String? {
        return null
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? {
        return null
    }

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int {
        return 0
    }

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int {
        return 0
    }

    /**
     * Own implementation of [openPipeHelper].
     *
     * Differs from the framework implementation in that it has an additional try/catch block
     * around the writeDataToPipe call.
     *
     * This is to catch the EPIPE (Broken pipe) error that can occur
     * when writing large files (like GIF cover arts) to the pipe.
     */
    private fun <T> openSafePipeHelper(
        uri: Uri,
        mimeType: String,
        opts: Bundle? = null,
        args: T?,
        func: PipeDataWriter<T>,
    ): ParcelFileDescriptor = try {
        val (read, write) = ParcelFileDescriptor.createPipe()

        coroutineScope.launch(Dispatchers.IO) {
            try {
                func.writeDataToPipe(write, uri, mimeType, opts, args)
            } catch (e: IOException) {
                Log.e(TAG, "Failure writing to pipe", e)
            }
            try {
                write.close()
            } catch (e: IOException) {
                Log.w(TAG, "Failure closing pipe", e)
            }
        }

        read
    } catch (e: IOException) {
        throw FileNotFoundException("failure making pipe")
    }

    companion object {
        private const val TAG = "MediaItemCP"
    }
}
