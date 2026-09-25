import 'package:flutter/material.dart';

import 'core/api.dart';
import 'models.dart';

const _brand = Color(0xff214e6b);
const _ink = Color(0xff162f3d);

class JobPortalApp extends StatefulWidget {
  const JobPortalApp({super.key});

  @override
  State<JobPortalApp> createState() => _JobPortalAppState();
}

class _JobPortalAppState extends State<JobPortalApp> {
  User? _user;

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(seedColor: _brand, brightness: Brightness.light);
    return MaterialApp(
      title: 'Northstar Jobs',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colors,
        scaffoldBackgroundColor: const Color(0xfff6f8fa),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: _ink, elevation: 0),
        cardTheme: const CardThemeData(elevation: 0, color: Colors.white, margin: EdgeInsets.zero),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xfff8fafc),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xffd8e0e6))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xffd8e0e6))),
        ),
      ),
      home: _user == null
          ? LoginPage(onLogin: (user) => setState(() => _user = user))
          : PortalShell(user: _user!, onLogout: () async { await Api.logout(); if (mounted) setState(() => _user = null); }),
    );
  }
}

class LoginPage extends StatefulWidget {
  final ValueChanged<User> onLogin;
  const LoginPage({super.key, required this.onLogin});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController(text: 'seeker@example.com');
  final _password = TextEditingController(text: 'SeekerDemo123!');
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _submit() async {
    setState(() { _busy = true; _error = null; });
    try {
      widget.onLogin(await Api.login(_email.text.trim(), _password.text));
    } catch (_) {
      if (mounted) setState(() => _error = 'We could not sign you in. Make sure the local API is running.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _useDemo(String email, String password) {
    setState(() { _email.text = email; _password.text = password; _error = null; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 850;
        final signIn = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const BrandMark(compact: true),
                const SizedBox(height: 30),
                Text('Welcome back', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: _ink)),
                const SizedBox(height: 8),
                Text('Sign in to manage your career journey.', style: TextStyle(color: Colors.blueGrey.shade600)),
                const SizedBox(height: 28),
                TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline))),
                const SizedBox(height: 14),
                TextField(controller: _password, obscureText: _obscurePassword, onSubmitted: (_) => _submit(), decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)))),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                const SizedBox(height: 22),
                SizedBox(width: double.infinity, height: 48, child: FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Sign in'))),
                const SizedBox(height: 20),
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xffeff6f8), borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Local demo accounts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _ink)), const SizedBox(height: 8), Wrap(spacing: 6, runSpacing: 6, children: [ActionChip(label: const Text('Job seeker'), onPressed: () => _useDemo('seeker@example.com', 'SeekerDemo123!')), ActionChip(label: const Text('Recruiter'), onPressed: () => _useDemo('recruiter@example.com', 'RecruiterDemo123!')), ActionChip(label: const Text('Admin'), onPressed: () => _useDemo('admin@example.com', 'AdminDemo123!'))])])),
              ]),
            ),
          ),
        );
        if (!wide) return SafeArea(child: Center(child: Padding(padding: const EdgeInsets.all(20), child: signIn)));
        return Row(children: [
          const Expanded(flex: 6, child: _LoginBrandPanel()),
          Expanded(flex: 5, child: Center(child: Padding(padding: const EdgeInsets.all(40), child: signIn))),
        ]);
      }),
    );
  }
}

class _LoginBrandPanel extends StatelessWidget {
  const _LoginBrandPanel();
  @override
  Widget build(BuildContext context) => Container(
    color: _brand,
    padding: const EdgeInsets.all(64),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      const BrandMark(light: true),
      const SizedBox(height: 72),
      const Text('The right opportunity\nchanges everything.', style: TextStyle(color: Colors.white, fontSize: 44, height: 1.12, fontWeight: FontWeight.w800)),
      const SizedBox(height: 22),
      const Text('Discover roles that match your skills, track every application, and take the next step with confidence.', style: TextStyle(color: Color(0xffd9e9f0), fontSize: 17, height: 1.6)),
      const SizedBox(height: 38),
      const Wrap(spacing: 20, runSpacing: 12, children: [ _Feature(icon: Icons.verified_outlined, label: 'Trusted employers'), _Feature(icon: Icons.bolt_outlined, label: 'Simple applications'), _Feature(icon: Icons.insights_outlined, label: 'Clear progress') ]),
    ]),
  );
}

class _Feature extends StatelessWidget {
  final IconData icon; final String label;
  const _Feature({required this.icon, required this.label});
  @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: const Color(0xff7ed6c2), size: 19), const SizedBox(width: 7), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))]);
}

class PortalShell extends StatefulWidget {
  final User user; final VoidCallback onLogout;
  const PortalShell({super.key, required this.user, required this.onLogout});
  @override State<PortalShell> createState() => _PortalShellState();
}

class _PortalShellState extends State<PortalShell> {
  int _section = 0;
  static const _seekerItems = [
    _NavigationItem('Overview', Icons.grid_view_rounded),
    _NavigationItem('Explore jobs', Icons.work_outline_rounded),
    _NavigationItem('My applications', Icons.description_outlined),
    _NavigationItem('Saved jobs', Icons.bookmark_border_rounded),
    _NavigationItem('My profile', Icons.person_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final desktop = constraints.maxWidth >= 960;
    final items = _itemsForRole(widget.user.role);
    final content = widget.user.role == 'ADMIN'
        ? AdminDashboardContent(section: _section, items: items)
        : widget.user.role == 'RECRUITER'
            ? RecruiterDashboardContent(section: _section, items: items)
            : DashboardContent(user: widget.user, section: _section, onSectionChange: (value) => setState(() => _section = value));
    return Scaffold(
      appBar: PortalAppBar(user: widget.user, onLogout: widget.onLogout),
      drawer: desktop ? null : NavigationDrawer(children: [_NavigationMenu(items: items, selected: _section, onSelect: (value) { setState(() => _section = value); Navigator.pop(context); })]),
      body: Row(children: [
        if (desktop) SizedBox(width: 250, child: ColoredBox(color: Colors.white, child: _NavigationMenu(items: items, selected: _section, onSelect: (value) => setState(() => _section = value)))),
        Expanded(child: content),
      ]),
    );
  });
}

class PortalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final User user; final VoidCallback onLogout;
  const PortalAppBar({super.key, required this.user, required this.onLogout});
  @override Size get preferredSize => const Size.fromHeight(72);
  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 72,
    title: const Padding(padding: EdgeInsets.only(left: 6), child: BrandMark(compact: true)),
    actions: [
      IconButton(tooltip: 'Notifications', onPressed: () {}, icon: const Badge(smallSize: 8, child: Icon(Icons.notifications_none_rounded))),
      const SizedBox(width: 8),
      PopupMenuButton<String>(onSelected: (value) { if (value == 'logout') onLogout(); }, itemBuilder: (_) => const [PopupMenuItem(value: 'logout', child: Text('Sign out'))], child: Padding(padding: const EdgeInsets.only(right: 20), child: Row(children: [CircleAvatar(backgroundColor: const Color(0xffd9ecf2), foregroundColor: _brand, child: Text(user.firstName.isEmpty ? 'U' : user.firstName[0].toUpperCase())), const SizedBox(width: 10), if (MediaQuery.sizeOf(context).width > 600) Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${user.firstName} ${user.lastName}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), Text(_roleName(user.role), style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600))]), const Icon(Icons.expand_more_rounded)]))),
    ],
  );
}

class _NavigationMenu extends StatelessWidget {
  final List<_NavigationItem> items; final int selected; final ValueChanged<int> onSelect;
  const _NavigationMenu({required this.items, required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(12, 20, 12, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Padding(padding: EdgeInsets.fromLTRB(14, 0, 14, 12), child: Text('WORKSPACE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Color(0xff78909c)))),
    ...List.generate(items.length, (index) { final item = items[index]; final active = selected == index; return Padding(padding: const EdgeInsets.only(bottom: 4), child: ListTile(leading: Icon(item.icon, color: active ? _brand : const Color(0xff607d8b)), title: Text(item.title, style: TextStyle(fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? _brand : _ink)), selected: active, selectedTileColor: const Color(0xffeaf4f7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), onTap: () => onSelect(index))); }),
    const Spacer(),
    Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xffeff6f8), borderRadius: BorderRadius.circular(14)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.lightbulb_outline_rounded, color: _brand), SizedBox(height: 10), Text('Complete your profile', style: TextStyle(fontWeight: FontWeight.w800)), SizedBox(height: 4), Text('Stand out to more employers.', style: TextStyle(fontSize: 12, color: Color(0xff546e7a)))])),
  ])));
}

class DashboardContent extends StatefulWidget {
  final User user; final int section; final ValueChanged<int> onSectionChange;
  const DashboardContent({super.key, required this.user, required this.section, required this.onSectionChange});
  @override State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  List<Job> _jobs = []; bool _loading = true; String _query = '';
  @override void initState() { super.initState(); _loadJobs(); }
  Future<void> _loadJobs() async { setState(() => _loading = true); try { _jobs = await Api.jobs(); } finally { if (mounted) setState(() => _loading = false); } }
  @override
  Widget build(BuildContext context) {
    if (widget.section > 1) return _EmptyWorkspace(section: _PortalShellState._seekerItems[widget.section].title, onExplore: () => widget.onSectionChange(1));
    final jobs = _jobs.where((job) => job.title.toLowerCase().contains(_query.toLowerCase()) || job.location.toLowerCase().contains(_query.toLowerCase()) || job.skills.join(' ').toLowerCase().contains(_query.toLowerCase())).toList();
    return RefreshIndicator(onRefresh: _loadJobs, child: ListView(padding: const EdgeInsets.fromLTRB(28, 30, 28, 48), children: [
      _WelcomeBanner(user: widget.user, jobsCount: _jobs.length, onExplore: () => widget.onSectionChange(1)),
      const SizedBox(height: 28),
      if (widget.section == 0) ...[const _SectionHeading(title: 'Your activity', subtitle: 'A quick view of your career journey.'), const SizedBox(height: 14), const _StatsRow(), const SizedBox(height: 34)],
      _SectionHeading(title: widget.section == 0 ? 'Recommended for you' : 'Explore open roles', subtitle: widget.section == 0 ? 'Fresh roles matched to your interests.' : 'Search current opportunities from verified employers.'),
      const SizedBox(height: 16),
      _SearchPanel(query: _query, onChanged: (value) => setState(() => _query = value)),
      const SizedBox(height: 20),
      if (_loading)
        const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator()))
      else if (jobs.isEmpty)
        _NoJobs(onClear: () => setState(() => _query = ''))
      else
        ...jobs.map(
          (job) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: ProfessionalJobCard(
              job: job,
              onOpen: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => JobDetailSheet(job: job),
              ),
            ),
          ),
        ),
    ]));
  }
}

class AdminDashboardContent extends StatefulWidget {
  final int section; final List<_NavigationItem> items;
  const AdminDashboardContent({super.key, required this.section, required this.items});
  @override State<AdminDashboardContent> createState() => _AdminDashboardContentState();
}

class _AdminDashboardContentState extends State<AdminDashboardContent> {
  Map<String, dynamic>? _metrics; String? _error;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { _metrics = await Api.adminDashboard(); } on ApiException catch (error) { _error = error.message; } if (mounted) setState(() {}); }
  @override Widget build(BuildContext context) {
    if (widget.section > 0) return _EmptyWorkspace(section: widget.items[widget.section].title, onExplore: () {});
    if (_metrics == null && _error == null) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _DashboardError(message: _error!, onRetry: _load);
    final m = _metrics!;
    return RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.fromLTRB(28, 30, 28, 48), children: [
      const _RoleBanner(title: 'System overview', subtitle: 'Monitor platform health, hiring activity, and user growth.', icon: Icons.admin_panel_settings_outlined),
      const SizedBox(height: 28),
      const _SectionHeading(title: 'Platform metrics', subtitle: 'Live totals from the recruitment system.'),
      const SizedBox(height: 14),
      Wrap(spacing: 14, runSpacing: 14, children: [
        _MetricCard(icon: Icons.people_outline, value: '${m['users']}', label: 'Total users'),
        _MetricCard(icon: Icons.business_outlined, value: '${m['companies']}', label: 'Companies'),
        _MetricCard(icon: Icons.work_outline, value: '${m['open_jobs']}', label: 'Open jobs'),
        _MetricCard(icon: Icons.description_outlined, value: '${m['applications']}', label: 'Applications'),
      ]),
      const SizedBox(height: 32),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hiring outcomes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 18),
              Wrap(spacing: 36, runSpacing: 16, children: [
                _Outcome(label: 'Selected candidates', value: '${m['selected']}'),
                _Outcome(label: 'Rejected applications', value: '${m['rejected']}'),
                _Outcome(label: 'Registered recruiters', value: '${m['recruiters']}'),
                _Outcome(label: 'Job seekers', value: '${m['seekers']}'),
              ]),
            ],
          ),
        ),
      ),
    ]));
  }
}

class RecruiterDashboardContent extends StatefulWidget {
  final int section; final List<_NavigationItem> items;
  const RecruiterDashboardContent({super.key, required this.section, required this.items});
  @override State<RecruiterDashboardContent> createState() => _RecruiterDashboardContentState();
}

class _RecruiterDashboardContentState extends State<RecruiterDashboardContent> {
  Map<String, dynamic>? _metrics; String? _error;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { _metrics = await Api.recruiterDashboard(); } on ApiException catch (error) { _error = error.message; } if (mounted) setState(() {}); }
  @override Widget build(BuildContext context) {
    if (widget.section > 0) return _EmptyWorkspace(section: widget.items[widget.section].title, onExplore: () {});
    if (_metrics == null && _error == null) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _DashboardError(message: _error!, onRetry: _load);
    final m = _metrics!;
    return RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.fromLTRB(28, 30, 28, 48), children: [
      const _RoleBanner(title: 'Hiring workspace', subtitle: 'Track your open roles and move the right candidates forward.', icon: Icons.groups_2_outlined),
      const SizedBox(height: 28),
      const _SectionHeading(title: 'Recruitment pulse', subtitle: 'Your hiring activity at a glance.'),
      const SizedBox(height: 14),
      Wrap(spacing: 14, runSpacing: 14, children: [
        _MetricCard(icon: Icons.work_outline, value: '${m['active_jobs']}', label: 'Active jobs'),
        _MetricCard(icon: Icons.description_outlined, value: '${m['applications']}', label: 'Applicants'),
        _MetricCard(icon: Icons.event_available_outlined, value: '${m['interviews']}', label: 'Interviews'),
        _MetricCard(icon: Icons.workspace_premium_outlined, value: '${m['selected']}', label: 'Selected'),
      ]),
      const SizedBox(height: 32),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Recent applications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 16),
              if ((m['recent_applications'] as List).isEmpty)
                const Text('New applicants will appear here.')
              else
                ...((m['recent_applications'] as List).map(
                  (application) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                    title: Text('${application['applicant']['first_name']} ${application['applicant']['last_name']}'),
                    subtitle: Text(application['job_title'] as String),
                    trailing: Chip(label: Text(application['status'] as String)),
                  ),
                )),
            ],
          ),
        ),
      ),
    ]));
  }
}

class _RoleBanner extends StatelessWidget {
  final String title; final String subtitle; final IconData icon;
  const _RoleBanner({required this.title, required this.subtitle, required this.icon});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_brand, Color(0xff34728a)]), borderRadius: BorderRadius.circular(20)), child: Row(children: [Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white.withOpacity(.16), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: Colors.white, size: 30)), const SizedBox(width: 18), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text(subtitle, style: const TextStyle(color: Color(0xffdcecf2), fontSize: 15))]))]));
}

class _Outcome extends StatelessWidget {
  final String label; final String value;
  const _Outcome({required this.label, required this.value});
  @override Widget build(BuildContext context) => SizedBox(width: 155, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: _brand)), const SizedBox(height: 3), Text(label, style: const TextStyle(color: Color(0xff607d8b), fontSize: 12))]));
}

class _DashboardError extends StatelessWidget {
  final String message; final VoidCallback onRetry;
  const _DashboardError({required this.message, required this.onRetry});
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off_outlined, size: 44, color: Color(0xff78909c)), const SizedBox(height: 12), Text(message, textAlign: TextAlign.center), const SizedBox(height: 12), OutlinedButton(onPressed: onRetry, child: const Text('Retry'))])));
}

class _WelcomeBanner extends StatelessWidget {
  final User user; final int jobsCount; final VoidCallback onExplore;
  const _WelcomeBanner({required this.user, required this.jobsCount, required this.onExplore});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_brand, Color(0xff34728a)]), borderRadius: BorderRadius.circular(20)), child: Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 22, crossAxisAlignment: WrapCrossAlignment.center, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Good to see you, ${user.firstName}.', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)), const SizedBox(height: 7), Text('$jobsCount open role${jobsCount == 1 ? '' : 's'} are available right now.', style: const TextStyle(color: Color(0xffdcecf2), fontSize: 15))]), OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0xffb8d7e1))), onPressed: onExplore, icon: const Icon(Icons.arrow_forward_rounded), label: const Text('Explore jobs'))]));
}

class _SectionHeading extends StatelessWidget {
  final String title; final String subtitle;
  const _SectionHeading({required this.title, required this.subtitle});
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: _ink)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(color: Colors.blueGrey.shade600))]);
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();
  @override Widget build(BuildContext context) => Wrap(spacing: 14, runSpacing: 14, children: const [_MetricCard(icon: Icons.send_outlined, value: '0', label: 'Applications'), _MetricCard(icon: Icons.bookmark_outline, value: '0', label: 'Saved roles'), _MetricCard(icon: Icons.visibility_outlined, value: '0', label: 'Profile views')]);
}

class _MetricCard extends StatelessWidget {
  final IconData icon; final String value; final String label;
  const _MetricCard({required this.icon, required this.value, required this.label});
  @override Widget build(BuildContext context) => SizedBox(width: 190, child: Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xffeaf4f7), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: _brand)), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink)), Text(label, style: const TextStyle(color: Color(0xff607d8b), fontSize: 12))])]))));
}

class _SearchPanel extends StatelessWidget {
  final String query; final ValueChanged<String> onChanged;
  const _SearchPanel({required this.query, required this.onChanged});
  @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [SizedBox(width: 440, child: TextField(onChanged: onChanged, decoration: const InputDecoration(hintText: 'Search by role, skill, or location', prefixIcon: Icon(Icons.search_rounded), isDense: true))), OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.tune_rounded), label: const Text('Filters'))])));
}

class ProfessionalJobCard extends StatelessWidget {
  final Job job; final VoidCallback onOpen;
  const ProfessionalJobCard({super.key, required this.job, required this.onOpen});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(22), child: LayoutBuilder(builder: (context, constraints) { final detailsWidth = constraints.maxWidth > 630 ? constraints.maxWidth - 260 : constraints.maxWidth > 80 ? constraints.maxWidth - 66 : constraints.maxWidth; return Wrap(spacing: 18, runSpacing: 18, crossAxisAlignment: WrapCrossAlignment.start, children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xffeaf4f7), borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: Text(job.companyName.isEmpty ? 'N' : job.companyName.substring(0, 1).toUpperCase(), style: const TextStyle(color: _brand, fontSize: 20, fontWeight: FontWeight.w800))), SizedBox(width: detailsWidth, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(job.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink))), const Icon(Icons.bookmark_border_rounded, color: Color(0xff607d8b))]), const SizedBox(height: 5), Text(job.companyName, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xff47616f))), const SizedBox(height: 12), Wrap(spacing: 14, runSpacing: 8, children: [_JobFact(icon: Icons.location_on_outlined, text: job.location), _JobFact(icon: Icons.business_center_outlined, text: job.employmentLabel), _JobFact(icon: Icons.laptop_mac_outlined, text: job.workModeLabel)]), if (job.skills.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 15), child: Wrap(spacing: 7, runSpacing: 7, children: job.skills.take(4).map((skill) => Chip(label: Text(skill), visualDensity: VisualDensity.compact, backgroundColor: const Color(0xfff0f5f7), side: BorderSide.none)).toList())), const SizedBox(height: 18), Align(alignment: Alignment.centerRight, child: FilledButton.tonal(onPressed: onOpen, child: const Text('View role')))]))]); })));
}

class JobDetailSheet extends StatefulWidget {
  final Job job;
  const JobDetailSheet({super.key, required this.job});
  @override State<JobDetailSheet> createState() => _JobDetailSheetState();
}

class _JobDetailSheetState extends State<JobDetailSheet> {
  final _coverLetter = TextEditingController(); bool _submitting = false; String? _error;
  @override void dispose() { _coverLetter.dispose(); super.dispose(); }
  Future<void> _apply() async { setState(() { _submitting = true; _error = null; }); try { await Api.apply(widget.job.id, coverLetter: _coverLetter.text.trim()); if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application submitted successfully.'))); } } on ApiException catch (error) { if (mounted) setState(() => _error = error.message); } finally { if (mounted) setState(() => _submitting = false); } }
  @override Widget build(BuildContext context) => Container(height: MediaQuery.sizeOf(context).height * .88, decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))), child: SafeArea(top: false, child: ListView(padding: const EdgeInsets.fromLTRB(28, 16, 28, 32), children: [Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: const Color(0xffcfd8dc), borderRadius: BorderRadius.circular(10)))), const SizedBox(height: 26), Text(widget.job.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _ink)), const SizedBox(height: 7), Text(widget.job.companyName, style: const TextStyle(fontSize: 16, color: Color(0xff47616f), fontWeight: FontWeight.w600)), const SizedBox(height: 20), Wrap(spacing: 10, runSpacing: 10, children: [Chip(label: Text(widget.job.location)), Chip(label: Text(widget.job.employmentLabel)), Chip(label: Text(widget.job.workModeLabel)), Chip(label: Text(widget.job.salaryLabel))]), const SizedBox(height: 28), const Text('About the role', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)), const SizedBox(height: 9), Text(widget.job.description.isEmpty ? 'The recruiter has not added a detailed description yet.' : widget.job.description, style: const TextStyle(height: 1.6, color: Color(0xff455a64))), const SizedBox(height: 24), const Text('Key skills', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)), const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: widget.job.skills.map((skill) => Chip(label: Text(skill), backgroundColor: const Color(0xffeaf4f7), side: BorderSide.none)).toList()), const SizedBox(height: 28), TextField(controller: _coverLetter, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Cover letter (optional)', alignLabelWithHint: true, hintText: 'Briefly explain why you are a strong match.')), if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))), const SizedBox(height: 18), SizedBox(height: 50, child: FilledButton(onPressed: _submitting || !widget.job.isOpen ? null : _apply, child: _submitting ? const CircularProgressIndicator(color: Colors.white) : Text(widget.job.isOpen ? 'Apply for this role' : 'Role closed')))])));
}

class _JobFact extends StatelessWidget {
  final IconData icon; final String text;
  const _JobFact({required this.icon, required this.text});
  @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 17, color: const Color(0xff607d8b)), const SizedBox(width: 5), Text(text, style: const TextStyle(fontSize: 13, color: Color(0xff546e7a)))]);
}

class _NoJobs extends StatelessWidget {
  final VoidCallback onClear; const _NoJobs({required this.onClear});
  @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(52), child: Column(children: [const Icon(Icons.search_off_rounded, size: 48, color: Color(0xff78909c)), const SizedBox(height: 14), const Text('No matching roles found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 6), const Text('Try another title, skill, or location.'), const SizedBox(height: 18), TextButton(onPressed: onClear, child: const Text('Clear search'))])));
}

class _EmptyWorkspace extends StatelessWidget {
  final String section; final VoidCallback onExplore;
  const _EmptyWorkspace({required this.section, required this.onExplore});
  @override Widget build(BuildContext context) => Center(child: Card(child: Padding(padding: const EdgeInsets.all(48), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.auto_awesome_outlined, size: 48, color: _brand), const SizedBox(height: 18), Text(section, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink)), const SizedBox(height: 8), const Text('This section is ready for your activity.'), const SizedBox(height: 20), FilledButton(onPressed: onExplore, child: const Text('Explore jobs'))]))));
}

class BrandMark extends StatelessWidget {
  final bool light; final bool compact;
  const BrandMark({super.key, this.light = false, this.compact = false});
  @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: compact ? 32 : 38, height: compact ? 32 : 38, decoration: BoxDecoration(color: light ? Colors.white : _brand, borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: Icon(Icons.north_east_rounded, color: light ? _brand : Colors.white, size: compact ? 19 : 23)), const SizedBox(width: 10), Text('NORTHSTAR', style: TextStyle(color: light ? Colors.white : _ink, fontSize: compact ? 15 : 18, fontWeight: FontWeight.w900, letterSpacing: 1.3))]);
}

class _NavigationItem {
  final String title; final IconData icon;
  const _NavigationItem(this.title, this.icon);
}

List<_NavigationItem> _itemsForRole(String role) {
  if (role == 'ADMIN') return const [
    _NavigationItem('Overview', Icons.grid_view_rounded),
    _NavigationItem('Users', Icons.people_outline_rounded),
    _NavigationItem('Companies', Icons.business_outlined),
    _NavigationItem('Jobs', Icons.work_outline_rounded),
    _NavigationItem('Reports', Icons.bar_chart_outlined),
  ];
  if (role == 'RECRUITER') return const [
    _NavigationItem('Overview', Icons.grid_view_rounded),
    _NavigationItem('My jobs', Icons.work_outline_rounded),
    _NavigationItem('Applicants', Icons.groups_outlined),
    _NavigationItem('Company profile', Icons.business_outlined),
    _NavigationItem('Settings', Icons.settings_outlined),
  ];
  return _PortalShellState._seekerItems;
}

String _roleName(String role) => switch (role) { 'ADMIN' => 'Administrator', 'RECRUITER' => 'Recruiter', _ => 'Job seeker' };
