import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  // the fields of the current post
  final String postId;
  final String uid;
  final String postText;
  final String displayName;
  final String postUrl;
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
  final String? aiReason;
  final String? adminReason;
  final String? moderatedBy;
  final DateTime? moderatedAt;
  final String? updateStatus;
  final String? updateError;


  const Post({
    required this.postId,
    required this.uid,
    required this.postText,
    required this.postUrl,
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
    this.aiReason,
    this.adminReason,
    this.moderatedBy,
    this.moderatedAt,
    this.updateStatus,
    this.updateError,
  });

  Map<String, dynamic> toJson() => {
    "postId": postId,
    "uid": uid,
    "postText": postText,
    "postUrl": postUrl,
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
    "aiReason": aiReason,
    "adminReason": adminReason,
    "moderatedBy": moderatedBy,
    "moderatedAt": moderatedAt != null
        ? Timestamp.fromDate(moderatedAt!)
        : null,
    "updateStatus": updateStatus,
    "updateError": updateError,
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

    return Post(
      postId: snapshotData['postId'] ?? '',
      uid: snapshotData['uid'] ?? '',
      postText: snapshotData['postText'] ?? '',
      postUrl: snapshotData['postUrl'] ?? '',
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
      aiReason: snapshotData['aiReason'],
      adminReason: snapshotData['adminReason'],
      moderatedBy: snapshotData['moderatedBy'],
      moderatedAt: parseDateField(snapshotData['moderatedAt']),
      updateStatus: snapshotData['updateStatus'],
      updateError: snapshotData['updateError'],
    );
  }
}
