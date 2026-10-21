import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityProvider extends ChangeNotifier {
  ConnectivityProvider() {
    _init();
  }

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _debounce;

  bool _isOnline = true;
  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  DateTime? _lastOnlineAt;
  DateTime? get lastOnlineAt => _lastOnlineAt;

  VoidCallback? onWentOnline;

  VoidCallback? onWentOffline;

  Future<void> _init() async {
    final results = await _connectivity.checkConnectivity();
    _updateFromResults(results, immediate: true);

    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) => _updateFromResults(results, immediate: false),
    );
  }

  void _updateFromResults(
    List<ConnectivityResult> results, {
    bool immediate = false,
  }) {
    if (immediate) {
      _applyResults(results);
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 500),
      () => _applyResults(results),
    );
  }

  void _applyResults(List<ConnectivityResult> results) {
    final online = results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);

    if (online == _isOnline) return;

    final wasOffline = !_isOnline;
    _isOnline = online;

    if (online) {
      _lastOnlineAt = DateTime.now();
    }

    notifyListeners();

    if (wasOffline && online) {
      debugPrint('Connectivity restored');
      onWentOnline?.call();
    } else if (!wasOffline && !online) {
      debugPrint('Connectivity lost');
      onWentOffline?.call();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}