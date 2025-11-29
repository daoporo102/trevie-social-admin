import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String uid;
  final String commentId;
  final String name;
  final String commentText;
  final String profilePic;
  final DateTime datePublished;
  final DateTime? dateUpdated;
  final DateTime lastDateModified;

  const Comment({
    required this.uid,
    required this.commentId,
    required this.name,
    required this.commentText,
    required this.profilePic,
    required this.datePublished,
    this.dateUpdated,
    required this.lastDateModified,
  });

  Map<String, dynamic> toJson() => {
    "uid": uid,
    "commentId": commentId,
    "commentText": commentText,
    "name": name,
    "profilePic": profilePic,
    "datePublished": Timestamp.fromDate(datePublished),
    "dateUpdated": dateUpdated != null ? Timestamp.fromDate(dateUpdated!) : null,
    "lastDateModified": Timestamp.fromDate(lastDateModified),
  };

  static Comment fromSnap(DocumentSnapshot snapshot) {
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

    return Comment(
      uid: snapshotData['uid'] ?? '',
      commentId: snapshotData['commentId'] ?? '',
      name: snapshotData['name'] ?? '',
      commentText: snapshotData['commentText'] ?? '',
      profilePic: snapshotData['profilePic'] ?? '',
      datePublished:
          parseDateField(snapshotData['datePublished']) ?? DateTime.now(),
      dateUpdated: parseDateField(snapshotData['dateUpdated']),
      lastDateModified:
          parseDateField(snapshotData['lastDateModified']) ?? DateTime.now(),
    );
  }
}