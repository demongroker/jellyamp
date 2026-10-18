# Changelog

All notable changes to Jellyamp are documented here, grouped by
**Added / Changed / Fixed / Security**, following [Keep a Changelog](https://keepachangelog.com/).
Tags are semver (`vX.Y.Z`) — the in-app update checker parses them.

## [Unreleased]

## [1.2.2] - 2026-10-17
### Fixed
- **Updater**: installing in-app now requires a published SHA-256. A release
  with no checksum line is refused with a clear message instead of installing
  unverified; the mismatch block is unchanged.
- **Release workflow**: branch pushes can no longer target a `v*` release —
  only tag pushes create/publish one. `contents: write` is scoped to the
  tag-only release jobs, so build jobs run read-only.
- **Desktop assets**: Windows `.msix`/`.zip` now get matching `.sha256` files
  on tag builds, and the release body always carries the `SHA-256:` line the
  in-app updater parses.
- **Version string**: app reports 1.2.2, so the updater stops offering the
  already-installed build.

## [1.2.1] - 2026-10-17
### Changed
- **Branding**: desktop outputs and Linux bundle files renamed `finamp` →
  `jellyamp` — asset names `jellyamp-v<version>-linux-<arch>.tar.gz`,
  `Jellyamp-v<version>-Windows.msix/.zip`, plus the `.desktop` file and the
  metainfo id. Finamp credit and the MPL-2.0 licence are unchanged.
- v1.2.0 release `target_commitish` corrected to `features/jellyamp-1.1`.

## [1.2.0] - 2026-10-16
### Added
- **CI**: every APK build now publishes a matching `<apk>.sha256` alongside the
  APK (workflow artifact and draft release), so a build's checksum always ships
  with it.
- **CI**: healthcheck/test workflow pinned to Flutter **3.44.9** (same as the APK
  build) so formatting and codegen checks agree with the branch.

### Changed
- **UI — clearer seek bar**: the progress slider now uses a 6px rounded track and
  a visible rounded thumb with a soft halo, making it easy to grab and read over
  any artwork.
- **UI — theme consistency**: rounded cards and uniform list-tile padding across
  the library, downloads and queue; matched bottom-nav / side-rail styling;
  consistent progress, scrollbar, icon-button and segmented-button themes.
- **UI — dark mode**: cards lift to `surfaceContainerLow` and the scaffold raises
  off pure black, so surfaces separate instead of blending together.
- **QoL — snappier search**: search debounce tightened 400 ms → 250 ms.

### Fixed
- **Housekeeping/versioning**: `.gitignore` now covers `*.pfx` / `*.p12` / `*.cer`
  in one place, so no signing material can be committed.
- Pre-existing `dart format` and `pubspec.lock` drift on the 1.1 branch, cleared
  under the pinned Flutter 3.44.9 toolchain.

### Notes
- Dynamic colour from album art, mini-player swipe-to-skip, the sleep timer and
  the downloaded-track indicator were already present in 1.1 and were deliberately
  left as-is rather than duplicated.

## [1.0.0] - 2026-08-16
### Added
- **Core hardening milestone** — completes the P0 power-user audit:
  - `downloaded:true/false` search filter (via the download store)
  - Album quality semantics — an album matches `codec:`/`bit:` only when ALL its tracks do
  - Transcoding explanation — track sheet shows source → output → reason
  - Search result limits ("View all N") + stale-query auto-dispose
### Fixed
- Search `codec:`/`bit:`/`year:` filters now work (were reading missing MediaSources/ProductionYear fields)

## [0.9.37] - 2026-08-16
### Security
- SHA-256 verification before install (checksum published in the release body)
- Exact APK asset selection (`jellyamp-<version>.apk`) instead of "first *.apk"
- Human-readable update errors

## [0.9.36] - 2026-08-16
### Added
- Unified grouped search (Artists/Albums/Tracks/Playlists/Genres) + query syntax
- ROADMAP.md + CHANGELOG.md

## [0.9.35] - 2026-08-16
### Added
- Remember the last Jellyfin server URL across launches
### Fixed
- Update banner overlapping the Home tab
- Gradle daemon 2nd-build crash (raised metaspace to 1G)

## [0.9.34] - 2026-08-16
### Added
- System notification when a new version is available
- Release note shown in-app under the version line

## [0.9.33] - 2026-08-15
### Added
- "Clear After Current" queue action

## [0.9.32] - 2026-08-15
### Changed
- Update banner moved onto the Home screen (was hidden in Settings)

## [0.9.31] - 2026-08-15
### Added
- Undo after removing a track from the queue

## [0.9.30] - 2026-08-15
### Added
- In-app APK download + install (no browser)

## [0.9.29] - 2026-08-15
### Added
- Track info sheet (codec, bitrate, bit depth, sample rate, channels, container, file size, path, server)
- Direct Play / Direct Streaming / Transcoding distinction on the Now Playing chip
- Year + Rating sort options for Albums and Tracks
### Fixed
- Stray `static` breaking release builds
- SDK floor raised to Dart 3.7 (upstream wildcard `_` params)

## [0.9.28-ice-glass] - 2026-08-12
### Added
- Ice liquid-glass theme (charcoal base + ice-cyan accent)
- Jellyamp logo + launcher assets; APK size reduction

## [0.9.27-icon-fix] - 2026-08-12
### Fixed
- Launcher icon

## [0.9.26-jellyamp-ui] - 2026-08-12
### Changed
- Home / UI polish

## [0.9.25] - 2026-08-12 (rebrand baseline)
### Added
- Rebrand Finamp → Jellyamp (`com.demongroker.jellyamp`, `Jellyamp` client header)
- Share original FLAC audio; share / copy Jellyfin link and "Artist — Title"
- Long-press / double-tap seek gestures
- Share APK over Wi-Fi
### Security
- Privacy build: no storage/media/camera/location runtime prompts; app-private downloads; `allowBackup=false`
