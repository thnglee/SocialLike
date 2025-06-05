import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_log_in/components/post_card.dart';
import 'package:social_log_in/models/post.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final postsProvider = AsyncNotifierProvider<PostsNotifier, List<Post>>(() {
  return PostsNotifier();
});

class PostsNotifier extends AsyncNotifier<List<Post>> {
  @override
  Future<List<Post>> build() async {
    return _fetchPosts();
  }

  Future<List<Post>> _fetchPosts() async {
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('posts')
          .select('''
            *,
            profiles!inner (
              username,
              avatar_url
            )
          ''')
          .order('created_at', ascending: false);

      return data.map<Post>((post) {
        final profile = post['profiles'] as Map<String, dynamic>;
        return Post(
          id: post['id'] as String,
          userId: post['user_id'] as String,
          username: profile['username'] as String? ?? 'Unknown User',
          userAvatar: profile['avatar_url'] as String?,
          createdAt: DateTime.parse(post['created_at'] as String),
          location: post['location'] as String,
          latitude:
              post['latitude'] == null
                  ? 0.0
                  : (post['latitude'] as num).toDouble(),
          longitude:
              post['longitude'] == null
                  ? 0.0
                  : (post['longitude'] as num).toDouble(),
          imageUrl: post['image_url'] as String,
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch posts: $e');
    }
  }

  Future<void> refreshPosts() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchPosts());
  }
}

class FeedPage extends ConsumerWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(postsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(postsProvider.notifier).refreshPosts();
            },
          ),
        ],
      ),
      body: postsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data:
            (posts) => RefreshIndicator(
              onRefresh: () => ref.read(postsProvider.notifier).refreshPosts(),
              child:
                  posts.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No posts yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to share a moment!',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          return PostCard(
                            post: posts[index],
                            onPostDeleted: () {
                              ref.read(postsProvider.notifier).refreshPosts();
                            },
                          );
                        },
                      ),
            ),
      ),
    );
  }
}
