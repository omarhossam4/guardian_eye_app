import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:guardian_eye/core/constants/app_constants.dart';
import 'package:guardian_eye/core/errors/app_exception.dart';
import 'package:guardian_eye/core/models/api_response.dart';
import 'package:guardian_eye/core/services/auth_service.dart';
import 'package:guardian_eye/features/guardian/data/models/alert_model.dart';
import 'package:guardian_eye/features/guardian/data/models/create_guardian_profile_request.dart';
import 'package:guardian_eye/features/guardian/data/models/guardian_profile_model.dart';
import 'package:guardian_eye/features/guardian/data/models/guardian_notification_model.dart';
import 'package:guardian_eye/features/guardian/data/models/link_user_request.dart';
import 'package:guardian_eye/features/guardian/data/models/location_model.dart';
import 'package:guardian_eye/features/guardian/data/models/monitored_user_model.dart';

class ApiService {
  ApiService({
    required AuthService authService,
    Dio? dio,
  })  : _authService = authService,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConstants.apiBaseUrl,
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 20),
                headers: const {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await _authService.getValidIdToken();
            debugPrint(
              '[API] ${options.method} ${options.path} '
              'tokenPresent=${token != null && token.isNotEmpty}',
            );
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            handler.next(options);
          } catch (error) {
            debugPrint('[API] request setup error -> ${options.path} $error');
            handler.reject(
              DioException(
                requestOptions: options,
                error: error,
                type: DioExceptionType.unknown,
              ),
            );
          }
        },
        onError: (error, handler) async {
          debugPrint(
            '[API] error ${error.requestOptions.method} ${error.requestOptions.path} '
            'status=${error.response?.statusCode} message=${error.message} '
            'body=${error.response?.data}',
          );
          final allowUnauthorized =
              error.requestOptions.extra['allowUnauthorized'] == true;
          final shouldRetry = error.response?.statusCode == 401 &&
              error.requestOptions.extra['retried'] != true;

          if (!shouldRetry) {
            handler.next(error);
            return;
          }

          final refreshedToken = await _authService.refreshIdToken();
          if (refreshedToken == null || refreshedToken.isEmpty) {
            if (!allowUnauthorized) {
              debugPrint(
                '[API] refresh token missing, logging out -> ${error.requestOptions.path}',
              );
              await _authService.logout();
            }
            handler.next(error);
            return;
          }

          final requestOptions = error.requestOptions;
          requestOptions.headers['Authorization'] = 'Bearer $refreshedToken';
          requestOptions.extra['retried'] = true;

          try {
            final response = await _dio.fetch<dynamic>(requestOptions);
            debugPrint(
              '[API] retry success ${requestOptions.method} ${requestOptions.path} '
              'status=${response.statusCode}',
            );
            handler.resolve(response);
          } on DioException catch (retryError) {
            if (retryError.response?.statusCode == 401 && !allowUnauthorized) {
              debugPrint(
                '[API] retry unauthorized, logging out -> ${requestOptions.path}',
              );
              await _authService.logout();
            }
            handler.next(retryError);
          }
        },
      ),
    );
  }

  final AuthService _authService;
  final Dio _dio;

  Future<ApiResponse<GuardianProfileModel>> createGuardianProfile(
    CreateGuardianProfileRequest request,
  ) async {
    return _post(
      '/auth/guardian/create-profile',
      data: request.toJson(),
      parser: GuardianProfileModel.fromJson,
    );
  }

  Future<ApiResponse<GuardianProfileModel>> getGuardianProfile() {
    return _get(
      '/auth/guardian/me',
      parser: GuardianProfileModel.fromJson,
    );
  }

  Future<void> verifyToken() async {
    try {
      await _executeWithRetry(
        () => _dio.get<dynamic>(
          '/auth/verify-token',
          options: Options(
            extra: const {
              'allowUnauthorized': true,
            },
          ),
        ),
      );
      debugPrint('[API] verifyToken success');
    } on DioException catch (error) {
      debugPrint(
        '[API] verifyToken failed status=${error.response?.statusCode} '
        'body=${error.response?.data}',
      );
      throw _mapDioException(error);
    }
  }

  Future<void> linkUser(
    LinkUserRequest request,
  ) async {
    try {
      await _executeWithRetry(
        () => _dio.post<dynamic>(
          '/guardian/link-user',
          data: request.toJson(),
        ),
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<void> unlinkUser(
    LinkUserRequest request,
  ) async {
    final uniqueId = Uri.encodeComponent(request.userUniqueId);

    try {
      await _executeWithRetry(
        () => _dio.delete<dynamic>(
          '/guardian/unlink-user/$uniqueId',
        ),
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<Map<String, dynamic>?> getUserSummary(String userId) async {
    try {
      final response = await _executeWithRetry(
        () => _dio.get<dynamic>('/guardian/user-summary/$userId'),
      );
      final body = _normalizeBody(response.data);
      final data = body.containsKey('data') ? body['data'] : body;
      if (data is Map<String, dynamic>) return data;
    } catch (_) {}
    return null;
  }

  Future<ApiResponse<LocationModel>> getCurrentLocation(String userId) {
    return _get(
      '/guardian/user-location/$userId',
      parser: LocationModel.fromJson,
    );
  }

  Future<ApiResponse<List<AlertModel>>> getRecentAlerts(String userId) {
    return _getList(
      '/guardian/alerts/$userId',
      parser: AlertModel.fromJson,
    );
  }

  Future<ApiResponse<List<GuardianNotificationModel>>>
      getNotifications() async {
    DioException? lastError;
    const paths = [
      '/guardian/notifications',
      '/notifications',
    ];

    for (final path in paths) {
      try {
        return await _getList(
          path,
          parser: GuardianNotificationModel.fromJson,
        );
      } on DioException catch (error) {
        lastError = error;
        final statusCode = error.response?.statusCode ?? 0;
        if (statusCode != 404 && statusCode != 405) {
          rethrow;
        }
      }
    }

    throw _mapDioException(
      lastError ??
          DioException(
            requestOptions: RequestOptions(path: '/guardian/notifications'),
            error: 'Request failed.',
            type: DioExceptionType.unknown,
          ),
    );
  }

  Future<void> markNotificationRead(String notificationId) async {
    DioException? lastError;
    final encodedId = Uri.encodeComponent(notificationId);
    final attempts = <Future<Response<dynamic>> Function()>[
      () => _dio.patch<dynamic>('/guardian/notifications/$encodedId'),
      () => _dio.post<dynamic>('/guardian/mark-as-read/$encodedId'),
      () => _dio.patch<dynamic>('/guardian/mark-as-read/$encodedId'),
      () => _dio.post<dynamic>('/guardian/notifications/$encodedId/read'),
      () => _dio.patch<dynamic>('/guardian/notifications/$encodedId/read'),
      () => _dio.post<dynamic>('/guardian/readnotification/$encodedId'),
      () => _dio.post<dynamic>('/guardian/read-notification/$encodedId'),
      () => _dio.patch<dynamic>('/guardian/readnotification/$encodedId'),
      () => _dio.patch<dynamic>('/guardian/read-notification/$encodedId'),
    ];

    for (final attempt in attempts) {
      try {
        await _executeWithRetry(attempt);
        return;
      } on DioException catch (error) {
        lastError = error;
        final statusCode = error.response?.statusCode ?? 0;
        if (statusCode != 404 && statusCode != 405) {
          throw _mapDioException(error);
        }
      }
    }

    throw _mapDioException(
      lastError ??
          DioException(
            requestOptions: RequestOptions(
              path: '/guardian/mark-as-read/$encodedId',
            ),
            error: 'Request failed.',
            type: DioExceptionType.unknown,
          ),
    );
  }

  Future<ApiResponse<T>> _get<T>(
    String path, {
    required T Function(Map<String, dynamic> json) parser,
  }) async {
    try {
      final response = await _executeWithRetry(() => _dio.get<dynamic>(path));
      debugPrint('[API] GET $path success status=${response.statusCode}');
      final body = _normalizeBody(response.data);
      final data = _extractDataMap(body);
      return ApiResponse<T>(
        data: parser(data),
        message: body['message'] as String?,
        meta: body['meta'] as Map<String, dynamic>?,
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<ApiResponse<List<T>>> _getList<T>(
    String path, {
    required T Function(Map<String, dynamic> json) parser,
  }) async {
    try {
      final response = await _executeWithRetry(() => _dio.get<dynamic>(path));
      debugPrint('[API] GET $path success status=${response.statusCode}');
      final body = _normalizeBody(response.data);
      final data = _extractDataList(body);
      return ApiResponse<List<T>>(
        data: data.map(parser).toList(),
        message: body['message'] as String?,
        meta: body['meta'] as Map<String, dynamic>?,
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<ApiResponse<T>> _post<T>(
    String path, {
    Map<String, dynamic>? data,
    required T Function(Map<String, dynamic> json) parser,
  }) async {
    try {
      final response = await _executeWithRetry(
        () => _dio.post<dynamic>(path, data: data),
      );
      debugPrint('[API] POST $path success status=${response.statusCode}');
      final body = _normalizeBody(response.data);
      final parsedData = _extractDataMap(body);
      return ApiResponse<T>(
        data: parser(parsedData),
        message: body['message'] as String?,
        meta: body['meta'] as Map<String, dynamic>?,
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<ApiResponse<List<MonitoredUserModel>>> getMonitoredUsers() {
    return _getList(
      '/guardian/monitored-users',
      parser: MonitoredUserModel.fromJson,
    );
  }

  Future<Response<dynamic>> _executeWithRetry(
    Future<Response<dynamic>> Function() action,
  ) async {
    DioException? lastError;

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await action();
      } on DioException catch (error) {
        lastError = error;
        if (!_shouldRetry(error) || attempt == 2) {
          rethrow;
        }

        await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }

    throw lastError ?? const AppException('Request failed.');
  }

  bool _shouldRetry(DioException error) {
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        (error.response?.statusCode ?? 0) >= 500;
  }

  Map<String, dynamic> _normalizeBody(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }

    return <String, dynamic>{'data': data};
  }

  Map<String, dynamic> _extractDataMap(Map<String, dynamic> body) {
    final dynamic data = body.containsKey('data') ? body['data'] : body;
    if (data is Map<String, dynamic>) {
      return data;
    }

    throw const AppException('Unexpected response format.');
  }

  List<Map<String, dynamic>> _extractDataList(Map<String, dynamic> body) {
    debugPrint('[API] _extractDataList keys: ${body.keys.toList()}');
    // Try common wrapper keys first, then fall back to body itself
    dynamic data;
    for (final key in [
      'data',
      'items',
      'users',
      'results',
      'monitored_users'
    ]) {
      if (body.containsKey(key) && body[key] is List) {
        data = body[key];
        break;
      }
    }
    data ??= body;
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }

    debugPrint('[API] _extractDataList unexpected format: $body');
    throw const AppException('Unexpected list response format.');
  }

  AppException _mapDioException(DioException error) {
    final responseData = error.response?.data;
    var message = responseData is Map<String, dynamic>
        ? (responseData['message'] as String?) ?? 'Request failed.'
        : 'Request failed.';

    if (error.response?.statusCode == 404 &&
        error.requestOptions.path == '/guardian/link-user') {
      message =
          'Unable to link this user. Verify the unique ID and make sure the blind user profile already exists.';
    }

    if (error.response?.statusCode == 404 &&
        error.requestOptions.path.contains('/guardian/unlink-user')) {
      message = 'Unable to unlink this user right now.';
    }

    return AppException(
      message,
      statusCode: error.response?.statusCode,
      code: error.type.name,
    );
  }
}
