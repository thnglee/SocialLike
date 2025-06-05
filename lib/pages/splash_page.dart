import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _isRedirecting = false;
  late final StreamSubscription<AuthState> _authStateSubscription;

  @override
  void initState() {
    super.initState();
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange
        .listen((data) {
          if (_isRedirecting) return;
          final session = data.session;
          if (session != null) {
            _isRedirecting = true;
            Navigator.of(context).pushReplacementNamed('/home');
          }
        });
    _redirect();
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  Future<void> _redirect() async {
    await Future.delayed(Duration.zero);
    if (!mounted || _isRedirecting) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      _isRedirecting = true;
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      _isRedirecting = true;
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
