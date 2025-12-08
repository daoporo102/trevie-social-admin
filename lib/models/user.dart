import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String uid;
  final String displayName;
  final String email;
  final String photoUrl;
  final String? bio;
  final DateTime? dateOfBirth;
  final DateTime createdAt;
  final List followers;
  final List following;
  final bool isSuspended;
  final DateTime? suspendedAt;
  final String? suspensionReason;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? deletionReason;

  const User({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    this.bio,
    this.dateOfBirth,
    required this.followers,
    required this.following,
    required this.createdAt,
    this.isSuspended = false,
    this.suspendedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletionReason,
    this.suspensionReason,
  });

  Map<String, dynamic> toJson() => {
    "uid": uid,
    "displayName": displayName,
    "email": email,
    "bio": bio,
    "dateOfBirth": dateOfBirth != null
        ? Timestamp.fromDate(dateOfBirth!)
        : null,
    "createdAt": Timestamp.fromDate(createdAt),
    "photoUrl": photoUrl,
    "followers": followers,
    "following": following,
    "isSuspended": isSuspended,
    "suspendedAt": suspendedAt != null
        ? Timestamp.fromDate(suspendedAt!)
        : null,
    "isDeleted": isDeleted,
    "deletedAt": deletedAt != null
        ? Timestamp.fromDate(deletedAt!)
        : null,
    "deletionReason": deletionReason,
    "suspensionReason": suspensionReason,
  };

  static User fromSnap(DocumentSnapshot snapshot) {
    var snapshotData = snapshot.data() as Map<String, dynamic>;

    // Helper function to safely convert Timestamp to DateTime
    DateTime? parseDateField(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return User(
      uid: snapshotData.containsKey("uid") ? snapshotData["uid"] : '',
      displayName: snapshotData.containsKey("displayName")
          ? snapshotData["displayName"]
          : '',
      email: snapshotData.containsKey("email") ? snapshotData["email"] : '',
      photoUrl: snapshotData.containsKey("photoUrl")
          ? snapshotData["photoUrl"]
          : '',
      followers: snapshotData.containsKey("followers")
          ? snapshotData["followers"]
          : [],
      following: snapshotData.containsKey("following")
          ? snapshotData["following"]
          : [],
      bio: snapshotData.containsKey("bio") ? snapshotData["bio"] : '',
      dateOfBirth: parseDateField(snapshotData["dateOfBirth"]),
      createdAt: parseDateField(snapshotData['createdAt']) ?? DateTime.now(),
      isSuspended:
          snapshotData['isSuspended'] == true, // Defaults to false if null
      suspendedAt: parseDateField(snapshotData['suspendedAt']),
      isDeleted: snapshotData['isDeleted'] == true, // Defaults to false if null
      deletedAt: parseDateField(snapshotData['deletedAt']),
      deletionReason: snapshotData["deletionReason"],
      suspensionReason: snapshotData["suspensionReason"],
    );
  }
}
