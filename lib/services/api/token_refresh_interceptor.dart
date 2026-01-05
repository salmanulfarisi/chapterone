import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../storage/storage_service.dart';

/// Interceptor that automatically refreshes expired tokens
class TokenRefreshInterceptor extends Interceptor {
  final Dio _dio;
  bool _isRefreshing = false;
  final List<_PendingRequest> _pendingRequests = [];

  TokenRefreshInterceptor(this._dio);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Only handle 401 Unauthorized errors
    if (err.response?.statusCode == 401) {
      // Don't retry refresh token endpoint itself
      if (err.requestOptions.path == ApiConstants.refreshToken) {
        return handler.next(err);
      }

      // If we're already refreshing, queue this request
      if (_isRefreshing) {
        _pendingRequests.add(_PendingRequest(err.requestOptions, handler));
        return;
      }

      _isRefreshing = true;

      try {
        // Attempt to refresh token
        final refreshToken = StorageService.getRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) {
          _isRefreshing = false;
          _rejectPendingRequests(err);
          return handler.next(err);
        }

        // Call refresh token endpoint
        final refreshResponse = await _dio.post(
          ApiConstants.refreshToken,
          data: {'refreshToken': refreshToken},
        );

        final newToken = refreshResponse.data['token'];
        if (newToken != null && newToken is String) {
          // Save new token
          await StorageService.saveAuthToken(newToken);
          
          // Update the original request with new token
          err.requestOptions.headers[ApiConstants.authorizationHeader] =
              'Bearer $newToken';

          // Retry the original request
          try {
            final response = await _dio.fetch(err.requestOptions);
            _isRefreshing = false;
            _resolvePendingRequests(newToken);
            return handler.resolve(response);
          } catch (e) {
            _isRefreshing = false;
            final dioError = e is DioException ? e : DioException(
              requestOptions: err.requestOptions,
              error: e,
            );
            _rejectPendingRequests(dioError);
            return handler.next(dioError);
          }
        } else {
          _isRefreshing = false;
          _rejectPendingRequests(err);
          return handler.next(err);
        }
      } catch (e) {
        // Refresh failed - clear tokens and reject all pending requests
        _isRefreshing = false;
        await StorageService.clearAuth();
        _rejectPendingRequests(err);
        return handler.next(err);
      }
    }

    return handler.next(err);
  }

  void _resolvePendingRequests(String newToken) {
    for (final pending in _pendingRequests) {
      pending.requestOptions.headers[ApiConstants.authorizationHeader] =
          'Bearer $newToken';
      _dio.fetch(pending.requestOptions).then(
            (response) => pending.handler.resolve(response),
            onError: (error) {
              final dioError = error is DioException ? error : DioException(
                requestOptions: pending.requestOptions,
                error: error,
              );
              pending.handler.reject(dioError);
            },
          );
    }
    _pendingRequests.clear();
  }

  void _rejectPendingRequests(DioException error) {
    for (final pending in _pendingRequests) {
      pending.handler.reject(error);
    }
    _pendingRequests.clear();
  }
}

class _PendingRequest {
  final RequestOptions requestOptions;
  final ErrorInterceptorHandler handler;

  _PendingRequest(this.requestOptions, this.handler);
}

