import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:social_log_in/services/google_auth_service.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _googleAuth = GoogleAuthService();

  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Get current session
  Session? get currentSession => _supabase.auth.currentSession;

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  // Sign in with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign up with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signUp(email: email, password: password);
  }

  // Sign in with Google
  Future<AuthResponse> signInWithGoogle() async {
    return await _googleAuth.signIn();
  }

  // Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
