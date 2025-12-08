import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:social_media_admin/models/user.dart' as model;
import 'package:social_media_admin/resources/storage_methods.dart';
import 'package:social_media_admin/utils/utils.dart';

enum UserStatus { all, active, suspended }

enum UserSortField { displayName, createdAt, followers }

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get paginated users list
  Future<Map<String, dynamic>> getUsers({
    int limit = 20,
    DocumentSnapshot? lastDocument,
    String? searchQuery,
    UserStatus status = UserStatus.all,
    DateTime? startDate,
    DateTime? endDate,
    UserSortField sortBy = UserSortField.createdAt,
    bool ascending = false,
    bool includeDeleted = false,
  }) async {
    try {
      Query query = _firestore.collection('users');

      // Exclude deleted users by default
      if (!includeDeleted) {
        query = query.where('isDeleted', isEqualTo: false);
      }

      // Apply search filter
      if (status == UserStatus.suspended) {
        query = query.where('isSuspended', isEqualTo: true);
      } else if (status == UserStatus.active) {
        query = query.where('isSuspended', isEqualTo: false);
      }

      // Apply date range filter
      if (startDate != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }
      if (endDate != null) {
        query = query.where(
          'createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      // Apply sorting
      String sortField;
      switch (sortBy) {
        case UserSortField.displayName:
          sortField = 'displayName';
          break;
        case UserSortField.createdAt:
          sortField = 'createdAt';
          break;
        case UserSortField.followers:
          sortField = 'followers';
          break;
      }
      query = query.orderBy(sortField, descending: !ascending);

      // Apply pagination
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      query = query.limit(limit);

      // Fetch users
      final snapshot = await query.get();

      // Filter by search query in memory (Firestore doesn't support full text search)
      List<model.User> users = snapshot.docs
          .map((doc) => model.User.fromSnap(doc))
          .where((user) {
            if (searchQuery == null || searchQuery.isEmpty) return true;
            final query = searchQuery.toLowerCase();
            return user.displayName.toLowerCase().contains(query) ||
                user.email.toLowerCase().contains(query);
          })
          .toList();

      return {
        'users': users,
        'lastDocument': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        'hasMore': snapshot.docs.length >= limit,
      };
    } catch (e) {
      avoidPrint('Error getting users: $e');
      return {'users': <model.User>[], 'lastDocument': null, 'hasMore': false};
    }
  }

  // Get total users count
  Future<int> getTotalUsersCount() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('isDeleted', isEqualTo: false)
          .get();
      return snapshot.size;
    } catch (e) {
      avoidPrint('Error getting total users count: $e');
      return 0;
    }
  }

  // Get total deleted users count
  Future<int> getTotalDeletedUsersCount() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('isDeleted', isEqualTo: true)
          .get();
      return snapshot.size;
    } catch (e) {
      avoidPrint('Error getting total deleted users count: $e');
      return 0;
    }
  }

  // Toggle user suspension status
  Future<String> toggleUserSuspension(String userId, bool isSuspended) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isSuspended': isSuspended,
        'suspendedAt': isSuspended ? Timestamp.now() : null,
      });
      return 'success';
    } catch (e) {
      avoidPrint('Error toggling user suspension: $e');
      return 'Đã xảy ra lỗi khi ${isSuspended ? 'đình chỉ' : 'kích hoạt'} tài khoản';
    }
  }

  // Delete user (soft delete - mark as deleted)
  Future<String> deleteUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isDeleted': true,
        'deletedAt': Timestamp.now(),
      });
      return 'success';
    } catch (e) {
      avoidPrint('Error deleting user: $e');
      return 'Đã xảy ra lỗi khi xóa người dùng';
    }
  }

  // Get single user details
  Future<model.User?> getUserDetailsById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return model.User.fromSnap(doc);
      } else {
        return null;
      }
    } catch (e) {
      avoidPrint('Error getting user details: $e');
      return null;
    }
  }

  // Update user profile (admin edit)
  Future<String> updateUserProfile({
    required String uid,
    required String displayName,
    String? bio,
    DateTime? dateOfBirth,
    Uint8List? image,
    String? existingImageUrl,
  }) async {
    try {
      String? newPhotoUrl;
      Map<String, dynamic> updateData = {'displayName': displayName};

      // Add bio if provided
      if (bio != null && bio.isNotEmpty) {
        updateData['bio'] = bio;
      } else {
        updateData['bio'] = ''; // Clear bio if empty
      }

      // Add dateOfBirth if provided
      if (dateOfBirth != null) {
        updateData['dateOfBirth'] = Timestamp.fromDate(dateOfBirth);
      } else {
        updateData['dateOfBirth'] = null; // Clear date if null
      }

      // Handle profile image update
      if (image != null) {
        // Delete old image if exists
        if (existingImageUrl != null && existingImageUrl.isNotEmpty) {
          try {
            await StorageMethods().deleteImageFromStorage(existingImageUrl);
          } catch (e) {
            avoidPrint('Error deleting old image: $e');
          }
        }

        // Upload new image
        newPhotoUrl = await StorageMethods().uploadImageToStorage(
          'profilePics',
          image,
          false,
        );

        if (newPhotoUrl.isEmpty) {
          return 'Lỗi tải ảnh lên, vui lòng thử lại';
        }

        updateData['photoUrl'] = newPhotoUrl;
      }

      // Update user document in Firestore
      await _firestore.collection('users').doc(uid).update(updateData);

      // Update all posts with new display name and profile image
      await _updateUserPosts(uid, displayName, newPhotoUrl);

      // Update all comments with new display name and profile image
      await _updateUserComments(uid, displayName, newPhotoUrl);

      return 'success';
    } catch (e) {
      avoidPrint('Error updating user profile: $e');
      return 'Đã xảy ra lỗi khi cập nhật người dùng';
    }
  }

  // Restore a deleted user
  Future<String> restoreUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isDeleted': false,
        'deletedAt': null,
      });
      return 'success';
    } catch (e) {
      avoidPrint('Error restoring user: $e');
      return 'Đã xảy ra lỗi khi khôi phục người dùng';
    }
  }

  // Get deleted users (for trash/recycle bin view)
  Future<Map<String, dynamic>> getDeletedUsers({
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _firestore
          .collection('users')
          .where('isDeleted', isEqualTo: true)
          .orderBy('deletedAt', descending: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();

      List<model.User> users = snapshot.docs
          .map((doc) => model.User.fromSnap(doc))
          .toList();

      return {
        'users': users,
        'lastDocument': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        'hasMore': snapshot.docs.length >= limit,
      };
    } catch (e) {
      avoidPrint('Error getting deleted users: $e');
      return {'users': <model.User>[], 'lastDocument': null, 'hasMore': false};
    }
  }

  // Permanently delete user
  Future<String> permanentlyDeleteUser(String uid) async {
    try {
      // Step 1: Get user document to retrieve photoUrl BEFORE deleting
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        return 'Người dùng không tồn tại';
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final String? userPhotoUrl = userData['photoUrl'];

      // Step 2: Delete user's profile picture from Storage
      if (userPhotoUrl != null && userPhotoUrl.isNotEmpty) {
        try {
          await StorageMethods().deleteImageFromStorage(userPhotoUrl);
          avoidPrint('Deleted user profile picture: $userPhotoUrl');
        } catch (e) {
          avoidPrint('Error deleting user profile picture: $e');
        }
      }

      // Step 3: Delete all user's posts and their images
      await _deleteUserPosts(uid);

      // Step 4: Delete all user's comments
      await _deleteUserComments(uid);

      // Step 5: Remove user from followers/following lists of other users
      await _removeUserFromFollowLists(uid);

      // Step 6: Delete user document from Firestore (ONLY ONCE!)
      await _firestore.collection('users').doc(uid).delete();

      avoidPrint('Successfully deleted all data for user: $uid');

      return 'success';
    } catch (e) {
      avoidPrint('Error permanently deleting user: $e');
      return 'Đã xảy ra lỗi khi xóa vĩnh viễn người dùng';
    }
  }

  // Helper method: Delete all user's posts and their images
  Future<void> _deleteUserPosts(String uid) async {
    try {
      // Get all posts by this user
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('uid', isEqualTo: uid)
          .get();

      if (postsSnapshot.docs.isEmpty) {
        avoidPrint('No posts found for user $uid');
        return;
      }

      avoidPrint(
        'Found ${postsSnapshot.docs.length} posts to delete for user $uid',
      );

      WriteBatch batch = _firestore.batch();
      int batchCount = 0;
      List<String> imageUrls = [];

      for (var postDoc in postsSnapshot.docs) {
        final postData = postDoc.data();
        final String? postUrl = postData['postUrl'];

        // Collect image URLs to delete from Storage
        if (postUrl != null && postUrl.isNotEmpty) {
          imageUrls.add(postUrl);
        }

        // Delete all comments under this post
        final commentsSnapshot = await postDoc.reference
            .collection('comments')
            .get();

        for (var commentDoc in commentsSnapshot.docs) {
          batch.delete(commentDoc.reference);
          batchCount++;

          // Commit batch if it reaches 500 operations (Firestore limit)
          if (batchCount >= 500) {
            await batch.commit();
            batch = _firestore.batch();
            batchCount = 0;
          }
        }

        // Delete the post document
        batch.delete(postDoc.reference);
        batchCount++;

        if (batchCount >= 500) {
          await batch.commit();
          batch = _firestore.batch();
          batchCount = 0;
        }
      }

      // Commit remaining operations
      if (batchCount > 0) {
        await batch.commit();
      }

      // Delete all post images from Storage
      for (String imageUrl in imageUrls) {
        try {
          await StorageMethods().deleteImageFromStorage(imageUrl);
          avoidPrint('Deleted post image: $imageUrl');
        } catch (e) {
          avoidPrint('Error deleting post image $imageUrl: $e');
        }
      }

      avoidPrint('Deleted all posts and images for user $uid');
    } catch (e) {
      avoidPrint('Error deleting user posts: $e');
      rethrow;
    }
  }

  // Helper method: Delete all user's comments across all posts
  Future<void> _deleteUserComments(String uid) async {
    try {
      // Get all posts to search for user's comments
      final allPostsSnapshot = await _firestore.collection('posts').get();

      WriteBatch batch = _firestore.batch();
      int batchCount = 0;
      int totalComments = 0;

      for (var postDoc in allPostsSnapshot.docs) {
        // Get comments by this user under each post
        final commentsSnapshot = await postDoc.reference
            .collection('comments')
            .where('uid', isEqualTo: uid)
            .get();

        for (var commentDoc in commentsSnapshot.docs) {
          batch.delete(commentDoc.reference);
          batchCount++;
          totalComments++;

          // Commit batch if it reaches 500 operations
          if (batchCount >= 500) {
            await batch.commit();
            batch = _firestore.batch();
            batchCount = 0;
          }
        }
      }

      // Commit remaining operations
      if (batchCount > 0) {
        await batch.commit();
      }

      avoidPrint('Deleted $totalComments comments for user $uid');
    } catch (e) {
      avoidPrint('Error deleting user comments: $e');
      rethrow;
    }
  }

  // Helper method: Remove user from all followers/following lists
  Future<void> _removeUserFromFollowLists(String uid) async {
    try {
      // Get the user's followers and following lists
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final List followers = userData['followers'] ?? [];
      final List following = userData['following'] ?? [];

      WriteBatch batch = _firestore.batch();
      int batchCount = 0;

      // Remove this user from their followers' "following" lists
      for (String followerId in followers) {
        final followerRef = _firestore.collection('users').doc(followerId);
        batch.update(followerRef, {
          'following': FieldValue.arrayRemove([uid]),
        });
        batchCount++;

        if (batchCount >= 500) {
          await batch.commit();
          batch = _firestore.batch();
          batchCount = 0;
        }
      }

      // Remove this user from their following users' "followers" lists
      for (String followingId in following) {
        final followingRef = _firestore.collection('users').doc(followingId);
        batch.update(followingRef, {
          'followers': FieldValue.arrayRemove([uid]),
        });
        batchCount++;

        if (batchCount >= 500) {
          await batch.commit();
          batch = _firestore.batch();
          batchCount = 0;
        }
      }

      // Commit remaining operations
      if (batchCount > 0) {
        await batch.commit();
      }

      avoidPrint(
        'Removed user $uid from ${followers.length} followers and ${following.length} following lists',
      );
    } catch (e) {
      avoidPrint('Error removing user from follow lists: $e');
      rethrow;
    }
  }

  // Create a new user (for Super Admins)
  Future<model.User?> createUserforSuperAdmin({
    required String email,
    required String password,
    required String displayName,
    String? bio,
    DateTime? dateOfBirth,
    required Uint8List image,
  }) async {
    String? uploadedPhotoUrl;

    try {
      // Force refresh token
      final user = _auth.currentUser;
      if (user != null) {
        await user.getIdToken(true);
      }

      // Upload image
      uploadedPhotoUrl = await StorageMethods().uploadImageToStorage(
        'profilePics',
        image,
        false,
      );

      if (uploadedPhotoUrl.isEmpty) {
        throw Exception('Không thể tải ảnh lên');
      }

      // CLEAN DATA (Delete nulls)
      // Create a temporary data map
      final Map<String, dynamic> payload = {
        'email': email,
        'password': password,
        'displayName': displayName,
        'photoUrl': uploadedPhotoUrl,
        'bio': bio, // can be null
        'dateOfBirth': dateOfBirth?.toIso8601String(), // can be null
      };

      // Remove all entries with null values
      // Helps avoid "Invalid request" errors from the Server
      payload.removeWhere((key, value) => value == null);

      // Call Cloud Function with cleaned payload
      final callable = _functions.httpsCallable('createUser');
      final result = await callable.call(payload);
      // ---------------------------------------------

      if (result.data['success'] == true) {
        final userData = Map<String, dynamic>.from(result.data['user']);

        DateTime? parseTimestamp(dynamic val) {
          if (val == null) return null;
          if (val is Timestamp) return val.toDate();
          if (val is String) return DateTime.tryParse(val);
          return null;
        }

        final user = model.User(
          uid: userData['uid'],
          displayName: userData['displayName'],
          email: userData['email'],
          photoUrl: userData['photoUrl'],
          bio: userData['bio'],
          dateOfBirth: parseTimestamp(userData['dateOfBirth']),
          createdAt: parseTimestamp(userData['createdAt']) ?? DateTime.now(),
          followers: List.from(userData['followers'] ?? []),
          following: List.from(userData['following'] ?? []),
          isSuspended: userData['isSuspended'] ?? false,
          suspendedAt: parseTimestamp(userData['suspendedAt']),
          isDeleted: userData['isDeleted'] ?? false,
        );

        return user;
      } else {
        throw Exception(result.data['message'] ?? 'Không thể tạo người dùng');
      }
    } on FirebaseFunctionsException catch (e) {
      String message = 'Đã xảy ra lỗi';
      switch (e.code) {
        case 'permission-denied':
          message =
              'Bạn không có quyền tạo người dùng (Token hết hạn hoặc không phải SuperAdmin)';
          break;
        case 'already-exists':
          message = 'Email đã được sử dụng';
          break;
        case 'invalid-argument':
          message = e.message ?? 'Thông tin không hợp lệ';
          break;
        default:
          message = e.message ?? 'Lỗi hệ thống: ${e.code}';
      }
      throw Exception(message);
    } catch (e) {
      // Clean up image if error occurs
      if (uploadedPhotoUrl != null && uploadedPhotoUrl.isNotEmpty) {
        try {
          await StorageMethods().deleteImageFromStorage(uploadedPhotoUrl);
        } catch (_) {}
      }
      rethrow;
    }
  }

  // Helper method: Update user's posts
  Future<void> _updateUserPosts(
    String uid,
    String displayName,
    String? newPhotoUrl,
  ) async {
    try {
      QuerySnapshot userPostsSnapshot = await _firestore
          .collection('posts')
          .where('uid', isEqualTo: uid)
          .get();

      WriteBatch batch = _firestore.batch();
      int batchCount = 0;

      for (var doc in userPostsSnapshot.docs) {
        Map<String, dynamic> updateData = {'displayName': displayName};

        if (newPhotoUrl != null) {
          updateData['profImage'] = newPhotoUrl;
        }

        batch.update(doc.reference, updateData);
        batchCount++;

        if (batchCount >= 500) {
          await batch.commit();
          batch = _firestore.batch();
          batchCount = 0;
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }

      avoidPrint(
        'Updated ${userPostsSnapshot.docs.length} posts for user $uid',
      );
    } catch (e) {
      avoidPrint('Error updating user posts: $e');
      rethrow;
    }
  }

  // Helper method: Update user's comments
  Future<void> _updateUserComments(
    String uid,
    String displayName,
    String? newPhotoUrl,
  ) async {
    try {
      QuerySnapshot allPostsSnapshot = await _firestore
          .collection('posts')
          .get();

      WriteBatch batch = _firestore.batch();
      int operationCount = 0;
      int totalUpdated = 0;

      for (var postDoc in allPostsSnapshot.docs) {
        QuerySnapshot commentsSnapshot = await postDoc.reference
            .collection('comments')
            .where('uid', isEqualTo: uid)
            .get();

        for (var commentDoc in commentsSnapshot.docs) {
          Map<String, dynamic> updateData = {'name': displayName};

          if (newPhotoUrl != null) {
            updateData['profImage'] = newPhotoUrl;
          }

          batch.update(commentDoc.reference, updateData);
          operationCount++;
          totalUpdated++;

          if (operationCount >= 500) {
            await batch.commit();
            batch = _firestore.batch();
            operationCount = 0;
          }
        }
      }

      if (operationCount > 0) {
        await batch.commit();
      }

      avoidPrint('Updated $totalUpdated comments for user $uid');
    } catch (e) {
      avoidPrint('Error updating user comments: $e');
      rethrow;
    }
  }

  // ...existing code...

  // Helper method: Delete user from Firebase Authentication
  Future<bool> _deleteUserFromAuth(String uid) async {
    try {
      final callable = _functions.httpsCallable('deleteUserAuth');
      final result = await callable.call({'uid': uid});
      
      if (result.data['success'] == true) {
        avoidPrint('Successfully deleted user from Firebase Auth: $uid');
        return true;
      }
      return false;
    } on FirebaseFunctionsException catch (e) {
      avoidPrint('Firebase Functions error deleting user from Auth: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      avoidPrint('Unexpected error deleting user from Auth: $e');
      return false;
    }
  }
}