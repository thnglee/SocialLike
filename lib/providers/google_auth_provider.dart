import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'google_auth_provider.g.dart';

@riverpod
class GoogleAuth extends _$GoogleAuth {
  @override
  FutureOr<void> build() {}

  Future<AuthResponse> signIn() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId:
            Platform.isIOS
                ? '801084616049-s8sbjcqoo3da4rg58tgm33eal8814vom.apps.googleusercontent.com'
                : null,
        serverClientId:
            '801084616049-ioc3b45jjvslehjk5n8ctk8t0c40nbin.apps.googleusercontent.com',
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

      debugPrint('Google Sign In successful, getting auth details...');

      // Get authentication details
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      debugPrint(
        'Got tokens - accessToken: ${accessToken != null}, idToken: ${idToken != null}',
      );

      if (accessToken == null) {
        throw AuthException('No Access Token found.');
      }
      if (idToken == null) {
        throw AuthException('No ID Token found.');
      }

      debugPrint('Proceeding with Supabase authentication...');

      // Sign in with Supabase
      final response = await Supabase.instance.client.auth.signInWithIdToken(
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
