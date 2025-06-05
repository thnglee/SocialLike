import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  // Utility function for consistent log formatting
  static void _logLocation(
    String category,
    String message, {
    Map<String, dynamic>? metadata,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final metadataStr = metadata != null ? '\n┗━━ Metadata: $metadata' : '';
    print('📍 LOCATION [$timestamp] ($category) $message$metadataStr');
  }

  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  static Future<Position?> getCurrentLocation() async {
    try {
      _logLocation('CHECK', 'Checking location permission...');

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _logLocation('ERROR', 'Location services are disabled');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        _logLocation('PERMISSION', 'Requesting location permission...');
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _logLocation('ERROR', 'Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _logLocation('ERROR', 'Location permissions are permanently denied');
        return null;
      }

      _logLocation('FETCH', 'Getting current position...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _logLocation(
        'SUCCESS',
        'Retrieved current position',
        metadata: {
          'latitude': position.latitude.toStringAsFixed(6),
          'longitude': position.longitude.toStringAsFixed(6),
          'accuracy': '${position.accuracy.toStringAsFixed(2)}m',
          'altitude': '${position.altitude.toStringAsFixed(2)}m',
          'speed': '${position.speed.toStringAsFixed(2)}m/s',
        },
      );

      return position;
    } catch (e) {
      _logLocation(
        'ERROR',
        'Failed to get location',
        metadata: {'error': e.toString()},
      );
      return null;
    }
  }

  static Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      _logLocation(
        'GEOCODE',
        'Converting coordinates to address...',
        metadata: {
          'latitude': latitude.toStringAsFixed(6),
          'longitude': longitude.toStringAsFixed(6),
        },
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isEmpty) {
        _logLocation('ERROR', 'No address found for coordinates');
        return null;
      }

      final place = placemarks.first;
      final address = [
        place.street,
        place.subLocality,
        place.locality,
        place.administrativeArea,
        place.country,
      ].where((element) => element != null && element.isNotEmpty).join(', ');

      _logLocation(
        'SUCCESS',
        'Address retrieved successfully',
        metadata: {
          'street': place.street,
          'locality': place.locality,
          'subLocality': place.subLocality,
          'administrativeArea': place.administrativeArea,
          'country': place.country,
          'postalCode': place.postalCode,
          'formatted_address': address,
        },
      );

      return address;
    } catch (e) {
      _logLocation(
        'ERROR',
        'Failed to get address',
        metadata: {'error': e.toString()},
      );
      return null;
    }
  }

  static Stream<Position> getLocationStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );
    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  static Future<double> getDistanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) async {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  static Future<Map<String, dynamic>?> getLocationData() async {
    try {
      final position = await getCurrentLocation();
      if (position == null) return null;

      final address = await getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'speed': position.speed,
        'address': address,
      };
    } catch (e) {
      _logLocation(
        'ERROR',
        'Failed to get location data',
        metadata: {'error': e.toString()},
      );
      return null;
    }
  }
}
