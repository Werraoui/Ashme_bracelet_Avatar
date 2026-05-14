import 'package:flutter/material.dart';
import 'package:avatar_monitoring/pages/login_page.dart';
import 'package:avatar_monitoring/screens/dashboard/dashboard.dart';
import 'package:avatar_monitoring/services/api_service.dart';

/// Auth gate — checks for a stored JWT token on startup and routes accordingly.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _authenticated = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final api = ApiService();
    final token = await api.getToken();
    final userId = await api.getUserId();
    setState(() {
      _authenticated = token != null && userId != null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0D16),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00C8E8))),
      );
    }
    return _authenticated ? const DashboardScreen() : const LoginPage();
  }
}
