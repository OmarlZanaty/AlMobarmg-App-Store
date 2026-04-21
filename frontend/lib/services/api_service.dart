import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  ApiService({
    Dio? dio,
    FlutterSecureStorage? storage,
    this.baseUrl = 'http://54.195.111.168/api',
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _dio = dio ?? Dio(BaseOptions(baseUrl: 'http://54.195.111.168/api')) {
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
              if (token != null) {
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

  Future<void> _refreshToken() async {
    _isRefreshing = true;
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) throw Exception('No refresh token available');

      final response = await _dio.post('/auth/refresh', data: {'refresh_token': refreshToken});
      final newAccessToken = response.data['access_token'] as String?;
      final newRefreshToken = response.data['refresh_token'] as String?;
      if (newAccessToken == null) throw Exception('Refresh did not return access token');
      await _storage.write(key: 'access_token', value: newAccessToken);
      if (newRefreshToken != null) {
        await _storage.write(key: 'refresh_token', value: newRefreshToken);
      }
    } finally {
      _isRefreshing = false;
    }
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> payload) async {
    final response = await _dio.post('/auth/register', data: payload);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> login({required String email, required String password}) async {
    final response = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['access_token'] != null) {
      await _storage.write(key: 'access_token', value: data['access_token']);
    }
    if (data['refresh_token'] != null) {
      await _storage.write(key: 'refresh_token', value: data['refresh_token']);
    }
    if (data['role'] != null) {
      await _storage.write(key: 'role', value: data['role']);
    }
    return data;
  }

  Future<void> logout() async {
    await _dio.post('/auth/logout');
    await _storage.deleteAll();
  }

  Future<void> verifyEmail(String token) async {
    await _dio.post('/auth/verify-email', data: {'token': token});
  }

  Future<List<Map<String, dynamic>>> getApps({
    String? query,
    String? platform,
    String? category,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get(
      '/apps',
      queryParameters: {
        if (query != null && query.isNotEmpty) 'query': query,
        if (platform != null && platform != 'all') 'platform': platform,
        if (category != null && category != 'all') 'category': category,
        'page': page,
        'page_size': pageSize,
      },
    );
    final data = response.data;
    if (data is List) return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final items = (data['items'] ?? []) as List;
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> getApp(String id) async {
    final response = await _dio.get('/apps/$id');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> recordInstall({required String appId, required String platform}) async {
    await _dio.post('/apps/$appId/install', data: {'platform': platform});
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
      '/developer/apps/upload',
      data: formData,
      onSendProgress: onSendProgress,
      options: Options(contentType: 'multipart/form-data'),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> getDeveloperApps() async {
    final response = await _dio.get('/developer/apps');
    final data = response.data as List;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getAdminQueue() async {
    final response = await _dio.get('/admin/queue');
    final data = response.data as List;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> approveApp(String id) async {
    await _dio.post('/admin/apps/$id/approve');
  }

  Future<void> rejectApp(String id, String reason) async {
    await _dio.post('/admin/apps/$id/reject', data: {'reason': reason});
  }
}
