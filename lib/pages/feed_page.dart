import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_log_in/components/post_card.dart';
import 'package:social_log_in/models/post.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Pagination state
class PaginatedPosts {
  final List<Post> posts;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final int currentPage;

  const PaginatedPosts({
    required this.posts,
    this.isLoading = false,
    this.error,
    this.hasMore = true,
    this.currentPage = 0,
  });

  PaginatedPosts copyWith({
    List<Post>? posts,
    bool? isLoading,
    String? error,
    bool? hasMore,
    int? currentPage,
  }) {
    return PaginatedPosts(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

const int _postsPerPage = 10;

final postsProvider = AsyncNotifierProvider<PostsNotifier, PaginatedPosts>(() {
  return PostsNotifier();
});

class PostsNotifier extends AsyncNotifier<PaginatedPosts> {
  @override
  Future<PaginatedPosts> build() async {
    return _fetchPosts();
  }

  Future<PaginatedPosts> _fetchPosts({int page = 0}) async {
    try {
      if (page == 0) {
        state = const AsyncValue.data(
          PaginatedPosts(posts: [], isLoading: true),
        );
      } else {
        state = AsyncValue.data(state.value!.copyWith(isLoading: true));
      }

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
          .order('created_at', ascending: false)
          .range(page * _postsPerPage, (page + 1) * _postsPerPage - 1);

      final posts =
          data.map<Post>((post) {
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

      if (page == 0) {
        return PaginatedPosts(
          posts: posts,
          hasMore: posts.length == _postsPerPage,
          currentPage: page,
        );
      } else {
        final currentPosts = state.value!.posts;
        return PaginatedPosts(
          posts: [...currentPosts, ...posts],
          hasMore: posts.length == _postsPerPage,
          currentPage: page,
        );
      }
    } catch (e) {
      if (page == 0) {
        throw Exception('Failed to fetch posts: $e');
      } else {
        return state.value!.copyWith(
          error: 'Failed to load more posts: $e',
          isLoading: false,
        );
      }
    }
  }

  Future<void> loadMore() async {
    final currentState = state.value;
    if (currentState == null ||
        currentState.isLoading ||
        !currentState.hasMore) {
      return;
    }

    state = AsyncValue.data(
      await _fetchPosts(page: currentState.currentPage + 1),
    );
  }

  Future<void> refreshPosts() async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _fetchPosts());
  }
}

class FeedPage extends ConsumerWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: FeedAppBar(),
      ),
      body: const FeedBody(),
    );
  }
}

class FeedAppBar extends ConsumerWidget {
  const FeedAppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      title: const Text('Feed'),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.read(postsProvider.notifier).refreshPosts(),
        ),
      ],
    );
  }
}

class FeedBody extends ConsumerWidget {
  const FeedBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(postsProvider);

    return postsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
      data:
          (paginatedPosts) => RefreshIndicator(
            onRefresh: () => ref.read(postsProvider.notifier).refreshPosts(),
            child:
                paginatedPosts.posts.isEmpty && !paginatedPosts.isLoading
                    ? const EmptyFeedWidget()
                    : PostsList(paginatedPosts: paginatedPosts),
          ),
    );
  }
}

class EmptyFeedWidget extends StatelessWidget {
  const EmptyFeedWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey[400]),
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
    );
  }
}

class PostsList extends ConsumerStatefulWidget {
  final PaginatedPosts paginatedPosts;

  const PostsList({required this.paginatedPosts, super.key});

  @override
  ConsumerState<PostsList> createState() => _PostsListState();
}

class _PostsListState extends ConsumerState<PostsList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(postsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.paginatedPosts.posts.length + 1,
      itemBuilder: (context, index) {
        if (index == widget.paginatedPosts.posts.length) {
          return _buildLoadMoreIndicator();
        }

        return PostCard(
          key: ValueKey(widget.paginatedPosts.posts[index].id),
          post: widget.paginatedPosts.posts[index],
          onPostDeleted: () {
            ref.read(postsProvider.notifier).refreshPosts();
          },
        );
      },
    );
  }

  Widget _buildLoadMoreIndicator() {
    if (!widget.paginatedPosts.hasMore) {
      return const SizedBox(height: 0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }
}
