import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoogleAuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Singleton pattern
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  Future<AuthResponse> signIn() async {
    const webClientId =
        '801084616049-ioc3b45jjvslehjk5n8ctk8t0c40nbin.apps.googleusercontent.com';

    const iosClientId =
        '801084616049-s8sbjcqoo3da4rg58tgm33eal8814vom.apps.googleusercontent.com';

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: Platform.isIOS ? iosClientId : null,
        serverClientId: Platform.isIOS ? null : webClientId,
        scopes: ['email', 'profile'],
      );

      // Make sure we're signed out before attempting to sign in
      try {
        await googleSignIn.signOut();
      } catch (e) {
        debugPrint('Error signing out from previous session: $e');
      }

      // Attempt to sign in
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw AuthException('Google Sign In was cancelled by user');
      }

      // Get authentication details
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null) {
        throw AuthException('No Access Token found.');
      }
      if (idToken == null) {
        throw AuthException('No ID Token found.');
      }

      debugPrint(
        'Google Sign In successful. Proceeding with Supabase authentication...',
      );

      // Sign in with Supabase
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      debugPrint('Supabase authentication successful.');
      return response;
    } on AuthException {
      rethrow;
    } catch (error) {
      debugPrint('Google Sign In error: $error');
      if (error.toString().toLowerCase().contains('cancel') ||
          error.toString().toLowerCase().contains('cancelled')) {
        throw AuthException('Google Sign In was cancelled');
      }
      throw AuthException('Failed to sign in with Google: $error');
    }
  }
}
