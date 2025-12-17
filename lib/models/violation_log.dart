import 'package:cloud_firestore/cloud_firestore.dart';

class ViolationLog {
  final String logId;
  final String uid;

  final String targetId; // Could be postId, commentId, uid
  final String targetType; // 'post', 'comment', 'user'
  final String? parentId; // For comments, the postId it belongs to

  final String actionType; // 'creation', 'update', 'reshare', 'deletion'
  final String moderatedBy; // Admin, AI, ...
  final List<String> violationLabels; // ['violence', 'blood']
  final double aiConfidence;   //

  final double textScore; // AI confidence score for text
  final double imageScore; // AI confidence score for image

  final String reason; // Reason of the violation
  final String? toxicText;
  final String? toxicImageUrl;
  final DateTime createdAt;
  final bool isRead; // Whether the log has been read by user

  ViolationLog({
    required this.logId,
    required this.uid,
    required this.targetId,
    required this.targetType,
    this.parentId,
    required this.actionType,
    required this.moderatedBy,
    required this.violationLabels,
    required this.aiConfidence,
    required this.reason,
    this.toxicText,
    this.toxicImageUrl,
    required this.createdAt,
    this.isRead = false,
    required this.textScore,
    required this.imageScore,
  });

  Map<String, dynamic> toJson() => {
    "logId": logId,
    "uid": uid,
    "targetId": targetId,
    "targetType": targetType,
    "parentId": parentId,
    "actionType": actionType,
    "moderatedBy": moderatedBy,
    "violationLabels": violationLabels,
    "aiConfidence": aiConfidence,
    "reason": reason,
    "toxicText": toxicText,
    "toxicImageUrl": toxicImageUrl,
    "createdAt": Timestamp.fromDate(createdAt),
    "isRead": isRead,
    "textScore": textScore,
    "imageScore": imageScore,
  };

  static ViolationLog fromSnap(DocumentSnapshot snapshot){
    var snapshotData = snapshot.data() as Map<String, dynamic>;

    // Helper function to safely parse createdAt
    DateTime? parseCreatedAt(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        return DateTime.tryParse(value);
      } else if (value is Timestamp) {
        return value.toDate();
      }

      return null;
    }

    return ViolationLog(
      logId: snapshotData["logId"]??'',
      uid: snapshotData["uid"]??'',

      targetId: snapshotData["targetId"]?? snapshot['postId'] ?? '', // Backward compatibility with 'postId'
      targetType: snapshotData["targetType"]??'post', // Default to 'post' for backward compatibility
      parentId: snapshotData["parentId"]??'',
      actionType: snapshotData["actionType"]??'creation',
      moderatedBy: snapshotData["moderatedBy"]??'AI',
      violationLabels: snapshotData["violationLabels"] != null
          ? List<String>.from(snapshotData["violationLabels"])
          : [],
      aiConfidence: snapshotData["aiConfidence"] != null
          ? snapshotData["aiConfidence"].toDouble()
          : 0.0,
      reason: snapshotData["reason"]??'Vi phạm tiêu chuẩn',
      toxicText: snapshotData["toxicText"],
      toxicImageUrl: snapshotData["toxicImageUrl"],
      createdAt: parseCreatedAt(snapshotData["createdAt"]) ?? DateTime.now(),
      isRead: snapshotData["isRead"]??false,
      textScore: snapshotData["textScore"] != null
          ? snapshotData["textScore"].toDouble()
          : 0.0,
      imageScore: snapshotData["imageScore"] != null
          ? snapshotData["imageScore"].toDouble()
          : 0.0,
    );
  }
}
