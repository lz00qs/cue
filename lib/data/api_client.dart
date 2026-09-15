import 'package:dio/dio.dart';

import '../models/cue_task.dart';
import 'token_store.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class SyncResult {
  const SyncResult({required this.changes, required this.latestRevision});

  final List<CueTask> changes;
  final int latestRevision;
}

class ApiClient {
  ApiClient(this._tokens, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 15),
              headers: const {'accept': 'application/json'},
            ),
          );

  static const _configuredBase = String.fromEnvironment(
    'CUE_API_URL',
    defaultValue: '',
  );

  final TokenStore _tokens;
  final Dio _dio;
  Future<void>? _refreshing;

  String _url(String path) {
    final base = _configuredBase.endsWith('/')
        ? _configuredBase.substring(0, _configuredBase.length - 1)
        : _configuredBase;
    return '$base/api$path';
  }

  Future<String> login(String email, String password) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _url('/auth/login'),
        data: {'email': email.trim(), 'password': password},
      );
      final data = response.data!;
      final normalizedEmail =
          (data['user'] as Map<String, dynamic>)['email'] as String;
      await _tokens.save(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        email: normalizedEmail,
      );
      return normalizedEmail;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<String> restoreSession() async {
    final refreshToken = await _tokens.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const ApiException('No saved session', statusCode: 401);
    }
    await _refreshTokens();
    return await _tokens.email ?? 'admin@cue.local';
  }

  Future<void> logout() => _tokens.clear();

  Future<List<CueTask>> fetchTasks() async {
    final response = await _authorized<List<dynamic>>(
      (options) => _dio.get<List<dynamic>>(_url('/tasks'), options: options),
    );
    return response.data!
        .map((json) => CueTask.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<CueTask> createTask(CueTask task) async {
    final response = await _authorized<Map<String, dynamic>>(
      (options) => _dio.post<Map<String, dynamic>>(
        _url('/tasks'),
        data: task.toCreateJson(),
        options: options,
      ),
    );
    return CueTask.fromJson(response.data!);
  }

  Future<CueTask> updateTask(CueTask task, Map<String, dynamic> changes) async {
    final response = await _authorized<Map<String, dynamic>>(
      (options) => _dio.patch<Map<String, dynamic>>(
        _url('/tasks/${task.id}'),
        data: {'version': task.version, ...changes},
        options: options,
      ),
    );
    return CueTask.fromJson(response.data!);
  }

  Future<CueTask> deleteTask(CueTask task) async {
    final response = await _authorized<Map<String, dynamic>>(
      (options) => _dio.delete<Map<String, dynamic>>(
        _url('/tasks/${task.id}'),
        data: {'version': task.version},
        options: options,
      ),
    );
    return CueTask.fromJson(response.data!);
  }

  Future<SyncResult> sync(int since) async {
    final response = await _authorized<Map<String, dynamic>>(
      (options) => _dio.get<Map<String, dynamic>>(
        _url('/sync'),
        queryParameters: {'since': since},
        options: options,
      ),
    );
    final data = response.data!;
    return SyncResult(
      changes: (data['changes'] as List<dynamic>)
          .map((json) => CueTask.fromJson(json as Map<String, dynamic>))
          .toList(),
      latestRevision: data['latestRevision'] as int,
    );
  }

  Future<Response<T>> _authorized<T>(
    Future<Response<T>> Function(Options options) request,
  ) async {
    Future<Response<T>> send() async {
      final accessToken = await _tokens.accessToken;
      if (accessToken == null) {
        throw const ApiException('Please sign in again', statusCode: 401);
      }
      return request(
        Options(headers: {'authorization': 'Bearer $accessToken'}),
      );
    }

    try {
      return await send();
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) throw _mapError(error);
      try {
        await _refreshOnce();
        return await send();
      } on DioException catch (retryError) {
        throw _mapError(retryError);
      }
    }
  }

  Future<void> _refreshOnce() async {
    final active = _refreshing;
    if (active != null) return active;
    final operation = _refreshTokens();
    _refreshing = operation;
    try {
      await operation;
    } finally {
      if (identical(_refreshing, operation)) _refreshing = null;
    }
  }

  Future<void> _refreshTokens() async {
    final refreshToken = await _tokens.refreshToken;
    if (refreshToken == null) {
      throw const ApiException('Please sign in again', statusCode: 401);
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _url('/auth/refresh'),
        data: {'refreshToken': refreshToken},
      );
      final data = response.data!;
      final email = (data['user'] as Map<String, dynamic>)['email'] as String;
      await _tokens.save(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        email: email,
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) await _tokens.clear();
      throw _mapError(error);
    }
  }

  ApiException _mapError(DioException error) {
    final data = error.response?.data;
    String? message;
    if (data is Map<String, dynamic>) {
      final raw = data['message'];
      if (raw is String) message = raw;
      if (raw is List) message = raw.join(', ');
    }
    return ApiException(
      message ??
          (error.response == null
              ? 'Cannot reach the Cue server'
              : 'Request failed (${error.response?.statusCode})'),
      statusCode: error.response?.statusCode,
    );
  }
}
