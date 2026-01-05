import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity/connectivity_service.dart';
import '../features/no_internet/no_internet_screen.dart';

class ConnectivityWrapper extends ConsumerWidget {
  final Widget child;
  final bool showOfflineScreen;

  const ConnectivityWrapper({
    super.key,
    required this.child,
    this.showOfflineScreen = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityState = ref.watch(connectivityProvider);

    if (!connectivityState.isConnected && showOfflineScreen) {
      return const NoInternetScreen();
    }

    return child;
  }
}

