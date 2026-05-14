import 'package:flutter/material.dart';
import 'package:avatar_monitoring/pages/login_page.dart';
import 'package:avatar_monitoring/screens/notifs/notification_service.dart';
import 'package:avatar_monitoring/services/api_service.dart';
import 'package:avatar_monitoring/screens/dashboard/dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _checkingSession = true;
  bool _isLoggedIn = false;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final api = ApiService();
    final token = await api.getToken();
    final userId = await api.getUserId();
    setState(() {
      _isLoggedIn = token != null && userId != null;
      _userId = userId;
      _checkingSession = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF0A0D16),
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFF00C8E8)),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'AVATAR Monitoring',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00C8E8),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: _isLoggedIn ? const DashboardScreen() : const LoginPage(),
    );
  }
}
