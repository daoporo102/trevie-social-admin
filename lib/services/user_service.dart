import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:social_media_admin/models/user.dart' as model;
import 'package:social_media_admin/resources/storage_methods.dart';
import 'package:social_media_admin/utils/utils.dart';

enum UserStatus { all, active, suspended }

enum UserSortField { displayName, createdAt, followers }

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
  Future<String> updateUser(String uid, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('users').doc(uid).update(updates);
      return 'success';
    } catch (e) {
      avoidPrint('Error updating user: $e');
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
      // Delete user document from Firestore
      await _firestore.collection('users').doc(uid).delete();

      // Get user document to retrieve photoUrl
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

      // Step 6: Delete user document from Firestore
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

      avoidPrint('Found ${postsSnapshot.docs.length} posts to delete for user $uid');

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
          'following': FieldValue.arrayRemove([uid])
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
          'followers': FieldValue.arrayRemove([uid])
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

      avoidPrint('Removed user $uid from ${followers.length} followers and ${following.length} following lists');
    } catch (e) {
      avoidPrint('Error removing user from follow lists: $e');
      rethrow;
    }
  }
}
