import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_log_in/pages/scan_page.dart';
import 'package:social_log_in/pages/feed_page.dart';
import 'package:social_log_in/pages/settings_page.dart';

final currentPageProvider = StateProvider<int>((ref) => 0);

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  late PageController _pageController;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: ref.read(currentPageProvider),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _animateToPage(int page) async {
    if (_isAnimating) return;

    _isAnimating = true;
    await _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _isAnimating = false;
  }

  @override
  Widget build(BuildContext context) {
    final currentPageIndex = ref.watch(currentPageProvider);

    // Listen to page changes from the provider
    ref.listen(currentPageProvider, (previous, next) {
      if (previous != next && _pageController.hasClients && !_isAnimating) {
        _animateToPage(next);
      }
    });

    // List of pages
    final pages = [const ScanPage(), const FeedPage(), const SettingsPage()];

    return WillPopScope(
      onWillPop: () async {
        if (currentPageIndex != 1) {
          ref.read(currentPageProvider.notifier).state = 1;
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            if (currentPageIndex != index && !_isAnimating) {
              ref.read(currentPageProvider.notifier).state = index;
            }
          },
          physics: const ClampingScrollPhysics(), // Allow free scrolling
          children: pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentPageIndex,
          onDestinationSelected: (int index) {
            if (currentPageIndex != index) {
              ref.read(currentPageProvider.notifier).state = index;
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.qr_code_scanner_outlined),
              selectedIcon: Icon(Icons.qr_code_scanner),
              label: 'Scan',
            ),
            NavigationDestination(
              icon: Icon(Icons.feed_outlined),
              selectedIcon: Icon(Icons.feed),
              label: 'Feed',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
