import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'user_provider.g.dart';

@riverpod
class UserState extends _$UserState {
  @override
  User? build() {
    return Supabase.instance.client.auth.currentUser;
  }

  void updateUser(User? user) {
    state = user;
  }
}
