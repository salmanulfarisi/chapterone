import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';
import '../api/api_service.dart';

class BackendHealthState {
  final bool isOnline;
  final DateTime? lastChecked;
  final String? error;

  BackendHealthState({
    required this.isOnline,
    this.lastChecked,
    this.error,
  });

  BackendHealthState copyWith({
    bool? isOnline,
    DateTime? lastChecked,
    String? error,
  }) {
    return BackendHealthState(
      isOnline: isOnline ?? this.isOnline,
      lastChecked: lastChecked ?? this.lastChecked,
      error: error ?? this.error,
    );
  }
}

class BackendHealthNotifier extends StateNotifier<BackendHealthState> {
  final Dio _dio;

  BackendHealthNotifier(this._dio)
      : super(BackendHealthState(isOnline: true)) {
    // Don't block initialization - check health asynchronously
    checkHealth().catchError((error) {
      // Silently handle errors during initialization
      Logger.warning(
        'Initial health check failed: ${error.toString()}',
        'BackendHealthNotifier',
      );
      return false;
    });
  }

  Future<bool> checkHealth() async {
    try {
      // Try a simple GET to a lightweight endpoint (or health endpoint if you have one)
      // Using /manga with limit=1 as a lightweight check
      // Increased timeout to 30 seconds for slower connections
      final response = await _dio.get(
        ApiConstants.mangaList,
        queryParameters: {'limit': '1'},
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final isOnline = response.statusCode != null && response.statusCode! < 500;
      state = BackendHealthState(
        isOnline: isOnline,
        lastChecked: DateTime.now(),
        error: isOnline ? null : 'Backend returned ${response.statusCode}',
      );

      return isOnline;
    } on DioException catch (e) {
      final isOnline = false;
      final error = e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.connectionError
          ? 'Backend is offline or unreachable'
          : 'Backend error: ${e.message}';

      state = BackendHealthState(
        isOnline: isOnline,
        lastChecked: DateTime.now(),
        error: error,
      );

      Logger.warning('Backend health check failed: $error', 'BackendHealthNotifier');
      return false;
    } catch (e) {
      state = BackendHealthState(
        isOnline: false,
        lastChecked: DateTime.now(),
        error: 'Unexpected error: ${e.toString()}',
      );
      return false;
    }
  }
}

final backendHealthProvider =
    StateNotifierProvider<BackendHealthNotifier, BackendHealthState>((ref) {
  final dio = ref.watch(dioProvider);
  return BackendHealthNotifier(dio);
});

