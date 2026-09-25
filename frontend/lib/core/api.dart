import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models.dart';

class ApiException implements Exception { final String message; const ApiException(this.message); @override String toString() => message; }

class Api {
  static final _storage = const FlutterSecureStorage();
  static final Dio _dio = Dio(BaseOptions(baseUrl: const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8000/api'), headers: {'Content-Type': 'application/json'}, connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 15)));
  static bool _configured = false;
  static Future<void> configure() async { if (_configured) return; final token = await _storage.read(key: 'access_token'); if (token != null) _dio.options.headers['Authorization'] = 'Bearer $token'; _configured = true; }
  static Future<User> login(String email, String password) async { try { final response = await _dio.post('/auth/login/', data: {'email': email, 'password': password}); await _storage.write(key: 'access_token', value: response.data['access'] as String); await _storage.write(key: 'refresh_token', value: response.data['refresh'] as String); _dio.options.headers['Authorization'] = 'Bearer ${response.data['access']}'; return currentUser(); } on DioException catch (error) { throw ApiException(_message(error)); } }
  static Future<User> currentUser() async { await configure(); try { final response = await _dio.get('/auth/me/'); return User.fromJson(Map<String, dynamic>.from(response.data['data'] as Map)); } on DioException catch (error) { throw ApiException(_message(error)); } }
  static Future<void> logout() async { await _storage.deleteAll(); _dio.options.headers.remove('Authorization'); }
  static Future<List<Job>> jobs({String search = '', Map<String, String> filters = const {}}) async { await configure(); try { final response = await _dio.get('/jobs/', queryParameters: {'status': 'OPEN', if (search.isNotEmpty) 'search': search, ...filters}); final body = Map<String, dynamic>.from(response.data as Map); final records = body['data'] as List? ?? body['results'] as List? ?? const []; return records.map((item) => Job.fromJson(Map<String, dynamic>.from(item as Map))).toList(); } on DioException catch (error) { throw ApiException(_message(error)); } }
  static Future<Job> job(int id) async { await configure(); try { final response = await _dio.get('/jobs/$id/'); return Job.fromJson(Map<String, dynamic>.from(response.data as Map)); } on DioException catch (error) { throw ApiException(_message(error)); } }
  static Future<void> apply(int jobId, {String coverLetter = ''}) async { await configure(); try { await _dio.post('/applications/apply/$jobId/', data: {'cover_letter': coverLetter}); } on DioException catch (error) { throw ApiException(_message(error)); } }
  static Future<Map<String, dynamic>> adminDashboard() async { await configure(); try { final response = await _dio.get('/admin/dashboard/'); return Map<String, dynamic>.from(response.data['data'] as Map); } on DioException catch (error) { throw ApiException(_message(error)); } }
  static Future<Map<String, dynamic>> recruiterDashboard() async { await configure(); try { final response = await _dio.get('/recruiter/dashboard/'); return Map<String, dynamic>.from(response.data['data'] as Map); } on DioException catch (error) { throw ApiException(_message(error)); } }
  static String _message(DioException error) { final data = error.response?.data; if (data is Map && data['message'] is String) return data['message'] as String; if (error.type == DioExceptionType.connectionError || error.type == DioExceptionType.connectionTimeout) return 'Cannot connect to the local API. Start Django and try again.'; return 'Something went wrong. Please try again.'; }
}
