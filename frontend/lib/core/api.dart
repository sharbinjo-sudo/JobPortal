import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models.dart';
import 'token_store.dart' as fallback;

/// Token storage that never wedges the app. `flutter_secure_storage` can fail
/// or hang indefinitely on web (blocked third-party storage, private mode, or
/// a slow first access), so every call races a short timeout and falls back to
/// in-memory storage plus localStorage (web) when the secure layer is unusable.
/// Tokens stay non-persistent in the worst case instead of blocking sign-in.
class _ResilientTokenStore {
  static const _timeout = Duration(seconds: 3);
  static const _prefix = 'jp_token_';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  final Map<String, String?> _memory = {};
  bool _secureUsable = true;

  Future<String?> read(String key) async {
    if (_memory.containsKey(key)) return _memory[key];
    if (_secureUsable) {
      try {
        final value = await _secure.read(key: key).timeout(_timeout);
        _memory[key] = value;
        if (value != null) return value;
        // Nothing in secure storage: check the web fallback so a session saved
        // during a previous secure-storage failure still restores.
        return fallback.readToken('$_prefix$key');
      } catch (_) {
        _secureUsable = false; // degrade once, stop stalling every call
      }
    }
    return fallback.readToken('$_prefix$key');
  }

  Future<void> write(String key, String? value) async {
    _memory[key] = value;
    if (_secureUsable) {
      try {
        await _secure.write(key: key, value: value).timeout(_timeout);
        return;
      } catch (_) {
        _secureUsable = false;
      }
    }
    if (value == null) {
      fallback.removeToken('$_prefix$key');
    } else {
      fallback.writeToken('$_prefix$key', value);
    }
  }

  Future<void> clear() async {
    _memory.clear();
    if (_secureUsable) {
      try {
        await _secure.deleteAll().timeout(_timeout);
      } catch (_) {
        _secureUsable = false;
      }
    }
    fallback.removeToken('${_prefix}access_token');
    fallback.removeToken('${_prefix}refresh_token');
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override String toString() => message;
}

/// Converts expected API failures and unexpected client errors into text that
/// is safe to show in the interface. Never expose raw exception details.
String userMessageFor(Object error) {
  if (error is ApiException) return error.message;
  return 'We could not complete that request. Please try again.';
}

/// Peels the actual payload out of the backend's `{success, message, data}`
/// envelope. Plain bodies (e.g. JWT login returning `{access, refresh}`) pass
/// through untouched, so callers always receive the real record(s).
dynamic unwrapEnvelope(dynamic body) {
  if (body is Map && body['success'] is bool && (body['data'] != null || body['message'] is String)) {
    return body['data'];
  }
  return body;
}

class JobFilters {
  final String search;
  final String location;
  final String skill;
  final String employmentType;
  final String workMode;
  final int? maxExperience;
  final num? minSalary;
  final bool includeClosed;

  const JobFilters({this.search = '', this.location = '', this.skill = '', this.employmentType = '', this.workMode = '', this.maxExperience, this.minSalary, this.includeClosed = false});

  bool get hasActiveFilters => search.isNotEmpty || location.isNotEmpty || skill.isNotEmpty || employmentType.isNotEmpty || workMode.isNotEmpty || maxExperience != null || minSalary != null;

  Map<String, dynamic> toQuery() => {
    if (!includeClosed) 'status': 'OPEN',
    if (search.isNotEmpty) 'search': search,
    if (location.isNotEmpty) 'location': location,
    if (skill.isNotEmpty) 'skill': skill,
    if (employmentType.isNotEmpty) 'employment_type': employmentType,
    if (workMode.isNotEmpty) 'work_mode': workMode,
    if (maxExperience != null) 'max_experience': maxExperience, // jobs requiring at most N years
    if (minSalary != null) 'min_salary': minSalary,
  };

  JobFilters copyWith({String? search, String? location, String? skill, String? employmentType, String? workMode, int? maxExperience, bool clearExperience = false, num? minSalary, bool clearSalary = false, bool? includeClosed}) => JobFilters(
    search: search ?? this.search,
    location: location ?? this.location,
    skill: skill ?? this.skill,
    employmentType: employmentType ?? this.employmentType,
    workMode: workMode ?? this.workMode,
    maxExperience: clearExperience ? null : (maxExperience ?? this.maxExperience),
    minSalary: clearSalary ? null : (minSalary ?? this.minSalary),
    includeClosed: includeClosed ?? this.includeClosed,
  );

  @override bool operator ==(Object other) => other is JobFilters && other.search == search && other.location == location && other.skill == skill && other.employmentType == employmentType && other.workMode == workMode && other.maxExperience == maxExperience && other.minSalary == minSalary && other.includeClosed == includeClosed;
  @override int get hashCode => Object.hash(search, location, skill, employmentType, workMode, maxExperience, minSalary, includeClosed);
}

class Api {
  static final _storage = _ResilientTokenStore();
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8000/api'),
    headers: {'Content-Type': 'application/json'},
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 20),
  ));
  static bool _configured = false;
  static bool _refreshing = false;

  /// Base URL for display/diagnostics (e.g. the login banner).
  static String get baseUrl => _dio.options.baseUrl;

  /// Test seam: widget tests stub this to control what the login screen's
  /// connectivity banner shows without touching the network.
  static Future<bool> Function()? reachabilityProbe;

  /// Quick reachability probe used by the login screen banner so users see a
  /// clear "backend not running" message instead of guessing.
  static Future<bool> isReachable() async {
    final probe = reachabilityProbe;
    if (probe != null) return probe();
    try {
      final response = await Dio(BaseOptions(
        baseUrl: _dio.options.baseUrl,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        validateStatus: (_) => true, // any HTTP answer means the server is up
      )).get<dynamic>('/health/');
      return response.statusCode != null;
    } catch (_) {
      return false;
    }
  }

  static Future<void> configure() async {
    if (_configured) return;
    final access = await _storage.read('access_token');
    if (access != null && access.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $access';
    }
    _configured = true;
  }

  static Future<User?> restoreSession() async {
    await configure();
    if (_dio.options.headers['Authorization'] == null) return null;
    try {
      return await currentUser();
    } on ApiException {
      await logout();
      return null;
    }
  }

  static Future<User> login(String email, String password) async {
    try {
      final response = await _dio.post('/auth/login/', data: {'email': email, 'password': password});
      // The backend wraps the JWT payload in its {success, message, data}
      // envelope, so unwrap before extracting tokens (plain bodies pass
      // through unchanged).
      await _storeTokens(Map<String, dynamic>.from(unwrapEnvelope(response.data) as Map));
      return await currentUser();
    } on DioException catch (error) {
      throw ApiException(_message(error));
    } on FormatException {
      throw const ApiException('The server returned an unexpected response. Is the API up to date?');
    }
  }

  static Future<User> register({required String firstName, required String lastName, required String email, required String password, required String role}) async {
    try {
      await _dio.post('/auth/register/', data: {'first_name': firstName, 'last_name': lastName, 'email': email, 'password': password, 'role': role});
      return login(email, password);
    } on DioException catch (error) {
      throw ApiException(_message(error));
    }
  }

  static Future<void> _storeTokens(Map<String, dynamic> values) async {
    final access = values['access'] as String?;
    final refresh = values['refresh'] as String?;
    if (access == null || access.isEmpty) {
      throw const ApiException('Login succeeded but the server did not return a session token.');
    }
    await _storage.write('access_token', access);
    await _storage.write('refresh_token', refresh);
    _dio.options.headers['Authorization'] = 'Bearer $access';
  }

  /// On a 401, refresh the access token once and replay the request. Serializes
  /// concurrent 401s onto one refresh. Returns null when the session is
  /// unrecoverable (invalid refresh token) so callers can sign out.
  static Future<Response<dynamic>?> _replayWithFreshToken(DioException error) async {
    final refresh = await _storage.read('refresh_token');
    if (refresh == null || refresh.isEmpty) return null;
    if (_refreshing) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return _dio.fetch(error.requestOptions);
    }
    _refreshing = true;
    try {
      final response = await Dio(BaseOptions(baseUrl: _dio.options.baseUrl)).post('/auth/token/refresh/', data: {'refresh': refresh});
      final access = response.data['access'] as String?;
      if (access == null) return null;
      await _storage.write('access_token', access);
      _dio.options.headers['Authorization'] = 'Bearer $access';
      return _dio.fetch(error.requestOptions);
    } on DioException {
      return null; // refresh token invalid/expired -> caller signs out
    } finally {
      _refreshing = false;
    }
  }

  /// Wraps a request; converts DioException into ApiException and transparently
  /// retries once through a token refresh when the API answers 401.
  ///
  /// Django answers with a `{success, message, data}` envelope, so the inner
  /// payload is unwrapped here and every caller receives the actual record(s).
  static Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    await configure();
    try {
      return unwrapEnvelope((await request()).data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 && error.requestOptions.path != '/auth/token/refresh/') {
        final replayed = await _replayWithFreshToken(error);
        if (replayed != null) return replayed.data;
        await logout();
      }
      throw ApiException(_message(error));
    }
  }

  static Future<User> currentUser() async => User.fromJson(Map<String, dynamic>.from(await _send(() => _dio.get('/auth/me/')) as Map));

  static Future<void> updateAccount({required String firstName, required String lastName, required String phone}) async { await _send(() => _dio.patch('/auth/me/', data: {'first_name': firstName, 'last_name': lastName, 'phone': phone})); }

  static Future<Map<String, dynamic>> profile() async => Map<String, dynamic>.from(await _send(() => _dio.get('/profiles/me/')) as Map);
  static Future<void> updateProfile(Map<String, dynamic> values) async { await _send(() => _dio.patch('/profiles/me/', data: values)); }

  static Future<Map<String, dynamic>> uploadResume(PlatformFile file) async {
    await configure();
    try {
      final bytes = file.bytes;
      if (bytes == null) throw const ApiException('The selected file could not be read. Please choose it again.');
      final response = await _dio.post('/profiles/me/resume/', data: FormData.fromMap({'resume': MultipartFile.fromBytes(bytes, filename: file.name)}));
      return Map<String, dynamic>.from(response.data['data'] as Map);
    } on DioException catch (error) { throw ApiException(_message(error)); }
  }

  static Future<Map<String, dynamic>> uploadCompanyLogo(int companyId, PlatformFile file) async {
    await configure();
    try {
      final bytes = file.bytes;
      if (bytes == null) throw const ApiException('The selected image could not be read. Please choose it again.');
      final response = await _dio.post('/companies/$companyId/logo/', data: FormData.fromMap({'logo': MultipartFile.fromBytes(bytes, filename: file.name)}));
      return Map<String, dynamic>.from(response.data['data'] as Map);
    } on DioException catch (error) { throw ApiException(_message(error)); }
  }

  static Future<void> logout() async { await _storage.clear(); _dio.options.headers.remove('Authorization'); }

  // ---- Jobs ----
  static Future<List<Job>> jobs(JobFilters filters) async {
    final records = await _records('/jobs/', query: filters.toQuery());
    return records.map(Job.fromJson).toList();
  }

  static Future<Job> createJob(Map<String, dynamic> values) async => Job.fromJson(Map<String, dynamic>.from(await _send(() => _dio.post('/jobs/', data: values)) as Map));
  static Future<Job> updateJob(int id, Map<String, dynamic> values) async => Job.fromJson(Map<String, dynamic>.from(await _send(() => _dio.patch('/jobs/$id/', data: values)) as Map));
  static Future<void> closeJob(int id) async { await _send(() => _dio.post('/jobs/$id/close/', data: const {})); }

  // ---- Companies ----
  static Future<List<Company>> companies() async => (await _records('/companies/')).map(Company.fromJson).toList();
  static Future<Company> createCompany(Map<String, dynamic> values) async => Company.fromJson(Map<String, dynamic>.from(await _send(() => _dio.post('/companies/', data: values)) as Map));
  static Future<Company> updateCompany(int id, Map<String, dynamic> values) async => Company.fromJson(Map<String, dynamic>.from(await _send(() => _dio.patch('/companies/$id/', data: values)) as Map));

  // ---- Applications ----
  static Future<void> apply(int jobId, {String coverLetter = ''}) async { await _send(() => _dio.post('/applications/apply/$jobId/', data: {'cover_letter': coverLetter})); }
  static Future<List<ApplicationItem>> applications() async => (await _records('/applications/')).map(ApplicationItem.fromJson).toList();
  static Future<ApplicationItem> updateApplicationStatus(int id, String status, {String note = ''}) async => ApplicationItem.fromJson(Map<String, dynamic>.from(await _send(() => _dio.patch('/applications/$id/status/', data: {'status': status, 'note': note})) as Map));

  // ---- Dashboards / admin ----
  static Future<Map<String, dynamic>> adminDashboard() async => Map<String, dynamic>.from(await _send(() => _dio.get('/admin/dashboard/')) as Map);
  static Future<Map<String, dynamic>> recruiterDashboard() async => Map<String, dynamic>.from(await _send(() => _dio.get('/recruiter/dashboard/')) as Map);
  static Future<List<User>> users() async => (await _records('/admin/users/')).map(User.fromJson).toList();
  static Future<User> setUserActive(int id, bool active) async => User.fromJson(Map<String, dynamic>.from(await _send(() => _dio.patch('/admin/users/$id/', data: {'is_active': active})) as Map));
  static Future<List<Company>> adminCompanies() async => (await _records('/admin/companies/')).map(Company.fromJson).toList();
  static Future<Company> adminUpdateCompany(int id, Map<String, dynamic> values) async => Company.fromJson(Map<String, dynamic>.from(await _send(() => _dio.patch('/admin/companies/$id/', data: values)) as Map));

  /// Extracts `data` records from a list endpoint (with 401-refresh handling).
  /// [_send] has already unwrapped the envelope, so a paginated body arrives
  /// here as the bare records list.
  static Future<List<Map<String, dynamic>>> _records(String path, {Map<String, dynamic>? query}) async {
    final data = await _send(() => _dio.get(path, queryParameters: query));
    final records = data is List ? data : const [];
    return records.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  static String _message(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      if (data['message'] is String) return data['message'] as String;
      if (data['detail'] is String) return data['detail'] as String;
      for (final value in data.values) {
        if (value is String && value.isNotEmpty) return value;
        if (value is List && value.isNotEmpty && value.first is String) return value.first as String;
      }
    }
    if (error.type == DioExceptionType.connectionError || error.type == DioExceptionType.connectionTimeout || error.type == DioExceptionType.receiveTimeout || error.type == DioExceptionType.sendTimeout) {
      return 'We could not reach the local API. Start the Django server and try again.';
    }
    return switch (error.response?.statusCode) {
      401 => 'Your session has ended. Please sign in again.',
      403 => 'You do not have permission to perform this action.',
      404 => 'The requested item is no longer available.',
      409 => 'This action conflicts with an existing record.',
      413 => 'The selected file is too large.',
      _ => 'We could not complete that request. Please try again.',
    };
  }
}
