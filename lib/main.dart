import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_log_in/pages/main_layout.dart';
import 'package:social_log_in/pages/login_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:social_log_in/constants.dart';

// Custom page route transition
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final String? routeName;

  SlidePageRoute({required this.page, this.routeName})
    : super(
        settings: RouteSettings(name: routeName),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Constants.supabaseUrl,
    anonKey: Constants.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder:
                  (context) => StreamBuilder<AuthState>(
                    stream: Supabase.instance.client.auth.onAuthStateChange,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final session = snapshot.data?.session;
                        return session != null
                            ? const MainLayout()
                            : const LoginPage();
                      }
                      return const LoginPage();
                    },
                  ),
            );
          case '/login':
            return SlidePageRoute(
              page: const LoginPage(),
              routeName: settings.name,
            );
          case '/home':
            return SlidePageRoute(
              page: const MainLayout(),
              routeName: settings.name,
            );
          default:
            return MaterialPageRoute(
              builder:
                  (context) => const Scaffold(
                    body: Center(child: Text('Route not found')),
                  ),
            );
        }
      },
    );
  }
}
