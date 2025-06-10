import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import '../models/post.dart';
import 'app_initialization_service.dart';

// Utility function for consistent log formatting
void _logPost(
  String category,
  String message, {
  Object? error,
  Map<String, dynamic>? metadata,
}) {
  final timestamp = DateTime.now().toIso8601String();
  final metadataStr = metadata != null ? '\n┗━━ Metadata: $metadata' : '';
  final errorMsg = error != null ? '\n┗━━ Error: $error' : '';
  debugPrint('📸 POST [$timestamp] ($category) $message$metadataStr$errorMsg');
}

class PostService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _bucketName = 'posts';
  static const Uuid _uuid = Uuid();
  final AppInitializationService _initService = AppInitializationService();

  Future<String> _compressAndUploadImage(String imagePath) async {
    File? compressedFile;
    final originalFile = File(imagePath);
    final originalSize = await originalFile.length();

    try {
      _logPost(
        'COMPRESS',
        'Starting image compression',
        metadata: {
          'originalPath': imagePath,
          'originalSize': '${(originalSize / 1024).toStringAsFixed(2)} KB',
        },
      );

      if (!_initService.isBucketVerified) {
        await _initService.verifyBucket();
      }

      final tempDir = await getTemporaryDirectory();
      final targetPath = path.join(tempDir.path, '${_uuid.v4()}.jpg');

      final result = await FlutterImageCompress.compressAndGetFile(
        imagePath,
        targetPath,
        quality: 85,
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        throw Exception('Failed to compress image');
      }

      compressedFile = File(result.path);
      final compressedSize = await compressedFile.length();

      _logPost(
        'COMPRESS',
        'Image compression completed',
        metadata: {
          'originalSize': '${(originalSize / 1024).toStringAsFixed(2)} KB',
          'compressedSize': '${(compressedSize / 1024).toStringAsFixed(2)} KB',
          'compressionRatio':
              '${((1 - compressedSize / originalSize) * 100).toStringAsFixed(1)}%',
        },
      );

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final fileName = '$userId/${_uuid.v4()}.jpg';
      _logPost(
        'UPLOAD',
        'Starting image upload',
        metadata: {
          'fileName': fileName,
          'fileSize': '${(compressedSize / 1024).toStringAsFixed(2)} KB',
        },
      );

      await _retryUpload(compressedFile, fileName);

      final imageUrl = _supabase.storage
          .from(_bucketName)
          .getPublicUrl(fileName);

      _logPost(
        'SUCCESS',
        'Image processed and uploaded successfully',
        metadata: {'imageUrl': imageUrl},
      );

      return imageUrl;
    } catch (e) {
      _logPost('ERROR', 'Failed to process and upload image', error: e);
      throw Exception('Failed to process and upload image: $e');
    } finally {
      if (compressedFile != null) {
        try {
          await compressedFile.delete();
          _logPost('CLEANUP', 'Temporary compressed file deleted');
        } catch (e) {
          _logPost('WARNING', 'Failed to delete temporary file', error: e);
        }
      }
    }
  }

  Future<void> _retryUpload(
    File file,
    String fileName, {
    int maxAttempts = 3,
  }) async {
    int attempts = 0;
    while (attempts < maxAttempts) {
      try {
        _logPost(
          'UPLOAD',
          'Attempting upload',
          metadata: {'attempt': attempts + 1, 'maxAttempts': maxAttempts},
        );

        await _supabase.storage
            .from(_bucketName)
            .upload(
              fileName,
              file,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
            );
        _logPost('UPLOAD', 'Upload successful on attempt ${attempts + 1}');
        return;
      } catch (e) {
        attempts++;
        _logPost(
          'RETRY',
          'Upload attempt failed',
          metadata: {'attempt': attempts, 'maxAttempts': maxAttempts},
          error: e,
        );

        if (attempts >= maxAttempts) {
          throw Exception('Failed to upload after $maxAttempts attempts: $e');
        }
        await Future.delayed(Duration(seconds: attempts));
      }
    }
  }

  Future<bool> createPost(String imagePath) async {
    try {
      _logPost('START', 'Creating new post...');

      // Get current user and validate authentication
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Start all async operations in parallel
      final Future<Map<String, dynamic>?> locationFuture =
          _initService.getLocation();
      final Future<String> imageFuture = _compressAndUploadImage(imagePath);
      final Future<Map<String, dynamic>?> profileFuture = _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single()
          .then((value) => value as Map<String, dynamic>?)
          .catchError((e) {
            _logPost('WARNING', 'Failed to fetch profile', error: e);
            return null;
          });

      _logPost(
        'PARALLEL',
        'Started parallel processing of location, image, and profile',
      );

      // Wait for all parallel operations to complete
      final results = await Future.wait([
        locationFuture,
        imageFuture,
        profileFuture,
      ]);

      final locationData = results[0] as Map<String, dynamic>?;
      final imageUrl = results[1] as String;
      final profile = results[2] as Map<String, dynamic>?;

      // Validate image upload
      if (imageUrl.isEmpty) {
        throw Exception('Failed to upload image: Empty URL received');
      }

      // Validate location data if available
      if (locationData != null) {
        if (locationData['latitude'] == null ||
            locationData['longitude'] == null) {
          _logPost(
            'WARNING',
            'Invalid location data received',
            metadata: locationData,
          );
        }
      }

      // Handle profile creation/update within a transaction
      final result = await _supabase.rpc(
        'create_post_with_profile',
        params: {
          'p_user_id': user.id,
          'p_image_url': imageUrl,
          'p_location': locationData?['address'] ?? 'Unknown location',
          'p_latitude': locationData?['latitude'] ?? 0.0,
          'p_longitude': locationData?['longitude'] ?? 0.0,
          'p_username':
              profile?['username'] ??
              user.email?.split('@')[0] ??
              'user_${user.id.substring(0, 8)}',
          'p_user_avatar': profile?['avatar_url'],
        },
      );

      if (result == null) {
        throw Exception(
          'Failed to create post: Database procedure returned null',
        );
      }

      _logPost(
        'SUCCESS',
        'Post created successfully',
        metadata: {
          'post_id': result,
          'location': locationData?['address'] ?? 'Unknown location',
          'image_url': imageUrl,
          'username': profile?['username'] ?? 'New user',
        },
      );

      return true;
    } catch (e) {
      _logPost('ERROR', 'Failed to create post', error: e);
      return false;
    }
  }

  Future<bool> deletePost(Post post) async {
    try {
      _logPost('DELETE', 'Deleting post', metadata: {'postId': post.id});

      // Extract file name from URL
      final uri = Uri.parse(post.imageUrl);
      final fileName = uri.pathSegments.last;
      final userId = _supabase.auth.currentUser?.id;

      if (userId == null) throw Exception('User not authenticated');

      // Delete image from storage
      await _supabase.storage.from(_bucketName).remove(['$userId/$fileName']);

      // Delete post record
      await _supabase.from('posts').delete().match({'id': post.id});

      _logPost('SUCCESS', 'Post deleted successfully');
      return true;
    } catch (e) {
      _logPost('ERROR', 'Failed to delete post', error: e);
      return false;
    }
  }
}
