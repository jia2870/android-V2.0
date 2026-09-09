class SavedPropertyModel {
  final String id;
  final String userId;
  final String listingId;
  final DateTime savedAt;

  SavedPropertyModel({
    required this.id,
    required this.userId,
    required this.listingId,
    required this.savedAt,
  });

  factory SavedPropertyModel.fromJson(Map<String, dynamic> json) {
    return SavedPropertyModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      listingId: json['listing_id'] ?? '',
      savedAt: json['saved_at'] != null
          ? DateTime.parse(json['saved_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'listing_id': listingId,
      'saved_at': savedAt.toIso8601String(),
    };
  }
}
