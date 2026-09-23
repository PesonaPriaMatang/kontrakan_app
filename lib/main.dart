import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');

  await Supabase.initialize(
    url: 'https://nrownptblroxeoffbiny.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5yb3ducHRibHJveGVvZmZiaW55Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxNjIyMjcsImV4cCI6MjEwNTczODIyN30.jB3wfwb9B_p32oe5IYQTXoytY66gOpIWk-Mvdd1mEHo',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      title: 'Kontrakan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: session != null ? const HomePage() : const LoginPage(),
    );
  }
}
