import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_log_in/providers/auth_provider.dart';
import 'package:social_log_in/providers/user_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userStateProvider);
    final auth = ref.watch(authProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundImage:
                  user?.userMetadata?['avatar_url'] != null
                      ? NetworkImage(
                        user!.userMetadata!['avatar_url'] as String,
                      )
                      : null,
              child:
                  user?.userMetadata?['avatar_url'] == null
                      ? const Icon(Icons.person)
                      : null,
            ),
            title: Text(user?.email ?? 'No email'),
            subtitle: const Text('Profile'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              try {
                await auth.signOut();
                if (context.mounted) {
                  // Navigate to login page and remove all previous routes
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
