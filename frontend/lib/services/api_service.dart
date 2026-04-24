import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants.dart';

class ApiService {
  ApiService({
    Dio? dio,
    FlutterSecureStorage? storage,
    this.baseUrl = AppConstants.baseUrl,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _dio = dio ?? Dio(BaseOptions(baseUrl: AppConstants.baseUrl)) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'access_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 && !_isRefreshing) {
            try {
              await _refreshToken();
              final requestOptions = error.requestOptions;
              final token = await _storage.read(key: 'access_token');
              if (token != null && token.isNotEmpty) {
                requestOptions.headers['Authorization'] = 'Bearer $token';
              }
              final response = await _dio.fetch(requestOptions);
              return handler.resolve(response);
            } catch (_) {
              await _storage.deleteAll();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final String baseUrl;
  final Dio _dio;
  final FlutterSecureStorage _storage;
  bool _isRefreshing = false;

  Never _throwReadableError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      String? message;
      if (data is Map && data['error'] != null) {
        message = data['error'].toString();
      } else if (data is Map && data['message'] != null) {
        message = data['message'].toString();
      }
      throw Exception(message ?? error.message ?? 'Network request failed');
    }
    throw Exception(error.toString());
  }

  Future<void> _refreshToken() async {
    _isRefreshing = true;
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null || refreshToken.isEmpty) {
        throw Exception('No refresh token available');
      }

      final response = await _dio.post('/auth/refresh', data: {'refresh_token': refreshToken});
      final payload = Map<String, dynamic>.from(response.data as Map);
      final newAccessToken = payload['access_token']?.toString();
      final newRefreshToken = payload['refresh_token']?.toString();
      if (newAccessToken == null || newAccessToken.isEmpty) {
        throw Exception('Refresh did not return access token');
      }

      await _storage.write(key: 'access_token', value: newAccessToken);
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await _storage.write(key: 'refresh_token', value: newRefreshToken);
      }
    } catch (error) {
      _throwReadableError(error);
    } finally {
      _isRefreshing = false;
    }
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post('/auth/register', data: payload);
      return Map<String, dynamic>.from(response.data as Map);
    } catch (error) {
      _throwReadableError(error);
    }
  }

  Future<Map<String, dynamic>> login({required String email, required String password}) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
        options: Options(validateStatus: (_) => true),
      );
      final payload = response.data;
      final statusCode = response.statusCode ?? 0;

      if (statusCode < 200 || statusCode >= 300) {
        String message = 'Unable to sign in right now. Please try again later.';
        if (payload is Map && payload['detail'] != null) {
          message = payload['detail'].toString();
        } else if (payload is Map && payload['message'] != null) {
          message = payload['message'].toString();
        }
        throw Exception(message);
      }

      if (payload is! Map) {
        throw Exception('Unexpected login response from server');
      }

      final data = Map<String, dynamic>.from(payload);
      final user = Map<String, dynamic>.from(data['user'] as Map? ?? const {});

      if (data['access_token'] != null) {
        await _storage.write(key: 'access_token', value: data['access_token'].toString());
      }
      if (data['refresh_token'] != null) {
        await _storage.write(key: 'refresh_token', value: data['refresh_token'].toString());
      }
      if (user['role'] != null) {
        await _storage.write(key: 'role', value: user['role'].toString());
      }
      if (user.isNotEmpty) {
        await _storage.write(key: 'user', value: user.toString());
      }

      return data;
    } catch (error) {
      _throwReadableError(error);
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
      await _storage.deleteAll();
    } catch (error) {
      _throwReadableError(error);
    }
  }

  Future<void> verifyEmail(String email, String otp) async {
    try {
      await _dio.post('/auth/verify-email', data: {'email': email, 'otp': otp});
    } catch (error) {
      _throwReadableError(error);
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      await _dio.post('/auth/forgot-password', data: {'email': email});
    } catch (error) {
      _throwReadableError(error);
    }
  }

  Future<void> resetPassword(String email, String token, String newPassword) async {
    try {
      await _dio.post(
        '/auth/reset-password',
        data: {'email': email, 'token': token, 'new_password': newPassword},
      );
    } catch (error) {
      _throwReadableError(error);
    }
  }

  Future<void> resendVerification(String email) async {
    try {
      await _dio.post('/auth/resend-verification', data: {'email': email});
    } catch (error) {
      _throwReadableError(error);
    }
  }

  Future<List<Map<String, dynamic>>> getApps({
    String? query,
    String? platform,
    String? category,
    int page = 1,
    int pageSize = AppConstants.defaultPageSize,
  }) async {
    try {
      final response = await _dio.get(
        '/apps',
        queryParameters: {
          if (query != null && query.isNotEmpty) 'q': query,
          if (platform != null && platform != 'all') 'platform': platform,
          if (category != null && category != 'all') 'category': category,
          'page': page,
          'limit': pageSize,
        },
      );

      final data = response.data;
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }

      final items = (Map<String, dynamic>.from(data as Map)['items'] as List? ?? const []);
      return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (error) {
      _throwReadableError(error);
    }
  }

  Future<Map<String, dynamic>> getApp(String id) async {
    try {
      final response = await _dio.get('/apps/$id');
      return Map<String, dynamic>.from(response.data as Map);
    } catch (error) {
      _throwReadableError(error);
    }
  }

  Future<void> recordInstall({required String appId, required String platform}) async {
    try {
      await _dio.post('/apps/$appId/install', data: {'platform': platform});
    } catch (error) {
      _throwReadableError(error);
    }
  }

  Future<Map<String, dynamic>> uploadApp({
    required Map<String, dynamic> metadata,
    File? androidFile,
    File? windowsFile,
    File? macFile,
    List<File>? linuxFiles,
    File? iconFile,
    List<File>? screenshots,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        ...metadata,
        if (androidFile != null) 'android_file': await MultipartFile.fromFile(androidFile.path),
        if (windowsFile != null) 'windows_file': await MultipartFile.fromFile(windowsFile.path),
        if (macFile != null) 'mac_file': await MultipartFile.fromFile(macFile.path),
        if (linuxFiles != null && linuxFiles.isNotEmpty)
          'linux_files': await Future.wait(linuxFiles.map((f) => MultipartFile.fromFile(f.path))),
        if (iconFile != null) 'icon': await MultipartFile.fromFile(iconFile.path),
        if (screenshots != null && screenshots.isNotEmpty)
          'screenshots': await Future.wait(screenshots.map((f) => MultipartFile.fromFile(f.path))),
      });

      final response = await _dio.post(
        '/developer/apps',
        data: formData,
        onSendProgress: onSendProgress,
        options: Options(contentType: 'multipart/form-data'),
      );
      return Map<String, dynamic>.from(response.data as Map);
    } catch (error) {
      _throwReadableError(error);
    }
  }

  Future<List<Map<String, dynamic>>> getDeveloperApps() async {
    try {
      final response = await _dio.get('/developer/apps');
      final data = response.data;
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      final payload = Map<String, dynamic>.from(data as Map);
      final items = (payload['items'] as List? ?? const []);
      return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (error) {
      _throwReadableError(error);
    }
  }

  Future<List<Map<String, dynamic>>> getAdminQueue({int page = 1, int pageSize = 20}) async {
    try {
      final response = await _dio.get(
        '/admin/queue',
        queryParameters: {'page': page, 'limit': pageSize},
      );
      final data = response.data;
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      final payload = Map<String, dynamic>.from(data as Map);
      final items = (payload['items'] as List? ?? const []);
      return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (error) {
      _throwReadableError(error);
    }
  }

  Future<void> approveApp(String appId) async {
    try {
      await _dio.post('/admin/apps/$appId/approve');
    } catch (error) {
      _throwReadableError(error);
    }
  }

  Future<void> rejectApp(String appId, {required String reason}) async {
    try {
      await _dio.post('/admin/apps/$appId/reject', data: {'reason': reason});
    } catch (error) {
      _throwReadableError(error);
    }
  }

  Future<Map<String, dynamic>> createFixRejectionPayment(
    String rejectionReason, {
    File? androidFile,
  }) async {
    try {
      final formData = FormData.fromMap({
        'rejection_reason': rejectionReason,
        if (androidFile != null) 'android_file': await MultipartFile.fromFile(androidFile.path),
      });

      final response = await _dio.post(
        '/payments/fix-rejection',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      return Map<String, dynamic>.from(response.data as Map);
    } catch (error) {
      _throwReadableError(error);
    }
  }

  Future<Map<String, dynamic>> getFixRejectionStatus(String reportId) async {
    try {
      final response = await _dio.get('/payments/fix-rejection/$reportId');
      return Map<String, dynamic>.from(response.data as Map);
    } catch (error) {
      _throwReadableError(error);
    }
  }
}
