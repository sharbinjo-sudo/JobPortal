import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/api.dart';
import 'models.dart';
import 'state/providers.dart';

const _brand = Color(0xff214e6b);
const _ink = Color(0xff162f3d);
const _muted = Color(0xff607d8b);

Color statusColor(String status) => Color(statusPalette[status] ?? 0xff607d8b);

class JobPortalApp extends ConsumerWidget {
  const JobPortalApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return MaterialApp(
      title: 'Northstar Jobs',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _brand),
        scaffoldBackgroundColor: const Color(0xfff6f8fa),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: _ink, elevation: 0, scrolledUnderElevation: 0, surfaceTintColor: Colors.transparent),
        cardTheme: CardThemeData(color: Colors.white, elevation: 0, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xffe3eaf0)))),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xfff8fafc),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xffd8e0e6))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xffd8e0e6))),
        ),
        snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: _ink, contentTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        popupMenuTheme: PopupMenuThemeData(color: Colors.white, surfaceTintColor: Colors.transparent, elevation: 8, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xffe3eaf0))))
      ),
      home: auth.when(
        loading: () => const _SplashPage(),
        error: (_, __) => const AuthPage(),
        data: (user) => user == null ? const AuthPage() : PortalShell(user: user),
      ),
    );
  }
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [BrandMark(), SizedBox(height: 24), CircularProgressIndicator()])),
  );
}

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});
  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController(text: 'seeker@demo.jobs');
  final _password = TextEditingController(text: 'SeekerDemo123!');
  final _confirm = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;
  bool _checkingApi = true;
  bool _apiUp = true;
  String _role = 'JOB_SEEKER';
  String? _error;

  @override
  void initState() {
    super.initState();
    _probeApi();
  }

  Future<void> _probeApi() async {
    final up = await Api.isReachable();
    if (mounted) setState(() { _apiUp = up; _checkingApi = false; });
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_registering && !_agreedToTerms) {
      setState(() => _error = 'Please accept the terms to create an account.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() { _busy = true; _error = null; });
    try {
      final controller = ref.read(authControllerProvider.notifier);
      if (_registering) {
        await controller.register(firstName: _firstName.text.trim(), lastName: _lastName.text.trim(), email: _email.text.trim(), password: _password.text, role: _role);
      } else {
        await controller.login(_email.text.trim(), _password.text);
      }
    } catch (error) {
      if (mounted) setState(() => _error = userMessageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _selectDemo(String email, String password) {
    setState(() { _registering = false; _email.text = email; _password.text = password; _error = null; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(builder: (context, constraints) {
      final form = _authForm(context);
      if (constraints.maxWidth < 900) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    form,
                    const SizedBox(height: 24),
                    const _MobileHowItWorksCard(),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      return Row(children: [
        const Expanded(flex: 6, child: _AuthHero()),
        Expanded(flex: 5, child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(40), child: form))),
      ]);
    }),
  );

  Widget _authForm(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 460),
    child: Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xffe3eaf0))),
      child: Padding(padding: const EdgeInsets.all(32), child: Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const BrandMark(compact: true),
        const SizedBox(height: 24),
        Text(_registering ? 'Create your account' : 'Welcome back', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: _ink)),
        const SizedBox(height: 6),
        Text(_registering ? 'Start your career journey with Northstar.' : 'Sign in to your Northstar workspace.', style: const TextStyle(color: _muted)),
        const SizedBox(height: 18),
        _ApiStatusBanner(offlineChecked: _checkingApi, offline: !_apiUp && !_checkingApi, onRetry: _probeApi),
        const SizedBox(height: 16),
        _AuthModeToggle(registering: _registering, onChanged: (registering) => setState(() { _registering = registering; _error = null; })),
        const SizedBox(height: 18),
        if (_registering) ...[
          Row(children: [Expanded(child: TextFormField(controller: _firstName, decoration: const InputDecoration(labelText: 'First name', prefixIcon: Icon(Icons.person_outline)), validator: _required)), const SizedBox(width: 12), Expanded(child: TextFormField(controller: _lastName, decoration: const InputDecoration(labelText: 'Last name', prefixIcon: Icon(Icons.person_outline)), validator: _required))]),
          const SizedBox(height: 14),
        ],
        TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline)), validator: _emailValidator),
        const SizedBox(height: 14),
        TextFormField(controller: _password, obscureText: _obscure, autofillHints: const [AutofillHints.password], onFieldSubmitted: (_) => _submit(), decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined))), validator: (value) => value == null || value.length < 8 ? 'Use at least 8 characters.' : null),
        if (_registering) ...[
          const SizedBox(height: 14),
          TextFormField(controller: _confirm, obscureText: _obscureConfirm, decoration: InputDecoration(labelText: 'Confirm password', prefixIcon: const Icon(Icons.lock_reset_outlined), suffixIcon: IconButton(onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm), icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined))), validator: (value) => value != _password.text ? 'Passwords do not match.' : null),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(initialValue: _role, isExpanded: true, selectedItemBuilder: (context) => const [Text('Job seeker'), Text('Recruiter')], decoration: const InputDecoration(labelText: 'I am joining as', prefixIcon: Icon(Icons.badge_outlined)), items: const [DropdownMenuItem(value: 'JOB_SEEKER', child: Text('Job seeker — find and apply to roles', overflow: TextOverflow.ellipsis)), DropdownMenuItem(value: 'RECRUITER', child: Text('Recruiter — post jobs and hire', overflow: TextOverflow.ellipsis))], onChanged: (value) => setState(() => _role = value ?? 'JOB_SEEKER')),
          const SizedBox(height: 6),
          CheckboxListTile(
            value: _agreedToTerms,
            onChanged: (value) => setState(() => _agreedToTerms = value ?? false),
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('I agree to the terms of service and privacy policy.', style: TextStyle(fontSize: 13)),
          ),
        ],
        if (!_registering)
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _busy ? null : () => _showForgotPasswordSheet(), child: const Text('Forgot password?'))),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 4, bottom: 8), child: _ErrorBanner(message: _error!)),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 48, child: FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_registering ? 'Create account' : 'Sign in'))),
        const SizedBox(height: 14),
        if (!_registering) ...[
          Row(children: [const Expanded(child: Divider()), Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or use a demo account', style: const TextStyle(fontSize: 12, color: _muted), maxLines: 1)), const Expanded(child: Divider())]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _DemoAccountChip(icon: Icons.person_search_outlined, label: 'Job seeker', email: 'seeker@demo.jobs', password: 'SeekerDemo123!', onSelect: _selectDemo)),
            const SizedBox(width: 10),
            Expanded(child: _DemoAccountChip(icon: Icons.business_center_outlined, label: 'Recruiter', email: 'recruiter@demo.jobs', password: 'RecruiterDemo123!', onSelect: _selectDemo)),
            const SizedBox(width: 10),
            Expanded(child: _DemoAccountChip(icon: Icons.admin_panel_settings_outlined, label: 'Admin', email: 'admin@demo.jobs', password: 'AdminDemo123!', onSelect: _selectDemo)),
          ]),
        ] else ...[
          Center(child: TextButton(onPressed: _busy ? null : () => setState(() { _registering = false; _error = null; }), child: const Text('Already have an account? Sign in'))),
        ],
      ],
    ))),
  ));

  void _showForgotPasswordSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Reset your password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 10),
          Text('This local build runs without an email provider, so password reset emails cannot be sent. Ask an administrator to reset your password from the admin workspace, or use one of the demo accounts to explore.', style: TextStyle(height: 1.5, color: Colors.grey.shade700)),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 44, child: FilledButton.tonal(onPressed: () => Navigator.pop(sheetContext), child: const Text('Got it'))),
        ]),
      ),
    );
  }
}

/// Segmented control that replaces the old text-link login/register toggle.
class _AuthModeToggle extends StatelessWidget {
  final bool registering;
  final ValueChanged<bool> onChanged;
  const _AuthModeToggle({required this.registering, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: const Color(0xffeef3f7), borderRadius: BorderRadius.circular(12)),
    padding: const EdgeInsets.all(4),
    child: Row(children: [
      Expanded(child: _ToggleSegment(selected: !registering, label: 'Sign in', icon: Icons.login_outlined, onTap: () => onChanged(false))),
      Expanded(child: _ToggleSegment(selected: registering, label: 'Register', icon: Icons.person_add_alt_1_outlined, onTap: () => onChanged(true))),
    ]),
  );
}

class _ToggleSegment extends StatelessWidget {
  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ToggleSegment({required this.selected, required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? Colors.white : Colors.transparent,
    borderRadius: BorderRadius.circular(9),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: selected ? _brand : _muted),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: selected ? _brand : _muted)),
        ]),
      ),
    ),
  );
}

/// Shows whether the local Django API is reachable before the user types
/// anything, so "stuck on login" is immediately diagnosable.
class _ApiStatusBanner extends StatelessWidget {
  final bool offlineChecked;
  final bool offline;
  final VoidCallback onRetry;
  const _ApiStatusBanner({required this.offlineChecked, required this.offline, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (offlineChecked) {
      return Card(
        margin: EdgeInsets.zero,
        color: const Color(0xfff4f7f9),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Row(children: [
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Expanded(child: Text('Checking local API at ${Api.baseUrl}…', style: const TextStyle(fontSize: 12, color: _muted))),
        ])),
      );
    }
    if (offline) {
      return Card(
        margin: EdgeInsets.zero,
        color: const Color(0xfffff4e5),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.cloud_off_outlined, size: 16, color: Color(0xffb75c00)),
            const SizedBox(width: 8),
            Expanded(child: Text('Cannot reach the API at ${Api.baseUrl}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xffb75c00)))),
          ]),
          const SizedBox(height: 4),
          Text('Start the Django server: cd backend && python manage.py runserver', style: TextStyle(fontSize: 11.5, color: Colors.brown.shade700)),
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: onRetry, child: const Text('Check again', style: TextStyle(fontSize: 12)))),
        ])),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xffe9f6ec),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Row(children: const [
        Icon(Icons.check_circle_outline, size: 16, color: Color(0xff1d7a35)),
        SizedBox(width: 8),
        Expanded(child: Text('Connected to the local API', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xff1d7a35)))),
      ])),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.error.withValues(alpha: .08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: .25))),
    child: Row(children: [
      Icon(Icons.error_outline, size: 18, color: Theme.of(context).colorScheme.error),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600))),
    ]),
  );
}

class _DemoAccountChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String email;
  final String password;
  final void Function(String email, String password) onSelect;
  const _DemoAccountChip({required this.icon, required this.label, required this.email, required this.password, required this.onSelect});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => onSelect(email, password),
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(color: const Color(0xffeef6f9), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xffd5e7ee))),
      child: Column(children: [
        Icon(icon, size: 20, color: _brand),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
      ]),
    ),
  );
}

String? _required(String? value) => value == null || value.trim().isEmpty ? 'Required.' : null;
String? _emailValidator(String? value) => value == null || !value.contains('@') ? 'Enter a valid email.' : null;

class _AuthHero extends StatelessWidget {
  const _AuthHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff183950),
            Color(0xff214e6b),
            Color(0xff16384d),
          ],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const BrandMark(light: true),
                    const SizedBox(width: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 13, color: Color(0xff7ce7ac)),
                          SizedBox(width: 5),
                          Text(
                            'Career Portal',
                            style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const Text(
                  'The right opportunity\nchanges everything.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'A streamlined hiring platform built for candidates finding dream roles and employers discovering top talent.',
                  style: TextStyle(color: Color(0xffd0e2ec), fontSize: 15.5, height: 1.5),
                ),
                const SizedBox(height: 28),
                _HeroFeatureSection(
                  badgeColor: const Color(0xff38bdf8),
                  badgeIcon: Icons.search_rounded,
                  badgeLabel: 'FOR CANDIDATES & SEEKERS',
                  title: 'Find, Apply & Track with Ease',
                  steps: const [
                    _HeroStep(
                      number: '1',
                      title: 'Discover Curated Roles',
                      description: 'Search and filter listings by title, required skills, experience level, employment type, or location.',
                    ),
                    _HeroStep(
                      number: '2',
                      title: 'Upload Profile & Resume',
                      description: 'Maintain your professional headline, bio, skills, and store your resume securely in cloud storage.',
                    ),
                    _HeroStep(
                      number: '3',
                      title: '1-Click Apply & Live Tracking',
                      description: 'Submit applications in seconds. Receive email confirmations and track your progress in real time.',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _HeroFeatureSection(
                  badgeColor: const Color(0xfffbbf24),
                  badgeIcon: Icons.business_center_rounded,
                  badgeLabel: 'FOR RECRUITERS & COMPANIES',
                  title: 'Publish Roles & Hire Efficiently',
                  steps: const [
                    _HeroStep(
                      number: '1',
                      title: 'Showcase Your Brand',
                      description: 'Create your company profile with custom logo, mission, website, and industry focus.',
                    ),
                    _HeroStep(
                      number: '2',
                      title: 'Post Detailed Listings',
                      description: 'Define key skills, experience brackets, compensation ranges, and job requirements.',
                    ),
                    _HeroStep(
                      number: '3',
                      title: 'Review Resumes & Pipeline',
                      description: 'Inspect candidates, view cloud-hosted resumes instantly, and advance hiring stages collaboratively.',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: const [
                    _HeroPill(icon: Icons.cloud_done_outlined, label: 'Cloud-Stored Resumes'),
                    _HeroPill(icon: Icons.mark_email_read_outlined, label: 'Email Notifications'),
                    _HeroPill(icon: Icons.track_changes_outlined, label: 'Transparent Statuses'),
                    _HeroPill(icon: Icons.verified_user_outlined, label: 'Verified Employers'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroFeatureSection extends StatelessWidget {
  final Color badgeColor;
  final IconData badgeIcon;
  final String badgeLabel;
  final String title;
  final List<_HeroStep> steps;

  const _HeroFeatureSection({
    required this.badgeColor,
    required this.badgeIcon,
    required this.badgeLabel,
    required this.title,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 13, color: badgeColor),
                    const SizedBox(width: 5),
                    Text(
                      badgeLabel,
                      style: TextStyle(color: badgeColor, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...steps.map((step) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      step.number,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${step.title}: ',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 12.5),
                        ),
                        TextSpan(
                          text: step.description,
                          style: const TextStyle(color: Color(0xffc5dae6), fontSize: 12.5, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _HeroStep {
  final String number;
  final String title;
  final String description;

  const _HeroStep({
    required this.number,
    required this.title,
    required this.description,
  });
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xff7ce7ac)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Color(0xffe1edf3), fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _MobileHowItWorksCard extends StatelessWidget {
  const _MobileHowItWorksCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xffe3eaf0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lightbulb_outline_rounded, color: _brand, size: 20),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How Northstar Works',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink),
                    ),
                    Text(
                      'Simple workflows for candidates & hiring teams',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _MobileRoleSection(
              title: 'For Candidates & Seekers',
              badgeColor: Color(0xff0284c7),
              icon: Icons.person_search_outlined,
              points: [
                'Discover roles filtered by skills, experience, and compensation',
                'Upload and securely store your resume in cloud storage',
                '1-click application submission with live status tracking & email alerts',
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(color: Color(0xffedf2f7), height: 1),
            ),
            const _MobileRoleSection(
              title: 'For Employers & Recruiters',
              badgeColor: Color(0xffd97706),
              icon: Icons.business_center_outlined,
              points: [
                'Create company profiles with verified branding and logos',
                'Publish job openings with custom requirements and skill tags',
                'Review incoming resumes instantly and manage your candidate pipeline',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileRoleSection extends StatelessWidget {
  final String title;
  final Color badgeColor;
  final IconData icon;
  final List<String> points;

  const _MobileRoleSection({
    required this.title,
    required this.badgeColor,
    required this.icon,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: badgeColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...points.map(
          (point) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    point,
                    style: const TextStyle(fontSize: 12.5, color: Color(0xff475569), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


class PortalShell extends ConsumerStatefulWidget {
  final User user;
  const PortalShell({super.key, required this.user});
  @override ConsumerState<PortalShell> createState() => _PortalShellState();
}

class _PortalShellState extends ConsumerState<PortalShell> {
  int _section = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final items = _itemsForRole(widget.user.role);
    final sections = _sectionsForRole(widget.user.role);
    if (_section >= items.length) _section = 0;
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 960;
      return Scaffold(
        key: _scaffoldKey,
        appBar: _TopBar(
          user: widget.user,
          onLogout: () => ref.read(authControllerProvider.notifier).logout(),
          onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        drawer: _SideNav(
          user: widget.user,
          items: items,
          sections: sections,
          selected: _section,
          onSelect: (value) { setState(() => _section = value); Navigator.pop(context); },
          onLogout: () => ref.read(authControllerProvider.notifier).logout(),
        ),
        drawerEnableOpenDragGesture: compact,
        body: _content(items),
      );
    });
  }

  Widget _content(List<_NavItem> items) {
    if (widget.user.role == 'ADMIN') {
      return switch (_section) {
        0 => const AdminOverview(),
        1 => const AdminUsersPage(),
        2 => const AdminCompaniesPage(),
        3 => const AdminJobsPage(),
        4 => const AdminApplicationsPage(),
        _ => const ReportsPage(),
      };
    }
    if (widget.user.role == 'RECRUITER') {
      return switch (_section) {
        0 => const RecruiterOverview(),
        1 => const RecruiterJobsPage(),
        2 => const ApplicantsPage(),
        3 => const CompaniesPage(),
        _ => AccountPage(user: widget.user, seekerProfile: false),
      };
    }
    return switch (_section) {
      0 => const JobsPage(title: 'Your next opportunity', subtitle: 'Roles selected from the live job board.', canApply: true),
      1 => const ApplicationsPage(title: 'My applications'),
      _ => AccountPage(user: widget.user, seekerProfile: true),
    };
  }
}

/// Navigation model: a flat list of destinations per role, grouped into
/// top-bar sections. Sections with a single destination render as a plain
/// nav button; sections with several render as a dropdown menu.
class _NavSection {
  final String title;
  final IconData icon;
  final List<int> indices; // indices into the flat _NavItem list
  const _NavSection(this.title, this.icon, this.indices);
}

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  final User user;
  final Future<void> Function() onLogout;
  final VoidCallback onOpenMenu;
  const _TopBar({required this.user, required this.onLogout, required this.onOpenMenu});
  @override Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) => AppBar(
      toolbarHeight: 68,
      automaticallyImplyLeading: false,
      leading: IconButton(onPressed: onOpenMenu, tooltip: 'Open navigation', icon: const Icon(Icons.menu_rounded)),
      leadingWidth: 58,
      titleSpacing: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      shape: const Border(bottom: BorderSide(color: Color(0xffe3eaf0))),
      title: const BrandMark(compact: true),
      actions: [
        _AccountMenu(user: user, onLogout: onLogout, compact: MediaQuery.sizeOf(context).width < 620),
        const SizedBox(width: 12),
      ],
    );
}

/// Avatar menu with account summary and sign out.
class _AccountMenu extends StatelessWidget {
  final User user;
  final Future<void> Function() onLogout;
  final bool compact;
  const _AccountMenu({required this.user, required this.onLogout, this.compact = false});

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    onSelected: (value) { if (value == 'logout') onLogout(); },
    offset: const Offset(0, 54),
    itemBuilder: (_) => [
      PopupMenuItem<String>(
        enabled: false,
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.displayName.isEmpty ? user.email : user.displayName, style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
            const SizedBox(height: 2),
            Text(user.email, style: const TextStyle(fontSize: 12, color: _muted)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xffeaf4f7), borderRadius: BorderRadius.circular(20)),
              child: Text(displayLabel(user.role), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _brand)),
            ),
          ]),
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem<String>(
        value: 'logout',
        height: 44,
        child: Row(children: [Icon(Icons.logout_rounded, size: 18, color: Color(0xffc62828)), SizedBox(width: 10), Text('Sign out', style: TextStyle(color: Color(0xffc62828), fontWeight: FontWeight.w700))]),
      ),
    ],
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 14),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(radius: 17, backgroundColor: const Color(0xffd9ecf2), foregroundColor: _brand, child: Text(user.firstName.isEmpty ? 'U' : user.firstName[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800))),
        if (!compact) ...[
          const SizedBox(width: 10),
          Text(user.displayName.isEmpty ? user.email : user.displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          const Icon(Icons.expand_more, size: 20),
        ],
      ]),
    ),
  );
}

/// Primary navigation displayed in the left hamburger drawer on every screen.
class _SideNav extends StatelessWidget {
  final User user;
  final List<_NavItem> items;
  final List<_NavSection> sections;
  final int selected;
  final ValueChanged<int> onSelect;
  final Future<void> Function() onLogout;
  const _SideNav({required this.user, required this.items, required this.sections, required this.selected, required this.onSelect, required this.onLogout});

  @override
  Widget build(BuildContext context) => Drawer(
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(20))),
    child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.fromLTRB(20, 20, 20, 4), child: BrandMark(compact: true)),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        child: Row(children: [
          CircleAvatar(radius: 19, backgroundColor: const Color(0xffd9ecf2), foregroundColor: _brand, child: Text(user.firstName.isEmpty ? 'U' : user.firstName[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.displayName.isEmpty ? user.email : user.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
            Text(displayLabel(user.role), style: const TextStyle(fontSize: 12, color: _muted)),
          ])),
        ]),
      ),
      const Divider(height: 1, thickness: 1, color: Color(0xffe3eaf0)),
      Expanded(child: ListView(padding: const EdgeInsets.all(12), children: [
        for (final section in sections) ...[
          if (section.indices.length > 1)
            Padding(padding: const EdgeInsets.fromLTRB(12, 14, 12, 6), child: Text(section.title.toUpperCase(), style: const TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: Color(0xff78909c)))),
          for (final index in section.indices)
            _SideNavItem(item: items[index], active: selected == index, onTap: () => onSelect(index)),
        ],
      ])),
      const Divider(height: 1, thickness: 1, color: Color(0xffe3eaf0)),
      Padding(padding: const EdgeInsets.all(12), child: SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: onLogout, icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xffc62828)), label: const Text('Sign out', style: TextStyle(color: Color(0xffc62828), fontWeight: FontWeight.w700))))),
    ])),
  );
}

class _SideNavItem extends StatelessWidget {
  final _NavItem item;
  final bool active;
  final VoidCallback onTap;
  const _SideNavItem({required this.item, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Material(
      color: active ? const Color(0xffeaf4f7) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), child: Row(children: [
          Icon(item.icon, size: 20, color: active ? _brand : _muted),
          const SizedBox(width: 12),
          Expanded(child: Text(item.title, style: TextStyle(color: active ? _brand : _ink, fontWeight: active ? FontWeight.w800 : FontWeight.w600, fontSize: 14))),
        ])),
      ),
    ),
  );
}

List<_NavItem> _itemsForRole(String role) {
  if (role == 'ADMIN') return const [_NavItem('Overview', Icons.grid_view_rounded), _NavItem('Users', Icons.people_outline), _NavItem('Companies', Icons.business_outlined), _NavItem('Jobs', Icons.work_outline), _NavItem('Applications', Icons.description_outlined), _NavItem('Reports', Icons.bar_chart_outlined)];
  if (role == 'RECRUITER') return const [_NavItem('Overview', Icons.grid_view_rounded), _NavItem('My jobs', Icons.work_outline), _NavItem('Applicants', Icons.groups_outlined), _NavItem('Companies', Icons.business_outlined), _NavItem('Account', Icons.person_outline)];
  return const [_NavItem('Explore jobs', Icons.work_outline), _NavItem('My applications', Icons.description_outlined), _NavItem('My profile', Icons.person_outline)];
}

/// Groups the flat destinations into top-bar sections. Sections listing more
/// than one destination render as dropdown menus on desktop and as labelled
/// groups inside the mobile drawer.
List<_NavSection> _sectionsForRole(String role) {
  if (role == 'ADMIN') return const [
    _NavSection('Overview', Icons.grid_view_rounded, [0]),
    _NavSection('Manage', Icons.admin_panel_settings_outlined, [1, 2, 3, 4]),
    _NavSection('Reports', Icons.bar_chart_outlined, [5]),
  ];
  if (role == 'RECRUITER') return const [
    _NavSection('Overview', Icons.grid_view_rounded, [0]),
    _NavSection('Hiring', Icons.work_outline, [1, 2]),
    _NavSection('Companies', Icons.business_outlined, [3]),
    _NavSection('Account', Icons.person_outline, [4]),
  ];
  return const [
    _NavSection('Explore jobs', Icons.work_outline, [0]),
    _NavSection('My applications', Icons.description_outlined, [1]),
    _NavSection('My profile', Icons.person_outline, [2]),
  ];
}

// ---------------------------------------------------------------------------
// Job discovery (seekers, public)
// ---------------------------------------------------------------------------

class JobsPage extends ConsumerStatefulWidget {
  final String title; final String subtitle; final bool canApply;
  const JobsPage({super.key, required this.title, required this.subtitle, required this.canApply});
  @override ConsumerState<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends ConsumerState<JobsPage> {
  JobFilters _filters = const JobFilters();
  JobFilters _draft = const JobFilters();
  Timer? _debounce;

  /// Text inputs update a draft immediately and commit to the live filters
  /// after a short debounce, so typing does not fire a request per keystroke.
  void _editFilters(JobFilters next, {bool immediate = false}) {
    _debounce?.cancel();
    setState(() => _draft = next);
    if (immediate) {
      setState(() => _filters = next);
    } else {
      _debounce = Timer(const Duration(milliseconds: 400), () { if (mounted) setState(() => _filters = _draft); });
    }
  }

  @override
  void dispose() { _debounce?.cancel(); super.dispose(); }

  Future<void> _refresh() async { ref.invalidate(jobsProvider(_filters)); await ref.read(jobsProvider(_filters).future); }

  @override
  Widget build(BuildContext context) {
    final jobsState = ref.watch(jobsProvider(_filters));
    return RefreshIndicator(onRefresh: _refresh, child: ListView(padding: const EdgeInsets.fromLTRB(28, 30, 28, 48), children: [
      _PageTitle(title: widget.title, subtitle: widget.subtitle), const SizedBox(height: 20),
      _JobFilterBar(filters: _draft, onChanged: _editFilters),
      const SizedBox(height: 18),
      if (jobsState.isLoading)
        const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator()))
      else if (jobsState.hasError)
        _ErrorPanel(message: userMessageFor(jobsState.error!), onRetry: _refresh)
      else if (jobsState.valueOrNull?.isEmpty ?? true)
        const _EmptyPanel(message: 'No roles match your filters. Try widening your search.')
      else
        ...jobsState.valueOrNull!.map((job) => Padding(padding: const EdgeInsets.only(bottom: 14), child: JobCard(job: job, canApply: widget.canApply))),
    ]));
  }
}

class _JobFilterBar extends StatelessWidget {
  final JobFilters filters; final void Function(JobFilters next, {bool immediate}) onChanged;
  const _JobFilterBar({required this.filters, required this.onChanged});

  /// Text inputs go through the parent's debounce; dropdown selections and the
  /// clear button commit immediately for snappier filtering.
  void _commit(JobFilters next) => onChanged(next, immediate: true);

  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
    TextField(onChanged: (value) => onChanged(filters.copyWith(search: value)), decoration: const InputDecoration(hintText: 'Search by title, skill, or company', prefixIcon: Icon(Icons.search), isDense: true)),
    const SizedBox(height: 12),
    LayoutBuilder(builder: (context, constraints) {
      final fields = <Widget>[
        TextField(onChanged: (value) => onChanged(filters.copyWith(location: value)), decoration: const InputDecoration(labelText: 'Location', prefixIcon: Icon(Icons.location_on_outlined), isDense: true)),
        TextField(onChanged: (value) => onChanged(filters.copyWith(skill: value)), decoration: const InputDecoration(labelText: 'Skill', prefixIcon: Icon(Icons.handyman_outlined), isDense: true)),
        DropdownButtonFormField<String>(initialValue: filters.employmentType, decoration: const InputDecoration(labelText: 'Employment type', prefixIcon: Icon(Icons.business_center_outlined), isDense: true), items: [const DropdownMenuItem(value: '', child: Text('Any type')), ...employmentTypes.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))], onChanged: (value) => _commit(filters.copyWith(employmentType: value ?? ''))),
        DropdownButtonFormField<String>(initialValue: filters.workMode, decoration: const InputDecoration(labelText: 'Work mode', prefixIcon: Icon(Icons.laptop_mac_outlined), isDense: true), items: [const DropdownMenuItem(value: '', child: Text('Any mode')), ...workModes.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))], onChanged: (value) => _commit(filters.copyWith(workMode: value ?? ''))),
        DropdownButtonFormField<int>(initialValue: filters.maxExperience, decoration: const InputDecoration(labelText: 'My experience (years)', prefixIcon: Icon(Icons.timeline_outlined), isDense: true), items: [const DropdownMenuItem(value: null, child: Text('Any')), ...List.generate(10, (index) => index + 1).map((years) => DropdownMenuItem(value: years, child: Text('$years+ years')))], onChanged: (value) => _commit(filters.copyWith(maxExperience: value, clearExperience: value == null))),
      ];
      if (constraints.maxWidth >= 900) return Column(children: [
        Row(children: [Expanded(child: fields[0]), const SizedBox(width: 12), Expanded(child: fields[1]), const SizedBox(width: 12), Expanded(child: fields[2])]),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: fields[3]), const SizedBox(width: 12), Expanded(child: fields[4]), const Spacer(flex: 2)]),
      ]);
      return Column(children: [
        for (final field in fields) ...[field, const SizedBox(height: 12)],
      ]);
    }),
    if (filters.minSalary != null || filters.hasActiveFilters) ...[
      const SizedBox(height: 6),
      Row(children: [
        if (filters.minSalary != null) Expanded(child: TextField(onChanged: (value) => onChanged(filters.copyWith(minSalary: num.tryParse(value), clearSalary: value.isEmpty)), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minimum salary', prefixIcon: Icon(Icons.payments_outlined), isDense: true))),
        if (filters.minSalary != null) const SizedBox(width: 12),
        Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => _commit(const JobFilters()), icon: const Icon(Icons.filter_alt_off_outlined, size: 18), label: const Text('Clear filters'))),
      ]),
    ],
  ])));
}

class JobCard extends StatelessWidget {
  final Job job; final bool canApply;
  const JobCard({super.key, required this.job, required this.canApply});
  @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [CircleAvatar(backgroundColor: const Color(0xffeaf4f7), foregroundColor: _brand, child: Text(job.companyName.isEmpty ? 'N' : job.companyName[0].toUpperCase())), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(job.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)), Text(job.companyName, style: const TextStyle(color: _muted))])), Chip(label: Text(job.isOpen ? 'Open' : 'Closed'))]),
    const SizedBox(height: 16),
    Wrap(spacing: 14, runSpacing: 8, children: [_Fact(icon: Icons.location_on_outlined, value: job.location), _Fact(icon: Icons.business_center_outlined, value: job.employmentLabel), _Fact(icon: Icons.laptop_mac_outlined, value: job.workModeLabel), _Fact(icon: Icons.payments_outlined, value: job.salaryLabel), _Fact(icon: Icons.timeline_outlined, value: job.experienceMin == 0 ? 'No experience required' : '${job.experienceMin}+ years experience')]),
    if (job.skills.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 14), child: Wrap(spacing: 7, runSpacing: 7, children: job.skills.map((skill) => Chip(label: Text(skill), visualDensity: VisualDensity.compact, side: BorderSide.none, backgroundColor: const Color(0xffeff6f8))).toList())),
    const SizedBox(height: 14), Align(alignment: Alignment.centerRight, child: FilledButton.tonal(onPressed: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => JobDetailSheet(job: job, canApply: canApply)), child: const Text('View role'))),
  ])));
}

class JobDetailSheet extends ConsumerStatefulWidget {
  final Job job; final bool canApply;
  const JobDetailSheet({super.key, required this.job, required this.canApply});
  @override ConsumerState<JobDetailSheet> createState() => _JobDetailSheetState();
}

class _JobDetailSheetState extends ConsumerState<JobDetailSheet> {
  final _coverLetter = TextEditingController(); bool _busy = false; String? _error;
  @override void dispose() { _coverLetter.dispose(); super.dispose(); }
  Future<void> _apply() async { setState(() { _busy = true; _error = null; }); try { await Api.apply(widget.job.id, coverLetter: _coverLetter.text.trim()); ref.invalidate(applicationsProvider); ref.invalidate(recruiterDashboardProvider); ref.invalidate(adminDashboardProvider); if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application submitted successfully.'))); } } catch (error) { if (mounted) setState(() => _error = userMessageFor(error)); } finally { if (mounted) setState(() => _busy = false); } }
  @override Widget build(BuildContext context) => Container(height: MediaQuery.sizeOf(context).height * .86, decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))), child: SafeArea(top: false, child: ListView(padding: const EdgeInsets.all(28), children: [
    Text(widget.job.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _ink)), const SizedBox(height: 6), Text(widget.job.companyName, style: const TextStyle(fontWeight: FontWeight.w700, color: _muted)), const SizedBox(height: 18),
    Wrap(spacing: 8, runSpacing: 8, children: [Chip(label: Text(widget.job.location)), Chip(label: Text(widget.job.employmentLabel)), Chip(label: Text(widget.job.workModeLabel)), Chip(label: Text(widget.job.salaryLabel)), Chip(label: Text(widget.job.experienceMin == 0 ? 'Fresher friendly' : '${widget.job.experienceMin}+ years'))]), const SizedBox(height: 24),
    const Text('About this role', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)), const SizedBox(height: 8), Text(widget.job.description.isEmpty ? 'No detailed description has been added yet.' : widget.job.description, style: const TextStyle(height: 1.6, color: Color(0xff455a64))), const SizedBox(height: 22),
    if (widget.job.skills.isNotEmpty) ...[const Text('Skills', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)), const SizedBox(height: 10), Wrap(spacing: 7, runSpacing: 7, children: widget.job.skills.map((skill) => Chip(label: Text(skill), backgroundColor: const Color(0xffeff6f8), side: BorderSide.none)).toList()), const SizedBox(height: 22)],
    if (widget.canApply) ...[TextField(controller: _coverLetter, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Cover letter (optional)', alignLabelWithHint: true)), if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))), const SizedBox(height: 16), SizedBox(height: 48, child: FilledButton(onPressed: _busy || !widget.job.isOpen ? null : _apply, child: _busy ? const CircularProgressIndicator(color: Colors.white) : Text(widget.job.isOpen ? 'Apply for this role' : 'Role closed')))],
  ])));
}

// ---------------------------------------------------------------------------
// Applications (seeker tracking + recruiter/admin pipeline)
// ---------------------------------------------------------------------------

class ApplicationsPage extends ConsumerWidget {
  final String title;
  const ApplicationsPage({super.key, required this.title});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applications = ref.watch(applicationsProvider);
    return RefreshIndicator(
      onRefresh: () async { ref.invalidate(applicationsProvider); await ref.read(applicationsProvider.future); },
      child: ListView(padding: const EdgeInsets.all(28), children: [
        _PageTitle(title: title, subtitle: 'Track the current status of every application.'),
        const SizedBox(height: 20),
        applications.when(
          loading: () => const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator())),
          error: (error, _) => _ErrorPanel(message: userMessageFor(error), onRetry: () => ref.invalidate(applicationsProvider)),
          data: (items) => items.isEmpty
              ? const _EmptyPanel(message: 'No applications to show yet.')
              : Column(children: items.map((item) => Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(contentPadding: const EdgeInsets.all(18), leading: CircleAvatar(backgroundColor: statusColor(item.status).withValues(alpha: .12), foregroundColor: statusColor(item.status), child: const Icon(Icons.description_outlined)), title: Text(item.jobTitle, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(item.companyName.isEmpty ? (item.appliedAt.isEmpty ? 'Date unavailable' : 'Applied ${item.appliedAt.substring(0, 10)}') : '${item.companyName} · Applied ${item.appliedAt.isEmpty ? '—' : item.appliedAt.substring(0, 10)}'), trailing: _StatusChip(status: item.status), onTap: () => _showDetail(context, item)))).toList()),
        ),
      ]),
    );
  }

  void _showDetail(BuildContext context, ApplicationItem item) {
    showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => ApplicationDetailSheet(application: item, canManage: false));
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: statusColor(status).withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
    child: Text(displayLabel(status), style: TextStyle(color: statusColor(status), fontWeight: FontWeight.w800, fontSize: 12)),
  );
}

class ApplicationDetailSheet extends ConsumerStatefulWidget {
  final ApplicationItem application;
  final bool canManage;
  const ApplicationDetailSheet({super.key, required this.application, required this.canManage});
  @override ConsumerState<ApplicationDetailSheet> createState() => _ApplicationDetailSheetState();
}

class _ApplicationDetailSheetState extends ConsumerState<ApplicationDetailSheet> {
  String _status = 'APPLIED';
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() { super.initState(); _status = widget.application.status; }

  @override
  void dispose() { _note.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() { _busy = true; _error = null; });
    try {
      await Api.updateApplicationStatus(widget.application.id, _status, note: _note.text.trim());
      ref.invalidate(applicationsProvider); ref.invalidate(recruiterDashboardProvider); ref.invalidate(adminDashboardProvider);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = userMessageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openResume() async {
    final url = widget.application.resumeUrl;
    if (url.isEmpty) return;
    try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The resume link could not be opened.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.application;
    return Container(height: MediaQuery.sizeOf(context).height * .86, decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))), child: SafeArea(top: false, child: ListView(padding: const EdgeInsets.all(28), children: [
      Text(app.jobTitle, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _ink)),
      const SizedBox(height: 4),
      Text([app.companyName, app.applicantName].where((part) => part.isNotEmpty).join(' · '), style: const TextStyle(color: _muted, fontWeight: FontWeight.w700)),
      const SizedBox(height: 18),
      _StatusChip(status: app.status),
      const SizedBox(height: 20),
      if (app.applicantEmail.isNotEmpty) ...[const Text('Candidate', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)), const SizedBox(height: 6), Text(app.applicantEmail, style: const TextStyle(color: Color(0xff455a64))), const SizedBox(height: 18)],
      if (app.coverLetter.isNotEmpty) ...[const Text('Cover letter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)), const SizedBox(height: 6), Text(app.coverLetter, style: const TextStyle(height: 1.6, color: Color(0xff455a64))), const SizedBox(height: 18)],
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.upload_file_outlined, color: _brand),
        title: const Text('Resume', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(app.resumeUrl.isEmpty ? 'No resume attached' : 'Open resume document'),
        trailing: app.resumeUrl.isEmpty ? null : IconButton(icon: const Icon(Icons.open_in_new), onPressed: _openResume),
        onTap: app.resumeUrl.isEmpty ? null : _openResume,
      ),
      if (app.history.isNotEmpty) ...[const SizedBox(height: 12), const Text('Status history', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)), const SizedBox(height: 10),
        ...app.history.map((entry) => ListTile(contentPadding: EdgeInsets.zero, dense: true, leading: Icon(Icons.timeline, size: 18, color: statusColor(entry.newStatus)), title: Text(entry.oldStatus.isEmpty ? 'Applied as ${displayLabel(entry.newStatus)}' : '${displayLabel(entry.oldStatus)} → ${displayLabel(entry.newStatus)}', style: const TextStyle(fontSize: 13.5)), subtitle: Text([entry.changedByName, entry.createdAt.substring(0, 10), if (entry.note.isNotEmpty) entry.note].where((part) => part.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 12))))],
      if (widget.canManage) ...[
        const Divider(height: 32),
        const Text('Update status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: _status, decoration: const InputDecoration(labelText: 'New status', prefixIcon: Icon(Icons.flag_outlined)), items: applicationStatuses.map((status) => DropdownMenuItem(value: status, child: Text(displayLabel(status)))).toList(), onChanged: (value) => setState(() => _status = value ?? _status)),
        const SizedBox(height: 12),
        TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note for the record (optional)')),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 18),
        SizedBox(height: 48, child: FilledButton(onPressed: _busy ? null : _save, child: _busy ? const CircularProgressIndicator(color: Colors.white) : const Text('Save status'))),
      ],
    ])));
  }
}

// ---------------------------------------------------------------------------
// Recruiter: jobs, applicants, companies
// ---------------------------------------------------------------------------

class RecruiterOverview extends ConsumerWidget {
  const RecruiterOverview({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) { final state = ref.watch(recruiterDashboardProvider); return state.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, _) => _ErrorPanel(message: userMessageFor(error), onRetry: () => ref.invalidate(recruiterDashboardProvider)),
    data: (data) => ListView(padding: const EdgeInsets.all(28), children: [
      _PageTitle(title: 'Hiring workspace', subtitle: 'Manage your recruitment activity in one place.'), const SizedBox(height: 20),
      Wrap(spacing: 14, runSpacing: 14, children: [_Metric(icon: Icons.work_outline, value: '${data['active_jobs']}', label: 'Active jobs'), _Metric(icon: Icons.work_history_outlined, value: '${data['total_jobs']}', label: 'Total postings'), _Metric(icon: Icons.people_outline, value: '${data['applications']}', label: 'Applicants'), _Metric(icon: Icons.playlist_add_check_outlined, value: '${data['shortlisted']}', label: 'Shortlisted'), _Metric(icon: Icons.event_available_outlined, value: '${data['interviews']}', label: 'Interviews'), _Metric(icon: Icons.workspace_premium_outlined, value: '${data['selected']}', label: 'Selected')]),
      const SizedBox(height: 26),
      const Text('Latest applicants', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
      const SizedBox(height: 12),
      ...((data['recent_applications'] as List? ?? const []).map((raw) {
        final item = ApplicationItem.fromJson(Map<String, dynamic>.from(raw as Map));
        return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(contentPadding: const EdgeInsets.all(16), leading: CircleAvatar(backgroundColor: statusColor(item.status).withValues(alpha: .12), foregroundColor: statusColor(item.status), child: Text(item.applicantName.isEmpty ? '?' : item.applicantName[0].toUpperCase())), title: Text('${item.applicantName} · ${item.jobTitle}', style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(item.appliedAt.isEmpty ? '' : 'Applied ${item.appliedAt.substring(0, 10)}'), trailing: _StatusChip(status: item.status)));
      })),
    ]));
  }
}

class RecruiterJobsPage extends ConsumerWidget {
  const RecruiterJobsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsState = ref.watch(jobsProvider(const JobFilters(includeClosed: true)));
    return RefreshIndicator(
      onRefresh: () async { ref.invalidate(jobsProvider(const JobFilters(includeClosed: true))); await ref.read(jobsProvider(const JobFilters(includeClosed: true)).future); },
      child: ListView(padding: const EdgeInsets.all(28), children: [
        Row(children: [const Expanded(child: _PageTitle(title: 'My job postings', subtitle: 'Create, edit, close, and review your open roles.')), FilledButton.icon(onPressed: () => _openEditor(context, ref, null), icon: const Icon(Icons.add), label: const Text('New job'))]),
        const SizedBox(height: 20),
        jobsState.when(
          loading: () => const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator())),
          error: (error, _) => _ErrorPanel(message: userMessageFor(error), onRetry: () => ref.invalidate(jobsProvider(const JobFilters(includeClosed: true)))),
          data: (jobs) => jobs.isEmpty ? const _EmptyPanel(message: 'You have not posted any jobs yet. Create your first role.') : Column(children: jobs.map((job) => _RecruiterJobRow(job: job)).toList()),
        ),
      ]),
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref, Job? job) {
    showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => JobEditSheet(existing: job));
  }
}

class _RecruiterJobRow extends ConsumerWidget {
  final Job job;
  const _RecruiterJobRow({required this.job});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(job.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink)), const SizedBox(height: 4), Text('${job.companyName} · ${job.location}', style: const TextStyle(color: _muted))])), Chip(label: Text(displayLabel(job.status)))])
    , const SizedBox(height: 10),
    Wrap(spacing: 14, runSpacing: 6, children: [_Fact(icon: Icons.business_center_outlined, value: job.employmentLabel), _Fact(icon: Icons.payments_outlined, value: job.salaryLabel), _Fact(icon: Icons.timeline_outlined, value: '${job.experienceMin}+ yrs')]),
    const SizedBox(height: 12),
    Wrap(spacing: 8, children: [
      OutlinedButton.icon(onPressed: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => JobEditSheet(existing: job)), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit')),
      if (job.status != 'CLOSED') OutlinedButton.icon(onPressed: () async { await Api.closeJob(job.id); ref.invalidate(jobsProvider(const JobFilters(includeClosed: true))); ref.invalidate(recruiterDashboardProvider); }, icon: const Icon(Icons.block_outlined, size: 18), label: const Text('Close')),
      FilledButton.tonalIcon(onPressed: () { Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobApplicantsPage(job: job))); }, icon: const Icon(Icons.groups_outlined, size: 18), label: const Text('Applicants')),
    ]),
  ])));
}

class JobEditSheet extends ConsumerStatefulWidget {
  final Job? existing;
  const JobEditSheet({super.key, required this.existing});
  @override ConsumerState<JobEditSheet> createState() => _JobEditSheetState();
}

class _JobEditSheetState extends ConsumerState<JobEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _description = TextEditingController(text: widget.existing?.description ?? '');
  late final TextEditingController _location = TextEditingController(text: widget.existing?.location ?? '');
  late final TextEditingController _salaryMin = TextEditingController(text: widget.existing?.salaryMin?.toString() ?? '');
  late final TextEditingController _salaryMax = TextEditingController(text: widget.existing?.salaryMax?.toString() ?? '');
  late final TextEditingController _skills = TextEditingController(text: widget.existing?.skills.join(', ') ?? '');
  late final TextEditingController _experience = TextEditingController(text: '${widget.existing?.experienceMin ?? 0}');
  late String _employmentType = widget.existing?.employmentType ?? 'FULL_TIME';
  late String _workMode = widget.existing?.workMode ?? 'HYBRID';
  int? _companyId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() { _title.dispose(); _description.dispose(); _location.dispose(); _salaryMin.dispose(); _salaryMax.dispose(); _skills.dispose(); _experience.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_companyId == null) { setState(() => _error = 'Create a company profile first (Companies tab).'); return; }
    setState(() { _busy = true; _error = null; });
    final values = {
      'company': _companyId,
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'location': _location.text.trim(),
      'salary_min': num.tryParse(_salaryMin.text.trim()),
      'salary_max': num.tryParse(_salaryMax.text.trim()),
      'skills': _skills.text.split(',').map((skill) => skill.trim()).where((skill) => skill.isNotEmpty).toList(),
      'experience_min': int.tryParse(_experience.text.trim()) ?? 0,
      'employment_type': _employmentType,
      'work_mode': _workMode,
    };
    try {
      if (widget.existing == null) { await Api.createJob(values); } else { await Api.updateJob(widget.existing!.id, values); }
      ref.invalidate(jobsProvider(const JobFilters(includeClosed: true))); ref.invalidate(recruiterDashboardProvider); ref.invalidate(adminDashboardProvider);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = userMessageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final companies = ref.watch(companiesProvider).valueOrNull ?? const <Company>[];
    if (_companyId == null && companies.isNotEmpty) _companyId = widget.existing?.companyId ?? companies.first.id;
    return Container(height: MediaQuery.sizeOf(context).height * .9, decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))), child: SafeArea(top: false, child: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(28), children: [
      Text(widget.existing == null ? 'Post a new job' : 'Edit job', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _ink)),
      const SizedBox(height: 20),
      TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Job title'), validator: _required),
      const SizedBox(height: 14),
      TextFormField(controller: _description, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true), validator: _required),
      const SizedBox(height: 14),
      if (companies.isEmpty) const _EmptyPanel(message: 'You need a company profile before posting a job.') else DropdownButtonFormField<int>(initialValue: _companyId, decoration: const InputDecoration(labelText: 'Company'), items: companies.map((company) => DropdownMenuItem(value: company.id, child: Text(company.name))).toList(), onChanged: (value) => setState(() => _companyId = value)),
      const SizedBox(height: 14),
      TextFormField(controller: _location, decoration: const InputDecoration(labelText: 'Location'), validator: _required),
      const SizedBox(height: 14),
      Row(children: [Expanded(child: TextFormField(controller: _salaryMin, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Salary minimum'))), const SizedBox(width: 12), Expanded(child: TextFormField(controller: _salaryMax, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Salary maximum')))]),
      const SizedBox(height: 14),
      TextFormField(controller: _skills, decoration: const InputDecoration(labelText: 'Skills (comma separated)', hintText: 'Python, Django, PostgreSQL')),
      const SizedBox(height: 14),
      TextFormField(controller: _experience, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minimum years of experience')),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(initialValue: _employmentType, decoration: const InputDecoration(labelText: 'Employment type'), items: employmentTypes.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(), onChanged: (value) => setState(() => _employmentType = value ?? _employmentType)),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(initialValue: _workMode, decoration: const InputDecoration(labelText: 'Work mode'), items: workModes.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(), onChanged: (value) => setState(() => _workMode = value ?? _workMode)),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      const SizedBox(height: 22),
      SizedBox(height: 48, child: FilledButton(onPressed: _busy ? null : _save, child: _busy ? const CircularProgressIndicator(color: Colors.white) : Text(widget.existing == null ? 'Publish job' : 'Save changes'))),
    ]))));
  }
}

class ApplicantsPage extends ConsumerWidget {
  const ApplicantsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applications = ref.watch(applicationsProvider);
    return RefreshIndicator(
      onRefresh: () async { ref.invalidate(applicationsProvider); await ref.read(applicationsProvider.future); },
      child: ListView(padding: const EdgeInsets.all(28), children: [
        const _PageTitle(title: 'Applicants', subtitle: 'Review candidates, download resumes, and move them through the pipeline.'),
        const SizedBox(height: 20),
        applications.when(
          loading: () => const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator())),
          error: (error, _) => _ErrorPanel(message: userMessageFor(error), onRetry: () => ref.invalidate(applicationsProvider)),
          data: (items) => items.isEmpty ? const _EmptyPanel(message: 'No applications received yet.') : Column(children: items.map((item) => _ApplicantRow(item: item)).toList()),
        ),
      ]),
    );
  }
}

class _ApplicantRow extends StatelessWidget {
  final ApplicationItem item;
  const _ApplicantRow({required this.item});
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(
    contentPadding: const EdgeInsets.all(18),
    leading: CircleAvatar(backgroundColor: statusColor(item.status).withValues(alpha: .12), foregroundColor: statusColor(item.status), child: Text(item.applicantName.isEmpty ? '?' : item.applicantName[0].toUpperCase())),
    title: Text(item.applicantName, style: const TextStyle(fontWeight: FontWeight.w800)),
    subtitle: Text('${item.jobTitle}${item.companyName.isEmpty ? '' : ' · ${item.companyName}'}\nApplied ${item.appliedAt.isEmpty ? '—' : item.appliedAt.substring(0, 10)}'),
    isThreeLine: true,
    trailing: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [_StatusChip(status: item.status), const Icon(Icons.chevron_right)]),
    onTap: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => ApplicationDetailSheet(application: item, canManage: true)),
  ));
}

class JobApplicantsPage extends ConsumerWidget {
  final Job job;
  const JobApplicantsPage({super.key, required this.job});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applications = ref.watch(applicationsProvider);
    final forJob = applications.valueOrNull?.where((item) => item.jobId == job.id).toList() ?? const <ApplicationItem>[];
    return Scaffold(
      appBar: AppBar(title: Text('Applicants · ${job.title}')),
      body: RefreshIndicator(
        onRefresh: () async { ref.invalidate(applicationsProvider); await ref.read(applicationsProvider.future); },
        child: applications.isLoading
            ? const Center(child: CircularProgressIndicator())
            : applications.hasError
                ? ListView(children: [_ErrorPanel(message: userMessageFor(applications.error!), onRetry: () => ref.invalidate(applicationsProvider))])
                : forJob.isEmpty
                    ? ListView(children: const [_EmptyPanel(message: 'No applications for this role yet.')])
                    : ListView(padding: const EdgeInsets.all(28), children: forJob.map((item) => _ApplicantRow(item: item)).toList()),
      ),
    );
  }
}

class CompaniesPage extends ConsumerWidget {
  const CompaniesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companies = ref.watch(companiesProvider);
    return RefreshIndicator(
      onRefresh: () async { ref.invalidate(companiesProvider); await ref.read(companiesProvider.future); },
      child: ListView(padding: const EdgeInsets.all(28), children: [
        Row(children: [const Expanded(child: _PageTitle(title: 'Company profiles', subtitle: 'Create companies and keep their branding current.')), FilledButton.icon(onPressed: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const CompanyEditSheet()), icon: const Icon(Icons.add), label: const Text('New company'))]),
        const SizedBox(height: 20),
        companies.when(
          loading: () => const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator())),
          error: (error, _) => _ErrorPanel(message: userMessageFor(error), onRetry: () => ref.invalidate(companiesProvider)),
          data: (items) => items.isEmpty ? const _EmptyPanel(message: 'Create your first company profile to start posting jobs.') : Column(children: items.map((company) => _CompanyCard(company: company)).toList()),
        ),
      ]),
    );
  }
}

class _CompanyCard extends ConsumerWidget {
  final Company company;
  const _CompanyCard({required this.company});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> uploadLogo() async {
      final file = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'], withData: true);
      if (file == null) return;
      try {
        await Api.uploadCompanyLogo(company.id, file.files.single);
        ref.invalidate(companiesProvider);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company logo uploaded successfully.')));
      } catch (error) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userMessageFor(error))));
      }
    }
    return Card(margin: const EdgeInsets.only(bottom: 14), child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [
      Container(width: 56, height: 56, decoration: BoxDecoration(color: const Color(0xffeaf4f7), borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: company.logoUrl.isEmpty ? Text(company.name.isEmpty ? 'C' : company.name.substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, color: _brand, fontSize: 22)) : ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(company.logoUrl, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, color: _brand)))),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(company.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), const SizedBox(height: 4), Text([company.location, if (company.openJobs > 0) '${company.openJobs} open roles'].where((part) => part.isNotEmpty).join(' · '), style: const TextStyle(color: _muted))])),
      TextButton(onPressed: uploadLogo, child: const Text('Logo')),
      OutlinedButton(onPressed: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => CompanyEditSheet(existing: company)), child: const Text('Edit')),
    ])));
  }
}

class CompanyEditSheet extends ConsumerStatefulWidget {
  final Company? existing;
  const CompanyEditSheet({super.key, this.existing});
  @override ConsumerState<CompanyEditSheet> createState() => _CompanyEditSheetState();
}

class _CompanyEditSheetState extends ConsumerState<CompanyEditSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _description = TextEditingController(text: widget.existing?.description ?? '');
  late final _industry = TextEditingController(text: widget.existing?.industry ?? '');
  late final _website = TextEditingController(text: widget.existing?.website ?? '');
  late final _location = TextEditingController(text: widget.existing?.location ?? '');
  final GlobalKey<FormState> _formKeyState = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() { _name.dispose(); _description.dispose(); _industry.dispose(); _website.dispose(); _location.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!(_formKeyState.currentState?.validate() ?? false)) return;
    setState(() { _busy = true; _error = null; });
    final values = {'name': _name.text.trim(), 'description': _description.text.trim(), 'industry': _industry.text.trim(), 'website': _website.text.trim(), 'location': _location.text.trim()};
    try {
      if (widget.existing == null) { await Api.createCompany(values); } else { await Api.updateCompany(widget.existing!.id, values); }
      ref.invalidate(companiesProvider); ref.invalidate(adminCompaniesProvider);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = userMessageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(height: MediaQuery.sizeOf(context).height * .8, decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))), child: SafeArea(top: false, child: Form(key: _formKeyState, child: ListView(padding: const EdgeInsets.all(28), children: [
    Text(widget.existing == null ? 'New company profile' : 'Edit company', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _ink)),
    const SizedBox(height: 20),
    TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Company name'), validator: _required),
    const SizedBox(height: 14),
    TextFormField(controller: _description, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true)),
    const SizedBox(height: 14),
    TextFormField(controller: _industry, decoration: const InputDecoration(labelText: 'Industry')),
    const SizedBox(height: 14),
    TextFormField(controller: _website, decoration: const InputDecoration(labelText: 'Website (https://...)')),
    const SizedBox(height: 14),
    TextFormField(controller: _location, decoration: const InputDecoration(labelText: 'Location')),
    if (_error != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
    const SizedBox(height: 22),
    SizedBox(height: 48, child: FilledButton(onPressed: _busy ? null : _save, child: _busy ? const CircularProgressIndicator(color: Colors.white) : const Text('Save company'))),
  ]))));
}

// ---------------------------------------------------------------------------
// Admin
// ---------------------------------------------------------------------------

class AdminOverview extends ConsumerWidget {
  const AdminOverview({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) { final state = ref.watch(adminDashboardProvider); return state.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, _) => _ErrorPanel(message: userMessageFor(error), onRetry: () => ref.invalidate(adminDashboardProvider)),
    data: (data) => ListView(padding: const EdgeInsets.all(28), children: [
      const _PageTitle(title: 'System overview', subtitle: 'Live platform metrics across users, jobs, and hiring.'),
      const SizedBox(height: 20),
      Wrap(spacing: 14, runSpacing: 14, children: [_Metric(icon: Icons.people_outline, value: '${data['users']}', label: 'Users'), _Metric(icon: Icons.business_outlined, value: '${data['companies']}', label: 'Companies'), _Metric(icon: Icons.work_outline, value: '${data['open_jobs']}', label: 'Open jobs'), _Metric(icon: Icons.description_outlined, value: '${data['applications']}', label: 'Applications'), _Metric(icon: Icons.workspace_premium_outlined, value: '${data['selected']}', label: 'Selected'), _Metric(icon: Icons.cancel_outlined, value: '${data['rejected']}', label: 'Rejected')]),
      const SizedBox(height: 26),
      const Text('Applications by status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
      const SizedBox(height: 12),
      _StatusPie(data: data),
    ]));
  }
}

class _StatusPie extends StatelessWidget {
  final Map<String, dynamic> data;
  const _StatusPie({required this.data});
  @override
  Widget build(BuildContext context) {
    final counts = {for (final entry in (data['by_status'] as List? ?? const [])) (entry as Map)['status'] as String: entry['count'] as int};
    final sections = applicationStatuses.where((status) => (counts[status] ?? 0) > 0).map((status) => PieChartSectionData(value: (counts[status] ?? 0).toDouble(), color: statusColor(status), radius: 44, title: '${counts[status]}', titleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white))).toList();
    return Card(child: Padding(padding: const EdgeInsets.all(20), child: sections.isEmpty ? const Text('No applications yet.', style: TextStyle(color: _muted)) : Column(children: [
      SizedBox(height: 200, child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 44, sectionsSpace: 3))),
      const SizedBox(height: 14),
      Wrap(spacing: 14, runSpacing: 6, children: applicationStatuses.map((status) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: statusColor(status), shape: BoxShape.circle)), const SizedBox(width: 5), Text(displayLabel(status), style: const TextStyle(fontSize: 12, color: _muted))])).toList()),
    ])));
  }
}

class AdminUsersPage extends ConsumerWidget {
  const AdminUsersPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminUsersProvider);
    return RefreshIndicator(
      onRefresh: () async { ref.invalidate(adminUsersProvider); await ref.read(adminUsersProvider.future); },
      child: ListView(padding: const EdgeInsets.all(28), children: [
        const _PageTitle(title: 'Users', subtitle: 'All registered accounts. Deactivate to block sign-in without deleting data.'),
        const SizedBox(height: 20),
        state.when(
          loading: () => const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator())),
          error: (error, _) => _ErrorPanel(message: userMessageFor(error), onRetry: () => ref.invalidate(adminUsersProvider)),
          data: (users) => users.isEmpty ? const _EmptyPanel(message: 'No users found.') : Column(children: users.map((user) => _AdminUserRow(user: user)).toList()),
        ),
      ]),
    );
  }
}

class _AdminUserRow extends ConsumerWidget {
  final User user;
  const _AdminUserRow({required this.user});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
    contentPadding: const EdgeInsets.all(16),
    leading: CircleAvatar(backgroundColor: user.isActive ? const Color(0xffeaf4f7) : const Color(0xffffebee), foregroundColor: user.isActive ? _brand : const Color(0xffc62828), child: Text(user.firstName.isEmpty ? 'U' : user.firstName[0].toUpperCase())),
    title: Text(user.displayName.isEmpty ? user.email : user.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text('${user.email} · ${displayLabel(user.role)}${user.applicationCount > 0 ? ' · ${user.applicationCount} applications' : ''}'),
    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
      Chip(label: Text(user.isActive ? 'Active' : 'Disabled'), backgroundColor: user.isActive ? const Color(0xffe8f5e9) : const Color(0xffffebee)),
      Switch(value: user.isActive, onChanged: (value) async { await Api.setUserActive(user.id, value); ref.invalidate(adminUsersProvider); }),
    ]),
  ));
}

class AdminCompaniesPage extends ConsumerWidget {
  const AdminCompaniesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminCompaniesProvider);
    return RefreshIndicator(
      onRefresh: () async { ref.invalidate(adminCompaniesProvider); await ref.read(adminCompaniesProvider.future); },
      child: ListView(padding: const EdgeInsets.all(28), children: [
        const _PageTitle(title: 'Companies', subtitle: 'Every company profile registered on the platform.'),
        const SizedBox(height: 20),
        state.when(
          loading: () => const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator())),
          error: (error, _) => _ErrorPanel(message: userMessageFor(error), onRetry: () => ref.invalidate(adminCompaniesProvider)),
          data: (companies) => companies.isEmpty ? const _EmptyPanel(message: 'No companies yet.') : Column(children: companies.map((company) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(contentPadding: const EdgeInsets.all(16), leading: const CircleAvatar(child: Icon(Icons.business_outlined)), title: Text(company.name, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${company.ownerName.isEmpty ? 'Unknown owner' : company.ownerName} · ${company.openJobs} open / ${company.jobCount} total jobs'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Chip(label: Text(company.isActive ? 'Active' : 'Inactive')), Switch(value: company.isActive, onChanged: (value) async { await Api.adminUpdateCompany(company.id, {'is_active': value}); ref.invalidate(adminCompaniesProvider); })])))).toList()),
        ),
      ]),
    );
  }
}

class AdminJobsPage extends ConsumerWidget {
  const AdminJobsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsState = ref.watch(jobsProvider(const JobFilters(includeClosed: true)));
    return RefreshIndicator(
      onRefresh: () async { ref.invalidate(jobsProvider(const JobFilters(includeClosed: true))); await ref.read(jobsProvider(const JobFilters(includeClosed: true)).future); },
      child: ListView(padding: const EdgeInsets.all(28), children: [
        const _PageTitle(title: 'All job postings', subtitle: 'Review every posting across companies; close anything inappropriate.'),
        const SizedBox(height: 20),
        jobsState.when(
          loading: () => const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator())),
          error: (error, _) => _ErrorPanel(message: userMessageFor(error), onRetry: () => ref.invalidate(jobsProvider(const JobFilters(includeClosed: true)))),
          data: (jobs) => jobs.isEmpty ? const _EmptyPanel(message: 'No job postings yet.') : Column(children: jobs.map((job) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(contentPadding: const EdgeInsets.all(16), title: Text(job.title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${job.companyName} · ${job.location} · ${job.employmentLabel}'), trailing: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [Chip(label: Text(displayLabel(job.status))), if (job.status == 'OPEN') OutlinedButton(onPressed: () async { await Api.closeJob(job.id); ref.invalidate(jobsProvider(const JobFilters(includeClosed: true))); ref.invalidate(adminDashboardProvider); }, child: const Text('Close'))])))).toList()),
        ),
      ]),
    );
  }
}

class AdminApplicationsPage extends ConsumerWidget {
  const AdminApplicationsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applications = ref.watch(applicationsProvider);
    return RefreshIndicator(
      onRefresh: () async { ref.invalidate(applicationsProvider); await ref.read(applicationsProvider.future); },
      child: ListView(padding: const EdgeInsets.all(28), children: [
        const _PageTitle(title: 'All applications', subtitle: 'Every application across the platform with full status history.'),
        const SizedBox(height: 20),
        applications.when(
          loading: () => const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator())),
          error: (error, _) => _ErrorPanel(message: userMessageFor(error), onRetry: () => ref.invalidate(applicationsProvider)),
          data: (items) => items.isEmpty ? const _EmptyPanel(message: 'No applications yet.') : Column(children: items.map((item) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(contentPadding: const EdgeInsets.all(16), leading: CircleAvatar(backgroundColor: statusColor(item.status).withValues(alpha: .12), foregroundColor: statusColor(item.status), child: Text(item.applicantName.isEmpty ? '?' : item.applicantName[0].toUpperCase())), title: Text('${item.applicantName} → ${item.jobTitle}', style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${item.companyName} · Applied ${item.appliedAt.isEmpty ? '—' : item.appliedAt.substring(0, 10)}'), trailing: _StatusChip(status: item.status), onTap: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => ApplicationDetailSheet(application: item, canManage: true))))).toList()),
        ),
      ]),
    );
  }
}

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminDashboardProvider);
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorPanel(message: userMessageFor(error), onRetry: () => ref.invalidate(adminDashboardProvider)),
      data: (data) {
        final topJobs = (data['top_jobs'] as List? ?? const []).cast<Map>();
        final maxCount = topJobs.isEmpty ? 1 : topJobs.map((entry) => entry['count'] as int).reduce((a, b) => a > b ? a : b).toDouble();
        final byStatus = {for (final entry in (data['by_status'] as List? ?? const [])) (entry as Map)['status'] as String: entry['count'] as int};
        return ListView(padding: const EdgeInsets.all(28), children: [
          const _PageTitle(title: 'Platform reports', subtitle: 'Where applications are flowing and how the pipeline converts.'),
          const SizedBox(height: 20),
          Wrap(spacing: 14, runSpacing: 14, children: [_Metric(icon: Icons.description_outlined, value: '${data['applications']}', label: 'Total applications'), _Metric(icon: Icons.workspace_premium_outlined, value: '${data['selected']}', label: 'Selected'), _Metric(icon: Icons.cancel_outlined, value: '${data['rejected']}', label: 'Rejected'), _Metric(icon: Icons.work_off_outlined, value: '${data['closed_jobs']}', label: 'Closed jobs')]),
          const SizedBox(height: 26),
          const Text('Most applied jobs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(20), child: topJobs.isEmpty ? const Text('No applications yet.', style: TextStyle(color: _muted)) : Column(children: [
            SizedBox(height: 180, child: BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxCount * 1.25,
              barTouchData: BarTouchData(enabled: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(show: false),
              barGroups: List.generate(topJobs.length, (index) {
                final entry = topJobs[index];
                return BarChartGroupData(x: index, barRods: [BarChartRodData(toY: (entry['count'] as int).toDouble(), color: _brand, width: 26, borderRadius: BorderRadius.circular(6))]);
              }),
            ))),
            const SizedBox(height: 12),
            ...topJobs.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: _brand, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${entry['job__title']} · ${entry['job__company__name']}', style: const TextStyle(fontSize: 13))),
                  Text('${entry['count']} applications', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ]),
              );
            }),
          ]))),
          const SizedBox(height: 26),
          const Text('Pipeline breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: applicationStatuses.map((status) {
            final count = byStatus[status] ?? 0;
            final total = (data['applications'] as int?) ?? 1;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                SizedBox(width: 96, child: Text(displayLabel(status), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: total == 0 ? 0 : count / total, minHeight: 10, backgroundColor: const Color(0xffeceff1), color: statusColor(status)))),
                const SizedBox(width: 12),
                SizedBox(width: 30, child: Text('$count', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w800))),
              ]),
            );
          }).toList()))),
        ]);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Account (shared by all roles; seekers get profile + resume)
// ---------------------------------------------------------------------------

class AccountPage extends ConsumerStatefulWidget {
  final User user;
  final bool seekerProfile;
  const AccountPage({super.key, required this.user, required this.seekerProfile});
  @override ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  final _headline = TextEditingController();
  final _location = TextEditingController();
  final _bio = TextEditingController();
  final _skills = TextEditingController();
  final _experience = TextEditingController();
  PlatformFile? _resumeFile;
  String _resumeName = '';
  bool _loading = true;
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController(text: widget.user.firstName);
    _lastName = TextEditingController(text: widget.user.lastName);
    _phone = TextEditingController(text: widget.user.phone);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (widget.seekerProfile) {
      try {
        final profile = await Api.profile();
        _headline.text = profile['headline'] as String? ?? '';
        _location.text = profile['location'] as String? ?? '';
        _bio.text = profile['bio'] as String? ?? '';
        _experience.text = '${profile['experience_years'] ?? 0}';
        _skills.text = ((profile['skills'] as List?) ?? const []).join(', ');
        _resumeName = profile['resume_file_url'] as String? ?? profile['resume_url'] as String? ?? '';
      } on ApiException {}
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() { _saving = true; _message = null; });
    try {
      await Api.updateAccount(firstName: _firstName.text.trim(), lastName: _lastName.text.trim(), phone: _phone.text.trim());
      if (widget.seekerProfile) {
        await Api.updateProfile({
          'headline': _headline.text.trim(),
          'location': _location.text.trim(),
          'bio': _bio.text.trim(),
          'experience_years': int.tryParse(_experience.text.trim()) ?? 0,
          'skills': _skills.text.split(',').map((skill) => skill.trim()).where((skill) => skill.isNotEmpty).toList(),
        });
        if (_resumeFile != null) await Api.uploadResume(_resumeFile!);
      }
      if (mounted) setState(() => _message = 'Changes saved successfully.');
    } catch (error) {
      if (mounted) setState(() => _message = userMessageFor(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickResume() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'doc', 'docx'], withData: true);
    if (result != null && mounted) setState(() { _resumeFile = result.files.single; _resumeName = result.files.single.name; });
  }

  @override
  void dispose() { _firstName.dispose(); _lastName.dispose(); _phone.dispose(); _headline.dispose(); _location.dispose(); _bio.dispose(); _skills.dispose(); _experience.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(28), children: [
    _PageTitle(title: widget.seekerProfile ? 'My profile' : 'Account', subtitle: widget.seekerProfile ? 'Keep your career profile and resume current.' : 'Keep your account information current.'),
    const SizedBox(height: 20),
    Card(child: Padding(padding: const EdgeInsets.all(24), child: _loading ? const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())) : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: TextField(controller: _firstName, decoration: const InputDecoration(labelText: 'First name'))), const SizedBox(width: 12), Expanded(child: TextField(controller: _lastName, decoration: const InputDecoration(labelText: 'Last name')))]),
      const SizedBox(height: 14),
      TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone number')),
      if (widget.seekerProfile) ...[
        const SizedBox(height: 14), TextField(controller: _headline, decoration: const InputDecoration(labelText: 'Professional headline')),
        const SizedBox(height: 14), TextField(controller: _location, decoration: const InputDecoration(labelText: 'Location')),
        const SizedBox(height: 14), TextField(controller: _experience, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Years of experience')),
        const SizedBox(height: 14), TextField(controller: _skills, decoration: const InputDecoration(labelText: 'Skills (comma separated)', hintText: 'Python, Django, PostgreSQL')),
        const SizedBox(height: 14), TextField(controller: _bio, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'About you', alignLabelWithHint: true)),
        const SizedBox(height: 14), _UploadTile(label: 'Resume', value: _resumeName, hint: 'PDF, DOC, or DOCX · max 5 MB', icon: Icons.upload_file_outlined, onPressed: _pickResume),
      ],
      if (_message != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_message!, style: TextStyle(color: _message!.contains('success') ? Colors.green.shade700 : Theme.of(context).colorScheme.error))),
      const SizedBox(height: 20),
      FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving...' : 'Save changes')),
    ]))),
  ]);
}

class _UploadTile extends StatelessWidget {
  final String label; final String value; final String hint; final IconData icon; final VoidCallback onPressed;
  const _UploadTile({required this.label, required this.value, required this.hint, required this.icon, required this.onPressed});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xfff8fafc), border: Border.all(color: const Color(0xffd8e0e6)), borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Icon(icon, color: _brand),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(value.isEmpty ? hint : value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: _muted)),
      ])),
      OutlinedButton(onPressed: onPressed, child: Text(value.isEmpty ? 'Choose file' : 'Replace')),
    ]),
  );
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _PageTitle extends StatelessWidget { final String title; final String subtitle; const _PageTitle({required this.title, required this.subtitle}); @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: _ink)), const SizedBox(height: 6), Text(subtitle, style: const TextStyle(color: _muted))]); }
class _Metric extends StatelessWidget { final IconData icon; final String value; final String label; const _Metric({required this.icon, required this.value, required this.label}); @override Widget build(BuildContext context) => SizedBox(width: 190, child: Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [Icon(icon, color: _brand), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)), Text(label, style: const TextStyle(color: _muted, fontSize: 12))])])))); }
class _Fact extends StatelessWidget { final IconData icon; final String value; const _Fact({required this.icon, required this.value}); @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 17, color: _muted), const SizedBox(width: 4), Text(value, style: const TextStyle(fontSize: 13, color: Color(0xff546e7a)))]); }
class _ErrorPanel extends StatelessWidget { final String message; final VoidCallback onRetry; const _ErrorPanel({required this.message, required this.onRetry}); @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(40), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off_outlined, size: 46), const SizedBox(height: 12), Text(message, textAlign: TextAlign.center), const SizedBox(height: 12), OutlinedButton(onPressed: onRetry, child: const Text('Retry'))]))); }
class _EmptyPanel extends StatelessWidget { final String message; const _EmptyPanel({required this.message}); @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(48), child: Center(child: Text(message)))); }
class BrandMark extends StatelessWidget { final bool light; final bool compact; const BrandMark({super.key, this.light = false, this.compact = false}); @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: compact ? 32 : 38, height: compact ? 32 : 38, decoration: BoxDecoration(color: light ? Colors.white : _brand, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.north_east_rounded, color: light ? _brand : Colors.white)), const SizedBox(width: 10), Text('NORTHSTAR', style: TextStyle(color: light ? Colors.white : _ink, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: compact ? 15 : 18))]); }
class _NavItem { final String title; final IconData icon; const _NavItem(this.title, this.icon); }
