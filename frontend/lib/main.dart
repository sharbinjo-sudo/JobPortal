import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A last-resort view for an unexpected widget-build failure. Expected API
  // failures are handled in the feature UI with a useful message and Retry.
  ErrorWidget.builder = (_) => const _ApplicationErrorScreen();

  // Session restore must never block startup: run configure() defensively so a
  // wedged storage plugin cannot keep the app on a blank screen. The auth
  // controller re-checks the session itself right after launch.
  try {
    await Api.configure().timeout(const Duration(seconds: 4));
  } catch (_) {
    // Storage unavailable — the resilient token store degrades to memory and
    // the user simply signs in again; never worth crashing or hanging over.
  }

  runApp(const ProviderScope(child: JobPortalApp()));
}

class _ApplicationErrorScreen extends StatelessWidget {
  const _ApplicationErrorScreen();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Color(0xff214e6b)),
              SizedBox(height: 16),
              Text('Something needs attention', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              Text('Please refresh the page and try again.', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ),
  );
}
