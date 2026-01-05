import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/logger.dart';

class ConnectivityState {
  final bool isConnected;
  final ConnectivityResult connectivityResult;

  ConnectivityState({
    required this.isConnected,
    required this.connectivityResult,
  });

  ConnectivityState copyWith({
    bool? isConnected,
    ConnectivityResult? connectivityResult,
  }) {
    return ConnectivityState(
      isConnected: isConnected ?? this.isConnected,
      connectivityResult: connectivityResult ?? this.connectivityResult,
    );
  }
}

class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _subscription;

  ConnectivityNotifier() : super(ConnectivityState(
    isConnected: true, // Assume connected initially
    connectivityResult: ConnectivityResult.none,
  )) {
    _init();
  }

  Future<void> _init() async {
    try {
      // Check initial connectivity
      final result = await _connectivity.checkConnectivity();
      _updateConnectivity(result);

      // Listen to connectivity changes
      _subscription = _connectivity.onConnectivityChanged.listen(
        _updateConnectivity,
        onError: (error) {
          Logger.error('Connectivity error', error, null, 'ConnectivityNotifier');
        },
      );
    } catch (e) {
      Logger.error('Failed to initialize connectivity', e, null, 'ConnectivityNotifier');
    }
  }

  void _updateConnectivity(ConnectivityResult result) {
    final isConnected = result != ConnectivityResult.none;

    state = ConnectivityState(
      isConnected: isConnected,
      connectivityResult: result,
    );

    Logger.info(
      'Connectivity changed: ${isConnected ? "Connected" : "Disconnected"} ($result)',
      'ConnectivityNotifier',
    );
  }

  Future<bool> checkConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final isConnected = result != ConnectivityResult.none;
      
      state = state.copyWith(
        isConnected: isConnected,
        connectivityResult: result,
      );
      
      return isConnected;
    } catch (e) {
      Logger.error('Failed to check connectivity', e, null, 'ConnectivityNotifier');
      return false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, ConnectivityState>((ref) {
  return ConnectivityNotifier();
});

