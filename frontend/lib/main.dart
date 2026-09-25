import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/api.dart';
Future<void> main() async { WidgetsFlutterBinding.ensureInitialized(); await Api.configure(); runApp(const ProviderScope(child: JobPortalApp())); }
