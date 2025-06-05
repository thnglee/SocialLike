import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import '../models/post.dart';
import 'location_service.dart';

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

  // Verify if bucket exists and is accessible
  Future<void> _verifyBucket() async {
    try {
      final user = _supabase.auth.currentUser;
      _logPost(
        'BUCKET',
        'Verifying bucket access',
        metadata: {'userId': user?.id, 'bucket': _bucketName},
      );

      await _supabase.storage.from(_bucketName).list();
      _logPost('BUCKET', 'Successfully verified bucket access');
    } catch (e) {
      _logPost('ERROR', 'Bucket verification failed', error: e);
      if (e.toString().contains('does not exist')) {
        throw Exception(
          'Storage bucket "$_bucketName" does not exist. Please create it in your Supabase dashboard.',
        );
      } else if (e.toString().contains('Permission denied')) {
        throw Exception(
          'Permission denied. Please check your storage policies.',
        );
      } else {
        throw Exception('Storage bucket "$_bucketName" is not accessible: $e');
      }
    }
  }

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

      await _verifyBucket();

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

      // Get location data with detailed logging
      final locationData = await LocationService.getLocationData();

      if (locationData == null) {
        _logPost('WARNING', 'Location data not available');
      } else {
        _logPost('LOCATION', 'Location data retrieved', metadata: locationData);
      }

      // Upload image
      final imageUrl = await _compressAndUploadImage(imagePath);

      // Get current user
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Create post record
      final response =
          await _supabase.from('posts').insert({
            'user_id': user.id,
            'image_url': imageUrl,
            'location': locationData?['address'],
            'latitude': locationData?['latitude'],
            'longitude': locationData?['longitude'],
            'username': user.userMetadata?['full_name'] ?? user.email,
            'user_avatar': user.userMetadata?['avatar_url'],
          }).select();

      _logPost(
        'SUCCESS',
        'Post created successfully',
        metadata: {
          'post_id': response[0]['id'],
          'image_url': imageUrl,
          'location': locationData?['address'],
        },
      );

      return true;
    } catch (e) {
      _logPost(
        'ERROR',
        'Failed to create post',
        metadata: {'error': e.toString()},
      );
      return false;
    }
  }

  Future<void> deletePost(Post post) async {
    try {
      _logPost(
        'DELETE',
        'Starting post deletion',
        metadata: {'postId': post.id},
      );

      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final uri = Uri.parse(post.imageUrl);
      final fileName = uri.pathSegments.last;

      _logPost(
        'STORAGE',
        'Deleting image from storage',
        metadata: {'fileName': fileName},
      );

      await _supabase.storage.from(_bucketName).remove([fileName]);

      _logPost(
        'DATABASE',
        'Deleting post from database',
        metadata: {'postId': post.id},
      );

      await _supabase
          .from('posts')
          .delete()
          .eq('id', post.id)
          .eq('user_id', user.id);

      _logPost(
        'SUCCESS',
        'Post deleted successfully',
        metadata: {'postId': post.id},
      );
    } catch (e) {
      _logPost('ERROR', 'Failed to delete post', error: e);
      throw Exception('Failed to delete post: $e');
    }
  }
}
