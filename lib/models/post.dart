class Post {
  final String id;
  final String userId;
  final String username;
  final String? userAvatar;
  final DateTime createdAt;
  final String location;
  final double latitude;
  final double longitude;
  final String imageUrl;

  Post({
    required this.id,
    required this.userId,
    required this.username,
    this.userAvatar,
    required this.createdAt,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
  });

  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      username: map['username'] as String,
      userAvatar: map['user_avatar'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      location: map['location'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      imageUrl: map['image_url'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'user_avatar': userAvatar,
      'created_at': createdAt.toIso8601String(),
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'image_url': imageUrl,
    };
  }
}
