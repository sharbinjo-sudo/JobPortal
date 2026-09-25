import 'package:flutter_test/flutter_test.dart';
import 'package:job_portal/core/api.dart';
import 'package:job_portal/models.dart';

void main() {
  group('unwrapEnvelope', () {
    test('unwraps the success/message/data envelope into the payload', () {
      final payload = unwrapEnvelope({
        'success': true,
        'message': 'OK',
        'data': {'id': 7, 'email': 'ada@example.com', 'first_name': 'Ada', 'last_name': 'Lovelace', 'role': 'JOB_SEEKER'},
      });
      expect(payload, isA<Map<dynamic, dynamic>>());
      final user = User.fromJson(Map<String, dynamic>.from(payload as Map));
      expect(user.id, 7);
      expect(user.email, 'ada@example.com');
      expect(user.displayName, 'Ada Lovelace');
    });

    test('unwraps paginated list data (records come back as a list)', () {
      final payload = unwrapEnvelope({
        'success': true,
        'message': 'OK',
        'data': [
          {'id': 1, 'title': 'Engineer'},
          {'id': 2, 'title': 'Designer'},
        ],
        'meta': {'count': 2, 'page': 1},
      });
      expect(payload, isA<List<dynamic>>());
      expect((payload as List).length, 2);
    });

    test('passes plain JWT login bodies through untouched', () {
      final body = {'access': 'a.b.c', 'refresh': 'r.s.t'};
      expect(unwrapEnvelope(body), same(body));
    });

    test('passes non-envelope maps through untouched', () {
      final body = {'status': 'ok', 'database': 'connected'};
      expect(unwrapEnvelope(body), same(body));
    });
  });

  test('user model parses the unwrapped /auth/me payload end to end', () {
    // Regression: before envelope unwrapping, the raw envelope reached
    // User.fromJson and `json['id'] as int` threw, silently bouncing the app
    // back to the login page right after a successful sign-in.
    final user = User.fromJson(Map<String, dynamic>.from(unwrapEnvelope({
      'success': true,
      'message': 'OK',
      'data': {'id': 3, 'email': 'seeker@example.com', 'first_name': 'Sam', 'last_name': 'Seeker', 'phone': '', 'role': 'JOB_SEEKER', 'is_active': true},
    }) as Map));
    expect(user.role, 'JOB_SEEKER');
    expect(user.isActive, isTrue);
  });
}
