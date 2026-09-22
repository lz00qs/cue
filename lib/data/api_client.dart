import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

import '../models/cue_task.dart';
import 'token_store.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

enum ServerConnectionFailure { unreachable, incompatible, verificationFailed }

class ServerConnectionException implements Exception {
  const ServerConnectionException(this.failure);

  final ServerConnectionFailure failure;
}

class SyncResult {
  const SyncResult({required this.changes, required this.latestRevision});

  final List<CueTask> changes;
  final int latestRevision;
}

class ApiClient {
  ApiClient(this._tokens, {Dio? dio, String? baseUrl})
    : _baseUrl = normalizeServerUrl(
        baseUrl ?? configuredBaseUrl,
        allowEmpty: true,
      ),
      _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 15),
              headers: const {'accept': 'application/json'},
            ),
          );

  static const configuredBaseUrl = String.fromEnvironment(
    'CUE_API_URL',
    defaultValue: '',
  );

  final TokenStore _tokens;
  final Dio _dio;
  final String _baseUrl;
  Future<void>? _refreshing;

  String get serverUrl => _baseUrl;

  String _url(String path) {
    return '$_baseUrl/api$path';
  }

  Future<void> checkConnection() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_url('/health'));
      if (response.data?['status'] != 'ok') {
        throw const ServerConnectionException(
          ServerConnectionFailure.incompatible,
        );
      }
    } on DioException catch (error) {
      throw ServerConnectionException(
        error.response == null
            ? ServerConnectionFailure.unreachable
            : ServerConnectionFailure.verificationFailed,
      );
    } on TypeError {
      throw const ServerConnectionException(
        ServerConnectionFailure.incompatible,
      );
    }
  }

  Future<bool> checkInitStatus() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_url('/auth/status'));
      final data = response.data;
      if (data != null && data['initialized'] is bool) {
        return data['initialized'] as bool;
      }
      return true;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<String> setupAdmin(String email, String password) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _url('/auth/setup'),
        data: {'email': email.trim(), 'password': password},
      );
      final data = response.data!;
      final normalizedEmail = _extractEmail(data);
      await _tokens.save(
        accessToken: _extractString(data, 'accessToken'),
        refreshToken: _extractString(data, 'refreshToken'),
        email: normalizedEmail,
      );
      return normalizedEmail;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<String> login(String email, String password) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _url('/auth/login'),
        data: {'email': email.trim(), 'password': password},
      );
      final data = response.data!;
      final normalizedEmail = _extractEmail(data);
      await _tokens.save(
        accessToken: _extractString(data, 'accessToken'),
        refreshToken: _extractString(data, 'refreshToken'),
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

  Stream<int> watchRevisions() async* {
    final client = http.Client();
    try {
      Future<http.StreamedResponse> connect() async {
        final accessToken = await _tokens.accessToken;
        if (accessToken == null) {
          throw const ApiException('Please sign in again', statusCode: 401);
        }
        final request = http.Request('GET', Uri.parse(_url('/sync/events')))
          ..headers.addAll({
            'authorization': 'Bearer $accessToken',
            'accept': 'text/event-stream',
            'cache-control': 'no-cache',
          });
        return client.send(request).timeout(const Duration(seconds: 10));
      }

      var response = await connect();
      if (response.statusCode == 401) {
        await response.stream.drain<void>();
        await _refreshOnce();
        response = await connect();
      }
      if (response.statusCode != 200) {
        throw ApiException(
          'Update stream failed (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
      if (!(response.headers['content-type'] ?? '').startsWith(
        'text/event-stream',
      )) {
        throw const ApiException(
          'Update stream returned an unexpected response',
        );
      }

      // Catch changes between the initial task load and opening the stream.
      yield 0;
      yield* parseSseRevisions(response.stream);
    } finally {
      client.close();
    }
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
      final email = _extractEmail(data);
      await _tokens.save(
        accessToken: _extractString(data, 'accessToken'),
        refreshToken: _extractString(data, 'refreshToken'),
        email: email,
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) await _tokens.clear();
      throw _mapError(error);
    }
  }

  /// Safely extracts a [String] value from the response [data] map.
  ///
  /// Throws [ApiException] when the field is missing or not a [String],
  /// which produces a clear message instead of a minified [TypeError] on web.
  static String _extractString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is String) return value;
    throw ApiException('Unexpected server response: "$key" is not a string');
  }

  /// Safely extracts the email from the nested `user` object in [data].
  static String _extractEmail(Map<String, dynamic> data) {
    final user = data['user'];
    if (user is Map<String, dynamic>) {
      final email = user['email'];
      if (email is String) return email;
    }
    throw const ApiException('Unexpected server response: missing user email');
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

Stream<int> parseSseRevisions(Stream<List<int>> bytes) async* {
  var event = '';
  final data = <String>[];
  await for (final line
      in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (event == 'change' && data.isNotEmpty) {
        try {
          final payload = jsonDecode(data.join('\n')) as Map<String, dynamic>;
          final revision = payload['revision'];
          if (revision is int && revision > 0) yield revision;
        } on FormatException {
          // A malformed notification cannot advance the sync cursor.
        } on TypeError {
          // Ignore events that do not contain a revision.
        }
      }
      event = '';
      data.clear();
    } else if (line.startsWith('event:')) {
      event = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      data.add(line.substring(5).trimLeft());
    }
  }
}

String normalizeServerUrl(String input, {bool allowEmpty = false}) {
  final value = input.trim();
  if (value.isEmpty) {
    if (allowEmpty) return '';
    throw const FormatException('Enter a server address');
  }
  final scheme = value.toLowerCase();
  if (!scheme.startsWith('http://') && !scheme.startsWith('https://')) {
    throw const FormatException('Start with http:// or https://');
  }

  final uri = Uri.tryParse(value);
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.query.isNotEmpty ||
      uri.fragment.isNotEmpty) {
    throw const FormatException('Enter a valid server URL');
  }

  var path = uri.path;
  while (path.endsWith('/') && path.length > 1) {
    path = path.substring(0, path.length - 1);
  }
  if (path == '/api') path = '';

  final normalized = uri.replace(path: path, query: null, fragment: null);
  final result = normalized.toString();
  return result.endsWith('/') ? result.substring(0, result.length - 1) : result;
}

final _emailRegex = RegExp(
  r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,63}$",
);

bool isValidEmail(String? value) {
  if (value == null) return false;
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.length > 254) return false;
  return _emailRegex.hasMatch(trimmed);
}
