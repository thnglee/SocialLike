import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'location_service.dart';

class AppInitializationService {
  static final AppInitializationService _instance =
      AppInitializationService._internal();
  factory AppInitializationService() => _instance;
  AppInitializationService._internal();

  bool _isBucketVerified = false;
  Map<String, dynamic>? _lastKnownLocation;
  DateTime? _lastLocationUpdate;
  static const Duration _locationUpdateInterval = Duration(minutes: 5);

  // Utility function for consistent log formatting
  void _log(
    String category,
    String message, {
    Object? error,
    Map<String, dynamic>? metadata,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final metadataStr = metadata != null ? '\n┗━━ Metadata: $metadata' : '';
    final errorMsg = error != null ? '\n┗━━ Error: $error' : '';
    debugPrint(
      '🚀 INIT [$timestamp] ($category) $message$metadataStr$errorMsg',
    );
  }

  Future<void> verifyBucket() async {
    if (_isBucketVerified) return;

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      _log(
        'BUCKET',
        'Verifying bucket access',
        metadata: {'userId': user?.id, 'bucket': 'posts'},
      );

      await supabase.storage.from('posts').list();
      _isBucketVerified = true;
      _log('BUCKET', 'Successfully verified bucket access');
    } catch (e) {
      _log('ERROR', 'Bucket verification failed', error: e);
      if (e.toString().contains('does not exist')) {
        throw Exception(
          'Storage bucket "posts" does not exist. Please create it in your Supabase dashboard.',
        );
      } else if (e.toString().contains('Permission denied')) {
        throw Exception(
          'Permission denied. Please check your storage policies.',
        );
      } else {
        throw Exception('Storage bucket "posts" is not accessible: $e');
      }
    }
  }

  Future<void> updateLocation() async {
    try {
      _log('LOCATION', 'Updating location data');
      _lastKnownLocation = await LocationService.getLocationData();
      _lastLocationUpdate = DateTime.now();

      if (_lastKnownLocation != null) {
        _log(
          'LOCATION',
          'Location updated successfully',
          metadata: {
            'address': _lastKnownLocation!['address'],
            'latitude': _lastKnownLocation!['latitude'],
            'longitude': _lastKnownLocation!['longitude'],
          },
        );
      } else {
        _log('WARNING', 'Failed to get location data');
      }
    } catch (e) {
      _log('ERROR', 'Failed to update location', error: e);
      _lastKnownLocation = null;
      _lastLocationUpdate = null;
    }
  }

  Future<Map<String, dynamic>?> getLocation() async {
    final now = DateTime.now();
    if (_lastLocationUpdate == null ||
        now.difference(_lastLocationUpdate!) > _locationUpdateInterval) {
      await updateLocation();
    }
    return _lastKnownLocation;
  }

  bool get isBucketVerified => _isBucketVerified;

  Future<void> initialize() async {
    _log('START', 'Initializing app services');
    await Future.wait([verifyBucket(), updateLocation()]);
    _log('COMPLETE', 'App services initialized');
  }
}
