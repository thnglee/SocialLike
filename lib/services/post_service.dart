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

      // Get current user first since it's needed for other operations
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

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
          .catchError((e) => null); // Handle case where profile doesn't exist

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

      if (locationData != null) {
        _logPost('LOCATION', 'Location data retrieved', metadata: locationData);
      } else {
        _logPost('WARNING', 'Location data not available');
      }

      _logPost('IMAGE', 'Image upload completed', metadata: {'url': imageUrl});

      // Handle profile creation if needed (only if parallel fetch didn't find one)
      if (profile == null) {
        _logPost('PROFILE', 'Creating new user profile');
        await _supabase.from('profiles').upsert({
          'id': user.id,
          'username':
              user.email?.split('@')[0] ?? 'user_${user.id.substring(0, 8)}',
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        _logPost(
          'PROFILE',
          'Using existing profile',
          metadata: {'username': profile['username']},
        );
      }

      // Create post record
      final postData = {
        'user_id': user.id,
        'image_url': imageUrl,
        'location': locationData?['address'] ?? 'Unknown location',
        'latitude': locationData?['latitude'] ?? 0.0,
        'longitude': locationData?['longitude'] ?? 0.0,
      };

      await _supabase.from('posts').insert(postData);

      _logPost(
        'SUCCESS',
        'Post created successfully',
        metadata: {
          'location': postData['location'],
          'image_url': postData['image_url'],
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
