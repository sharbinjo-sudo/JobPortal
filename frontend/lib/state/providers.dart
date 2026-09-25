import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../models.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, User?>(AuthController.new);

class AuthController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() => Api.restoreSession();

  Future<User> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      final user = await Api.login(email, password);
      state = AsyncData(user);
      return user;
    } catch (_) {
      state = const AsyncData(null);
      rethrow;
    }
  }

  Future<User> register({required String firstName, required String lastName, required String email, required String password, required String role}) async {
    state = const AsyncLoading();
    try {
      final user = await Api.register(firstName: firstName, lastName: lastName, email: email, password: password, role: role);
      state = AsyncData(user);
      return user;
    } catch (_) {
      state = const AsyncData(null);
      rethrow;
    }
  }

  Future<void> logout() async {
    await Api.logout();
    state = const AsyncData(null);
  }
}

final jobsProvider = FutureProvider.autoDispose.family<List<Job>, JobFilters>((ref, filters) => Api.jobs(filters));
final applicationsProvider = FutureProvider.autoDispose<List<ApplicationItem>>((ref) => Api.applications());
final adminDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) => Api.adminDashboard());
final recruiterDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) => Api.recruiterDashboard());
final adminUsersProvider = FutureProvider.autoDispose<List<User>>((ref) => Api.users());
final adminCompaniesProvider = FutureProvider.autoDispose<List<Company>>((ref) => Api.adminCompanies());
final companiesProvider = FutureProvider.autoDispose<List<Company>>((ref) => Api.companies());
