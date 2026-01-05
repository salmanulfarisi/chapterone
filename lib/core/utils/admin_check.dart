import '../../features/auth/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool isAdmin(WidgetRef ref) {
  final authState = ref.read(authProvider);
  return authState.user?.isAdmin ?? false;
}

bool isModerator(WidgetRef ref) {
  final authState = ref.read(authProvider);
  return authState.user?.isModerator ?? false;
}

