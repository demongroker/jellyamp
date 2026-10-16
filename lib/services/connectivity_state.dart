import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// P0.3 step 7 - explicit ONLINE / DEGRADED / OFFLINE connectivity state.
///
/// Jellyamp needs to explicitly understand its connectivity so it can (a) keep
/// the app usable when the server is unreachable, and (b) tell the user once,
/// subtly, instead of flooding screens with error dialogs and retry popups.
///
/// The three states:
///
/// * [ConnectivityState.online]  - server communication operating normally.
/// * [ConnectivityState.degraded] - server is technically reachable but normal
///   operation is unreliable (elevated request-failure rate, intermittent
///   connectivity, selected endpoints failing). Local data is usable while
///   remote refresh cannot reliably complete.
/// * [ConnectivityState.offline] - Jellyfin cannot currently be reached. The
///   app falls back to local (downloaded) state.
///
/// This is an *observational/derived* layer built on top of the signals that
/// already exist in the codebase:
///
/// 1. The manual / auto "Offline Mode" toggle ([FinampSettings.isOffline],
///    driven by `network_manager.dart`). When it is true, we are offline.
/// 2. The platform network-interface state from `connectivity_plus`
///    (the same package `network_manager.dart` already uses).
/// 3. Real server request outcomes, recorded by `ServerRequestSignals` from the
///    single choke point `JellyfinApiHelper.runInIsolate`.
///
/// It does NOT reinvent the existing Offline Mode toggle; it composes with it.
enum ConnectivityState { online, degraded, offline }

final Logger _connectivityLogger = Logger("Connectivity State");

/// Minimum number of CONSECUTIVE failed server requests (with NO success in the
/// whole rolling window) before we classify the server as unreachable -> OFFLINE.
///
/// Deliberately conservative to stop FALSE-OFFLINE (post-1.1 user report). This
/// is a *sustained* verdict, not a transient one: a genuinely-online user hits
/// short failure runs all the time (a slow/unreachable endpoint, a few timeouts
/// during a sync pass, selected endpoints failing - the roadmap DEGRADED case).
/// Those are a handful of failures. We only call OFFLINE when the ENTIRE rolling
/// window is failures (`allRecentFailed`, which already requires ~40 consecutive
/// failures to age any success out of the window) AND at least this many
/// consecutive failures have piled up - the latter matters for a partially
/// filled window, e.g. a server that is down right at startup. 20 consecutive
/// failures with zero recent success is far beyond any transient blip, yet a
/// truly-down server (connection-refused / immediate rejects) accumulates them
/// quickly, so real-offline fallback is not meaningfully delayed.
const int offlineFailureThreshold = 20;

/// Fraction of the recent request window that must have failed (while at least
/// one request succeeded) before we classify operation as DEGRADED.
const double degradedFailureRate = 0.5;

/// How many recent request outcomes we keep in the rolling window.
const int requestSignalWindowSize = 40;

// ---------------------------------------------------------------------------
// Signal 1: platform network-interface presence (from connectivity_plus).
// ---------------------------------------------------------------------------

final StreamController<List<ConnectivityResult>> _interfaceController =
    StreamController<List<ConnectivityResult>>.broadcast();

List<ConnectivityResult> _lastInterfaceResults = <ConnectivityResult>[];

StreamSubscription<List<ConnectivityResult>>? _interfaceSubscription;

/// Whether the device currently has no usable network interface at all.
bool get networkInterfaceDown => _lastInterfaceResults.contains(ConnectivityResult.none);

/// Starts (once) listening to `connectivity_plus`. Seeded with the current
/// state so a provider can read a value on its first build.
void _startInterfaceListening() {
  if (_interfaceSubscription != null) return;
  _interfaceSubscription = Connectivity().onConnectivityChanged.listen((results) {
    _lastInterfaceResults = results;
    _interfaceController.add(results);
    _connectivityLogger.fine("Network interface changed: $results");
  });
  Connectivity()
      .checkConnectivity()
      .then((results) {
        _lastInterfaceResults = results;
        _interfaceController.add(results);
      })
      .catchError((Object e) {
        _connectivityLogger.warning("connectivity_plus checkConnectivity failed", e);
      });
}

/// Stream of network-interface changes. Watching this rebuilds dependents.
final connectivityInterfaceProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  _startInterfaceListening();
  return _interfaceController.stream;
});

// ---------------------------------------------------------------------------
// Signal 2: real server request outcomes.
// ---------------------------------------------------------------------------

/// Rolling record of the outcome of individual server requests. Fed from
/// `JellyfinApiHelper.runInIsolate` (the single choke point for library API
/// traffic). Kept deliberately small and dependency-free.
class ServerRequestSignals {
  ServerRequestSignals._();
  static final ServerRequestSignals instance = ServerRequestSignals._();

  final List<bool> _successes = <bool>[];
  final List<bool> _timeouts = <bool>[];
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Records one request outcome. `timeout` is only meaningful when `success`
  /// is false, and indicates the failure was a timeout rather than an
  /// immediate rejection (used as a secondary, qualitative signal).
  void record({required bool success, required bool timeout}) {
    _successes.add(success);
    _timeouts.add(success ? false : timeout);
    if (_successes.length > requestSignalWindowSize) {
      _successes.removeAt(0);
      _timeouts.removeAt(0);
    }
    _changes.add(null);
  }

  Stream<void> get changes => _changes.stream;

  int get windowSize => _successes.length;

  int get failures => _successes.where((e) => !e).length;

  int get successes => _successes.length - failures;

  double get failureRate => _successes.isEmpty ? 0 : failures / _successes.length;

  /// True if any request in the window succeeded (the server was reachable at
  /// least once recently). This is what separates DEGRADED from OFFLINE.
  bool get hasRecentSuccess => _successes.contains(true);

  /// True if every request in the window failed (server likely unreachable).
  bool get allRecentFailed => _successes.isNotEmpty && !_successes.contains(true);

  /// Number of trailing request outcomes that are failures, i.e. how long the
  /// server has been failing with no success in between. This is what separates
  /// a transient blip (a handful of failures) from sustained unreachability.
  int get consecutiveFailures {
    var count = 0;
    for (var i = _successes.length - 1; i >= 0; i--) {
      if (_successes[i]) break;
      count++;
    }
    return count;
  }

  /// Clears all recorded outcomes. Test-only: lets a test drive the notifier /
  /// [classifyConnectivity] from a clean slate within one process.
  @visibleForTesting
  void reset() {
    _successes.clear();
    _timeouts.clear();
    _changes.add(null);
  }
}

/// Stream of server-request signal changes. Watching this rebuilds dependents.
final serverRequestSignalsProvider = StreamProvider<void>((ref) => ServerRequestSignals.instance.changes);

// ---------------------------------------------------------------------------
// Pure classification (top-level so it is directly unit-testable).
// ---------------------------------------------------------------------------

/// Pure classification of request-signal state into ONLINE / DEGRADED /
/// OFFLINE, factoring out the manual-offline and network-interface signals the
/// notifier already holds. No Riverpod / global-state deps, so it can be driven
/// directly from a test by recording outcomes on [ServerRequestSignals].
///
/// Decision order:
/// 1. Manual offline choice -> OFFLINE (authoritative, never overridden).
/// 2. No usable network interface -> OFFLINE.
/// 3. No requests observed yet (e.g. startup) -> ONLINE (assume healthy).
/// 4. Whole rolling window failed AND >= [offlineFailureThreshold] consecutive
///    failures -> OFFLINE (sustained unreachability; conservative, see the
///    constant for the false-OFFLINE rationale).
/// 5. At least one recent success but an elevated failure rate -> DEGRADED
///    (server reachable but unreliable - the roadmap case).
/// 6. Otherwise -> ONLINE.
ConnectivityState classifyConnectivity(
  ServerRequestSignals signals, {
  required bool networkInterfaceDown,
  required bool manualOffline,
}) {
  // Manual offline choice is authoritative.
  if (manualOffline) return ConnectivityState.offline;
  // No usable network interface at all -> offline.
  if (networkInterfaceDown) return ConnectivityState.offline;
  // No requests observed yet (e.g. at startup) -> assume online.
  if (signals.windowSize == 0) return ConnectivityState.online;
  // All recent requests failed with no recent success -> server unreachable.
  // Conservative: needs the WHOLE window to be failures (so any recent success
  // ages out slowly) AND >= offlineFailureThreshold consecutive failures. A
  // reachable-but-flaky server (roadmap DEGRADED) never trips this while a
  // success is still in the window; a truly-down server hits it quickly.
  if (signals.allRecentFailed && signals.consecutiveFailures >= offlineFailureThreshold) {
    return ConnectivityState.offline;
  }
  // At least one recent success but an elevated failure rate -> reachable but
  // unreliable.
  if (signals.hasRecentSuccess && signals.failureRate >= degradedFailureRate) {
    return ConnectivityState.degraded;
  }
  return ConnectivityState.online;
}

// ---------------------------------------------------------------------------
// The authoritative state.
// ---------------------------------------------------------------------------

/// Single source of truth for connectivity state. Every screen / widget that
/// cares about connectivity should read [connectivityStateProvider].
class ConnectivityStateNotifier extends Notifier<ConnectivityState> {
  // True when *we* auto-engaged the Offline Mode setting based on signals this
  // session. Lets us recover automatically when the server returns, without
  // ever overriding a user's manual Offline Mode choice.
  bool _autoEngagedOffline = false;
  bool _listening = false;

  @override
  ConnectivityState build() {
    // Recompute whenever any raw signal changes.
    ref.watch(connectivityInterfaceProvider);
    ref.watch(serverRequestSignalsProvider);
    ref.watch(finampSettingsProvider);

    if (!_listening) {
      _listening = true;
      listenSelf((ConnectivityState? previous, ConnectivityState next) {
        if (previous != next) _reconcileOfflineSetting(previous!, next);
      });
    }

    final state = _computeState();
    _connectivityLogger.fine("Connectivity state -> $state (autoEngagedOffline=$_autoEngagedOffline)");
    return state;
  }

  ConnectivityState _computeState() {
    final signals = ServerRequestSignals.instance;
    final isOfflineSetting = FinampSettingsHelper.finampSettings.isOffline;

    // The Offline Mode setting (manual toggle, or the existing auto-offline
    // automation from network_manager.dart) is authoritative -- unless we
    // auto-engaged it ourselves from signals, in which case it is just our own
    // echo and we should let the real signal determine the state so we can
    // recover automatically.
    final manualOffline = isOfflineSetting && !_autoEngagedOffline;

    return classifyConnectivity(signals, networkInterfaceDown: networkInterfaceDown, manualOffline: manualOffline);
  }

  /// Drives the Offline Mode setting so the rest of the app actually falls
  /// back to local state, without fighting the existing auto-offline
  /// automation (which owns [FinampSettings.isOffline] when enabled).
  void _reconcileOfflineSetting(ConnectivityState previous, ConnectivityState next) {
    // If the user has the existing auto-offline automation enabled, let it own
    // the isOffline setting (it already confirms and flips it).
    final autoOfflineEnabled =
        FinampSettingsHelper.finampSettings.autoOffline != AutoOfflineOption.disabled &&
        FinampSettingsHelper.finampSettings.autoOfflineListenerActive;
    if (autoOfflineEnabled) return;

    if (next == ConnectivityState.offline && !_autoEngagedOffline && !FinampSettingsHelper.finampSettings.isOffline) {
      // Server unreachable (not a manual offline choice) -> auto fall back to
      // local state. The rest of the app already reads isOffline to switch to
      // the downloaded library.
      _connectivityLogger.info("Auto-engaging Offline Mode (server unreachable).");
      _autoEngagedOffline = true;
      FinampSetters.setIsOffline(true);
    } else if (next == ConnectivityState.online && _autoEngagedOffline) {
      // Server is back and we auto-engaged earlier -> recover automatically.
      _connectivityLogger.info("Auto-disabling Offline Mode (server reachable again).");
      _autoEngagedOffline = false;
      FinampSetters.setIsOffline(false);
    }
  }
}

final connectivityStateProvider = NotifierProvider<ConnectivityStateNotifier, ConnectivityState>(
  ConnectivityStateNotifier.new,
);
