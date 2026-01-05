import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';
import '../connectivity/connectivity_service.dart';
import 'token_refresh_interceptor.dart';

// Helper function to check if error should be retried
bool _shouldRetry(DioException error) {
  // Don't retry on 504 Gateway Timeout - it's a server timeout, not a connection error
  if (error.response?.statusCode == 504) {
    return false;
  }

  // Retry on connection errors, timeouts, and connection reset
  return error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.unknown ||
      (error.error?.toString().contains('Connection reset') ?? false) ||
      (error.error?.toString().contains('SocketException') ?? false);
}

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      // Global timeouts - some admin scraper operations (e.g. importing many chapters)
      // can legitimately take longer than 30 seconds.
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {ApiConstants.contentTypeHeader: ApiConstants.contentTypeJson},
      // Connection pooling settings
      persistentConnection: true,
      followRedirects: true,
      maxRedirects: 5,
    ),
  );

  // Add token refresh interceptor first (handles 401 errors)
  dio.interceptors.add(TokenRefreshInterceptor(dio));

  // Add retry interceptor for connection errors (handles network errors)
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        Logger.debug('Request: ${options.method} ${options.path}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        Logger.debug(
          'Response: ${response.statusCode} ${response.requestOptions.path}',
        );
        return handler.next(response);
      },
      onError: (error, handler) async {
        // Skip retry for 401 errors (handled by token refresh interceptor)
        if (error.response?.statusCode == 401) {
          return handler.next(error);
        }

        // Retry logic for connection errors
        if (_shouldRetry(error)) {
          final retryCount = error.requestOptions.extra['retryCount'] ?? 0;
          if (retryCount < 3) {
            error.requestOptions.extra['retryCount'] = retryCount + 1;

            // Exponential backoff: 1s, 2s, 4s
            final delay = Duration(seconds: 1 << retryCount);
            Logger.info(
              'Retrying request (attempt ${retryCount + 1}/3) after ${delay.inSeconds}s: ${error.requestOptions.path}',
              'ApiService',
            );

            await Future.delayed(delay);

            try {
              final response = await dio.fetch(error.requestOptions);
              return handler.resolve(response);
            } catch (e) {
              // If retry also fails, continue with error
            }
          }
        }

        // Log errors based on severity
        final statusCode = error.response?.statusCode;
        if (statusCode != null && statusCode >= 400 && statusCode < 500) {
          // 4xx errors are client errors (expected in some cases) - log as warning
          Logger.warning(
            'API Client Error ($statusCode): ${error.requestOptions.path}',
            'ApiService',
          );
        } else {
          // 5xx errors and network errors are server/unexpected errors - log as error
          Logger.error(
            'API Error: ${error.message}',
            error,
            error.stackTrace,
            'ApiService',
          );
        }
        return handler.next(error);
      },
    ),
  );

  return dio;
});

class ApiService {
  final Dio _dio;
  final Ref? _ref;

  ApiService(this._dio, [this._ref]);

  // Check connectivity before making requests
  Future<void> _checkConnectivity() async {
    if (_ref != null) {
      final connectivityState = _ref.read(connectivityProvider);
      if (!connectivityState.isConnected) {
        throw ApiException(
          'No internet connection. Please check your network and try again.',
        );
      }
    }
  }

  // Generic GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    await _checkConnectivity();
    try {
      // Merge custom timeout options with default options
      final mergedOptions = (options ?? Options()).copyWith(
        receiveTimeout: options?.receiveTimeout ?? _dio.options.receiveTimeout,
        sendTimeout: options?.sendTimeout ?? _dio.options.sendTimeout,
      );

      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: mergedOptions,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    } on ApiException {
      rethrow;
    }
  }

  // Generic POST request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    await _checkConnectivity();
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    } on ApiException {
      rethrow;
    }
  }

  // Generic PUT request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    await _checkConnectivity();
    try {
      return await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    } on ApiException {
      rethrow;
    }
  }

  // Generic DELETE request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    await _checkConnectivity();
    try {
      return await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    } on ApiException {
      rethrow;
    }
  }

  // Set authorization token
  void setAuthToken(String? token) {
    if (token != null) {
      _dio.options.headers[ApiConstants.authorizationHeader] = 'Bearer $token';
    } else {
      _dio.options.headers.remove(ApiConstants.authorizationHeader);
    }
  }

  // Handle errors
  ApiException _handleError(DioException error) {
    // Check for connection reset or similar errors
    final errorString = error.error?.toString().toLowerCase() ?? '';
    if (errorString.contains('connection reset') ||
        errorString.contains('socketexception') ||
        errorString.contains('connection refused')) {
      return ApiException(
        'Connection lost. The server may be restarting. Please try again in a moment.',
      );
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          'Connection timeout. Please check your internet connection.',
        );
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final responseData = error.response?.data;

        // Try to extract error message from response
        String message = 'An error occurred';
        if (responseData != null) {
          if (responseData is Map) {
            message =
                responseData['message'] ??
                responseData['error'] ??
                responseData['msg'] ??
                'An error occurred';
          } else if (responseData is String) {
            message = responseData;
          }
        }

        // For 401, provide more specific message
        if (statusCode == 401) {
          message =
              message.contains('Invalid') || message.contains('credentials')
              ? message
              : 'Invalid credentials. Please check your email and password.';
        }

        return ApiException(message, statusCode: statusCode);
      case DioExceptionType.cancel:
        return ApiException('Request cancelled');
      case DioExceptionType.unknown:
        // Provide more specific message for connection errors
        if (errorString.contains('connection') ||
            errorString.contains('network')) {
          return ApiException(
            'Network error. Please check your connection and try again.',
          );
        }
        return ApiException('Network error. Please check your connection.');
      default:
        return ApiException('An unexpected error occurred');
    }
  }
}

// Custom exception class for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

final apiServiceProvider = Provider<ApiService>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiService(dio, ref);
});
