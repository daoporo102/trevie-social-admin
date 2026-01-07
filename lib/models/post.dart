import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  // the fields of the current post
  final String postId;
  final String uid;
  final String postText;
  final String displayName;
  final List<String> postUrls;
  final String profImage;
  final DateTime datePublished;
  final List<String> likes;
  final int likesCount;
  final DateTime? dateUpdated;
  final DateTime lastDateModified;
  final int reshareCount;
  // the fields of the original post being reshared
  final String? originalPostId;
  final String? originalUid;
  final String? originalPostText;
  final String? originalDisplayName;
  final String? originalProfImage;
  final String role;
  final String status;
  final String? adminReason;
  final String? moderatedBy;
  final DateTime? moderatedAt;
  final String? updateStatus;
  final String? updateError;
  final String? attemptedUpdateText;
  final String? attemptedUpdateImage;
  final String? aiReasonText;
  final String? aiReasonImage;
  final bool? textChecked;
  final bool? imageChecked;

  const Post({
    required this.postId,
    required this.uid,
    required this.postText,
    required this.postUrls,
    required this.profImage,
    required this.datePublished,
    required this.likes,
    required this.displayName,
    this.dateUpdated,
    required this.lastDateModified,
    required this.reshareCount,
    this.originalPostId,
    this.originalUid,
    this.originalPostText,
    this.originalDisplayName,
    this.originalProfImage,
    required this.likesCount,
    this.role = 'user',
    required this.status,
    this.adminReason,
    this.moderatedBy,
    this.moderatedAt,
    this.updateStatus,
    this.updateError,
    this.attemptedUpdateText,
    this.attemptedUpdateImage,
    this.aiReasonText,
    this.aiReasonImage,
    this.textChecked = false,
    this.imageChecked = false,
  });

  Map<String, dynamic> toJson() => {
    "postId": postId,
    "uid": uid,
    "postText": postText,
    "postUrls": postUrls,
    "profImage": profImage,
    "datePublished": Timestamp.fromDate(datePublished),
    "likes": likes,
    "displayName": displayName,
    "dateUpdated": dateUpdated != null
        ? Timestamp.fromDate(dateUpdated!)
        : null,
    "lastDateModified": Timestamp.fromDate(lastDateModified),
    "reshareCount": reshareCount,
    "originalPostId": originalPostId,
    "originalUid": originalUid,
    "originalPostText": originalPostText,
    "originalDisplayName": originalDisplayName,
    "originalProfImage": originalProfImage,
    "likesCount": likes.length,
    "role": role,
    "status": status,
    "adminReason": adminReason,
    "moderatedBy": moderatedBy,
    "moderatedAt": moderatedAt != null
        ? Timestamp.fromDate(moderatedAt!)
        : null,
    "updateStatus": updateStatus,
    "updateError": updateError,
    "attemptedUpdateText": attemptedUpdateText,
    "attemptedUpdateImage": attemptedUpdateImage,
    "aiReasonText": aiReasonText,
    "aiReasonImage": aiReasonImage,
    "textChecked": textChecked,
    "imageChecked": imageChecked,
  };

  static Post fromSnap(DocumentSnapshot snapshot) {
    var snapshotData = snapshot.data() as Map<String, dynamic>;

    // Helper funtion to safely parse DateTime
    DateTime? parseDateField(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        return DateTime.tryParse(value);
      } else if (value is Timestamp) {
        return value.toDate();
      }

      return null;
    }

    // Helper function to safely cast List<dynamic> to List<String>
    List<String> parseStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return [];
    }

    // Logic to handle both single and multiple image URLs
    List<String> images = [];
    if (snapshot['postUrls'] != null) {
      images = List<String>.from(snapshot['postUrls']);
    } else if (snapshot['postUrl'] != null) {
      // If the old post only has one string image, force it into a list.
      images.add(snapshot['postUrl']);
    }

    return Post(
      postId: snapshotData['postId'] ?? '',
      uid: snapshotData['uid'] ?? '',
      postText: snapshotData['postText'] ?? '',
      postUrls: images,
      profImage: snapshotData['profImage'] ?? '',
      datePublished:
          parseDateField(snapshotData['datePublished']) ?? DateTime.now(),
      likes: parseStringList(snapshotData['likes']),
      displayName: snapshotData['displayName'] ?? '',
      dateUpdated: parseDateField(snapshotData['dateUpdated']),
      lastDateModified:
          parseDateField(snapshotData['lastDateModified']) ?? DateTime.now(),
      reshareCount: snapshotData['reshareCount'] ?? 0,
      originalPostId: snapshotData['originalPostId'],
      originalUid: snapshotData['originalUid'],
      originalPostText: snapshotData['originalPostText'],
      originalDisplayName: snapshotData['originalDisplayName'],
      originalProfImage: snapshotData['originalProfImage'],
      likesCount:
          snapshotData['likesCount'] ?? snapshotData['likes']?.length ?? 0,
      role: snapshotData['role'] ?? 'user',
      status: snapshotData['status'] ?? 'active',
      adminReason: snapshotData['adminReason'],
      moderatedBy: snapshotData['moderatedBy'],
      moderatedAt: parseDateField(snapshotData['moderatedAt']),
      updateStatus: snapshotData['updateStatus'],
      updateError: snapshotData['updateError'],
      attemptedUpdateText: snapshotData['attemptedUpdateText'],
      attemptedUpdateImage: snapshotData['attemptedUpdateImage'],
      aiReasonText: snapshotData['aiReasonText'],
      aiReasonImage: snapshotData['aiReasonImage'],
      textChecked: snapshotData['textChecked'] ?? false,
      imageChecked: snapshotData['imageChecked'] ?? false,
    );
  }
}
