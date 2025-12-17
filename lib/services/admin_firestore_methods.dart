import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AdminFirestoreMethod {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Mark the log as read (so the admin knows the issue has been resolved).
  Future<String> markLogAsRead(String logId) async {
    try {
      await _firestore.collection('violation_logs').doc(logId).update({
        'isRead': true,
      });
      return 'success';
    } catch (e) {
      debugPrint("Lỗi markLogAsRead: $e");
      return e.toString();
    }
  }

  // 2. Suspend a user
  // Based on the 'isSuspended' field in the users collection that defined in index.js (create user)

  Future<String> suspendUser(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isSuspended': true,
        'suspendedAt': FieldValue.serverTimestamp(),
      });
      return 'success';
    } catch (e) {
      debugPrint("Lỗi đình chỉ người dùng: $e");
      return e.toString();
    }
  }

  // Unsuspend User
  Future<String> unsuspendUser(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isSuspended': false,
        'suspendedAt': null,
      });
      return 'success';
    } catch (e) {
      return e.toString();
    }
  }
}
