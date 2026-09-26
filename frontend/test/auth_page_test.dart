import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:job_portal/app.dart';
import 'package:job_portal/core/api.dart';
import 'package:job_portal/models.dart';
import 'package:job_portal/state/providers.dart';

const _demoUser = User(id: 1, email: 'seeker@demo.jobs', firstName: 'Sam', lastName: 'Seeker', phone: '', role: 'JOB_SEEKER');

/// Records auth calls instead of touching the network or secure storage.
/// The real controller's `build()` restores a session from token storage,
/// which would block widget tests on a missing platform channel.
class _FakeAuthController extends AuthController {
  int loginCalls = 0;
  int registerCalls = 0;
  String? loginEmail;
  String? loginPassword;
  String? registerRole;
  Object? loginError;
  Completer<User>? gate;

  @override
  Future<User?> build() async => null;

  @override
  Future<User> login(String email, String password) async {
    loginCalls++;
    loginEmail = email;
    loginPassword = password;
    final error = loginError;
    if (error != null) {
      state = const AsyncData(null);
      throw error;
    }
    final gated = gate;
    final user = gated == null
        ? User(id: 1, email: email, firstName: 'Sam', lastName: 'Seeker', phone: '', role: 'JOB_SEEKER')
        : await gated.future;
    state = AsyncData(user);
    return user;
  }

  @override
  Future<User> register({required String firstName, required String lastName, required String email, required String password, required String role}) async {
    registerCalls++;
    registerRole = role;
    final user = User(id: 2, email: email, firstName: firstName, lastName: lastName, phone: '', role: role);
    state = AsyncData(user);
    return user;
  }
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

/// Tall surface so every form control (terms checkbox, submit, demo chips)
/// sits on-screen and can be tapped without scrolling heuristics.
Future<void> _pumpAuthPage(WidgetTester tester, {required _FakeAuthController auth, bool apiUp = true}) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  Api.reachabilityProbe = () async => apiUp;
  addTearDown(() => Api.reachabilityProbe = null);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authControllerProvider.overrideWith(() => auth)],
      child: const MaterialApp(home: AuthPage()),
    ),
  );
  // Warm the controller like real app startup does: its async build() must
  // resolve before interactions, otherwise Riverpod drops state assignments
  // made by login/register while the initial build is still pending.
  ProviderScope.containerOf(tester.element(find.byType(AuthPage))).read(authControllerProvider);
  await tester.pumpAndSettle(); // let the connectivity probe and build() settle
}

ProviderContainer _containerOf(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(AuthPage)));

void main() {
  testWidgets('sign-in form renders banner, demo shortcuts, and empty inputs by default', (tester) async {
    await _pumpAuthPage(tester, auth: _FakeAuthController());

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsNWidgets(2)); // toggle segment + submit button
    expect(find.text('Connected to the local API'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Job seeker'), findsOneWidget);
    expect(find.text('Recruiter'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(_field('Email address'), findsOneWidget);
    expect(_field('Password'), findsOneWidget);
    expect(tester.widget<TextFormField>(_field('Email address')).controller!.text, '');
    expect(tester.widget<TextFormField>(_field('Password')).controller!.text, '');
  });

  testWidgets('switching between register and sign-in clears all input fields', (tester) async {
    await _pumpAuthPage(tester, auth: _FakeAuthController());

    // Select a demo account to populate email and password
    final recruiterChip = find.text('Recruiter');
    await tester.ensureVisible(recruiterChip);
    await tester.tap(recruiterChip);
    await tester.pump();

    expect(tester.widget<TextFormField>(_field('Email address')).controller!.text, 'recruiter@demo.jobs');
    expect(tester.widget<TextFormField>(_field('Password')).controller!.text, 'RecruiterDemo123!');

    // Switch to Register
    await tester.tap(find.text('Register'));
    await tester.pump();

    expect(tester.widget<TextFormField>(_field('Email address')).controller!.text, '');
    expect(tester.widget<TextFormField>(_field('Password')).controller!.text, '');
    expect(tester.widget<TextFormField>(_field('First name')).controller!.text, '');
    expect(tester.widget<TextFormField>(_field('Last name')).controller!.text, '');
    expect(tester.widget<TextFormField>(_field('Confirm password')).controller!.text, '');

    // Enter data into registration fields
    await tester.enterText(_field('First name'), 'Jane');
    await tester.enterText(_field('Email address'), 'jane@example.com');
    await tester.enterText(_field('Password'), 'Secret123!');
    await tester.pump();

    // Switch back to Sign in
    await tester.tap(find.text('Sign in').first);
    await tester.pump();

    expect(tester.widget<TextFormField>(_field('Email address')).controller!.text, '');
    expect(tester.widget<TextFormField>(_field('Password')).controller!.text, '');
  });

  testWidgets('password visibility toggle unobscures the password field', (tester) async {
    await _pumpAuthPage(tester, auth: _FakeAuthController());

    final editable = find.descendant(of: _field('Password'), matching: find.byType(EditableText));
    expect(tester.widget<EditableText>(editable).obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();

    expect(tester.widget<EditableText>(editable).obscureText, isFalse);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });

  testWidgets('offline banner explains the problem and retry reconnects', (tester) async {
    await _pumpAuthPage(tester, auth: _FakeAuthController(), apiUp: false);

    expect(find.textContaining('Cannot reach the API at'), findsOneWidget);
    expect(find.textContaining('Start the Django server'), findsOneWidget);
    expect(find.text('Connected to the local API'), findsNothing);

    Api.reachabilityProbe = () async => true;
    await tester.tap(find.text('Check again'));
    await tester.pump();

    expect(find.text('Connected to the local API'), findsOneWidget);
  });

  testWidgets('demo account chips fill email and password', (tester) async {
    await _pumpAuthPage(tester, auth: _FakeAuthController());

    final recruiterChip = find.text('Recruiter');
    await tester.ensureVisible(recruiterChip);
    await tester.tap(recruiterChip);
    await tester.pump();

    expect(tester.widget<TextFormField>(_field('Email address')).controller!.text, 'recruiter@demo.jobs');
    expect(tester.widget<TextFormField>(_field('Password')).controller!.text, 'RecruiterDemo123!');
  });

  testWidgets('register mode reveals name, confirm password, role picker, and terms; hides demo shortcuts', (tester) async {
    await _pumpAuthPage(tester, auth: _FakeAuthController());

    await tester.tap(find.text('Register'));
    await tester.pump();

    expect(find.text('Create your account'), findsOneWidget);
    expect(_field('First name'), findsOneWidget);
    expect(_field('Last name'), findsOneWidget);
    expect(_field('Confirm password'), findsOneWidget);
    expect(find.text('I am joining as'), findsOneWidget);
    expect(find.textContaining('terms of service'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Already have an account? Sign in'), findsOneWidget);
    expect(find.text('Job seeker'), findsOneWidget); // dropdown selection only — demo chips hidden while registering
    expect(find.text('Recruiter'), findsNothing);
  });

  testWidgets('forgot password opens an explainer sheet', (tester) async {
    await _pumpAuthPage(tester, auth: _FakeAuthController());

    await tester.ensureVisible(find.text('Forgot password?'));
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.textContaining('demo accounts'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.text('Reset your password'), findsNothing);
  });

  testWidgets('validation blocks submit with inline errors and never calls the controller', (tester) async {
    final auth = _FakeAuthController();
    await _pumpAuthPage(tester, auth: auth);

    await tester.enterText(_field('Email address'), 'not-an-email');
    await tester.enterText(_field('Password'), 'short');
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.text('Enter a valid email.'), findsOneWidget);
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    expect(auth.loginCalls, 0);
    expect(_containerOf(tester).read(authControllerProvider).value, isNull);
  });

  testWidgets('submitting valid credentials forwards them to the auth controller', (tester) async {
    final auth = _FakeAuthController();
    await _pumpAuthPage(tester, auth: auth);

    final seekerChip = find.text('Job seeker');
    await tester.ensureVisible(seekerChip);
    await tester.tap(seekerChip);
    await tester.pump();

    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(auth.loginCalls, 1);
    expect(auth.loginEmail, 'seeker@demo.jobs');
    expect(auth.loginPassword, 'SeekerDemo123!');
    expect(_containerOf(tester).read(authControllerProvider).value?.email, 'seeker@demo.jobs');
  });

  testWidgets('submit button shows progress and is disabled while signing in', (tester) async {
    final auth = _FakeAuthController()..gate = Completer<User>();
    await _pumpAuthPage(tester, auth: auth);

    final seekerChip = find.text('Job seeker');
    await tester.ensureVisible(seekerChip);
    await tester.tap(seekerChip);
    await tester.pump();

    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    final button = find.byType(FilledButton);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(find.descendant(of: button, matching: find.byType(CircularProgressIndicator)), findsOneWidget);

    auth.gate!.complete(_demoUser);
    await tester.pump();

    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    expect(find.descendant(of: button, matching: find.byType(CircularProgressIndicator)), findsNothing);
  });

  testWidgets('failed sign-in surfaces the API error message and re-enables submit', (tester) async {
    final auth = _FakeAuthController()..loginError = const ApiException('No active account found with the given credentials.');
    await _pumpAuthPage(tester, auth: auth);

    final seekerChip = find.text('Job seeker');
    await tester.ensureVisible(seekerChip);
    await tester.tap(seekerChip);
    await tester.pump();

    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.text('No active account found with the given credentials.'), findsOneWidget);
    expect(_containerOf(tester).read(authControllerProvider).value, isNull);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
  });

  testWidgets('register flow validates passwords, requires terms, and forwards the chosen role', (tester) async {
    final auth = _FakeAuthController();
    await _pumpAuthPage(tester, auth: auth);

    await tester.tap(find.text('Register'));
    await tester.pump();
    await tester.enterText(_field('First name'), 'Ada');
    await tester.enterText(_field('Last name'), 'Lovelace');
    await tester.enterText(_field('Email address'), 'ada@example.com');
    await tester.enterText(_field('Password'), 'Sup3rSecret!');
    await tester.enterText(_field('Confirm password'), 'Nope!');

    final submit = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(auth.registerCalls, 0);

    await tester.enterText(_field('Confirm password'), 'Sup3rSecret!');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Please accept the terms to create an account.'), findsOneWidget);
    expect(auth.registerCalls, 0);

    final dropdown = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recruiter — post jobs and hire'));
    await tester.pumpAndSettle();

    final terms = find.textContaining('terms of service');
    await tester.ensureVisible(terms);
    await tester.tap(terms);
    await tester.pump();

    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(auth.registerCalls, 1);
    expect(auth.registerRole, 'RECRUITER');
    expect(_containerOf(tester).read(authControllerProvider).value?.email, 'ada@example.com');
  });
}
