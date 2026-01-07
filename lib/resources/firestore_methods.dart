import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:social_media_admin/models/comment.dart';
import 'package:social_media_admin/models/post.dart';
import 'package:social_media_admin/resources/storage_methods.dart';
import 'package:social_media_admin/services/network_service.dart';
import 'package:social_media_admin/utils/utils.dart';
import 'package:uuid/uuid.dart';

class FirestoreMethod {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final userUid = FirebaseAuth.instance.currentUser?.uid;
  final NetworkService _networkService = NetworkService();

  // Check network connectivity
  Future<bool> _checkNetwork() async {
    return await _networkService.checkConnectivity();
  }

  //upload post
  Future<String> uploadPost(
    String postText,
    List<Uint8List> images,
    String uid,
    String displayName,
    String profImage,
  ) async {
    String res = "Một lỗi đã xảy ra";
    try {
      // Validate profImage before proceeding
      if (profImage.isEmpty) {
        return "Ảnh đại diện không hợp lệ";
      }

      // Validate images list
      if (images.isEmpty) {
        return "Vui lòng chọn ít nhất một ảnh";
      }

      // Upload all images to storage
      List<String> photoUrls = await StorageMethods().uploadMultipleImages(
        'posts',
        images,
        true,
      );

      // Check if upload succeeded
      if (photoUrls.isEmpty) {
        return "Lỗi tải ảnh lên, vui lòng thử lại";
      }

      // creates unique id based on time
      String postId = const Uuid().v1();
      // get current time
      final now = DateTime.now();

      // Fetch author doc to get role (fallback to 'user')
      final authorDoc = await _firestore.collection('users').doc(uid).get();
      final authorRole = (authorDoc.exists && authorDoc.data() != null)
          ? (authorDoc.data() as Map<String, dynamic>)['role'] as String? ??
                'user'
          : 'user';

      Post post = Post(
        postId: postId,
        uid: uid,
        postText: postText,
        displayName: displayName,
        postUrls: photoUrls, // Lưu danh sách URLs
        profImage: profImage,
        datePublished: now,
        likes: [],
        dateUpdated: null,
        lastDateModified: now,
        reshareCount: 0,
        originalPostId: null,
        originalUid: null,
        originalPostText: null,
        originalDisplayName: null,
        originalProfImage: null,
        likesCount: 0,
        role: authorRole,
        status: 'processing',
        adminReason: null,
        aiReasonText: null,
        aiReasonImage: null,
        textChecked: false,
        imageChecked: false,
      );

      // Create a map from the Post object
      final postMap = post.toJson();

      // upload to firestore
      await _firestore.collection('posts').doc(postId).set(postMap);

      // return the postId on success
      res = postId;
    } on FirebaseException catch (e) {
      avoidPrint("Firebase error in uploadPost: ${e.code} - ${e.message}");
      if (e.code == 'permission-denied' || e.code == 'unauthorized') {
        return "Ảnh không hợp lệ hoặc quá lớn. Vui lòng chọn ảnh dưới 5MB";
      }
      return "Lỗi Firebase: ${e.message ?? e.code}";
    } catch (e) {
      avoidPrint("Error in uploadPost: ${e.toString()}");
      // Check for custom error messages
      if (e.toString().contains('quá lớn')) {
        return e.toString().replaceAll('Exception: ', '');
      }
      return "Đã xảy ra lỗi, vui lòng thử lại sau";
    }
    return res;
  }

  // update post
  Future<String> updatePost(
    String postId,
    String postText,
    List<Uint8List>? newImages,
    List<String>? urlsToDelete,
  ) async {
    String res = "Một lỗi đã xảy ra";
    try {
      final startTime = DateTime.now();
      avoidPrint("=== START UPDATE POST ===");

      final now = DateTime.now();

      // Get current post data
      DocumentSnapshot postDoc = await _firestore
          .collection('posts')
          .doc(postId)
          .get();
      if (!postDoc.exists) return "Bài viết không tồn tại";

      final currentData = postDoc.data() as Map<String, dynamic>;
      final oldText = currentData['postText'] as String? ?? '';
      final textChanged = postText != oldText;

      Map<String, dynamic> updateData = {
        'postText': postText,
        'dateUpdated': Timestamp.fromDate(now),
        'lastDateModified': Timestamp.fromDate(now),
        'updateStatus': null,
        'updateError': null,
        'moderatedBy': null,
      };

      if (textChanged) {
        updateData['status'] = 'processing';
        updateData['adminReason'] = null;
      }

      // Get current postUrls
      List<String> currentUrls = currentData['postUrls'] != null &&
              currentData['postUrls'] is List
          ? List<String>.from(currentData['postUrls'])
          : [];

      // Delete images if specified
      if (urlsToDelete != null && urlsToDelete.isNotEmpty) {
        final deleteStart = DateTime.now();
        avoidPrint("Deleting ${urlsToDelete.length} old images...");

        try {
          await StorageMethods().deleteMultipleImagesFromStorage(urlsToDelete);
          currentUrls.removeWhere((url) => urlsToDelete.contains(url));

          final deleteDuration = DateTime.now().difference(deleteStart);
          avoidPrint("Deleted images in ${deleteDuration.inSeconds}s");
        } catch (storageError) {
          avoidPrint("Storage deletion warning: $storageError");
        }
      }

      // Upload new images if provided
      if (newImages != null && newImages.isNotEmpty) {
        final uploadStart = DateTime.now();
        avoidPrint("Uploading ${newImages.length} new images...");

        List<String> newPhotoUrls = await StorageMethods().uploadMultipleImages(
          'posts',
          newImages,
          true,
        );

        if (newPhotoUrls.isEmpty) {
          return "Lỗi tải ảnh lên, vui lòng thử lại";
        }

        final uploadDuration = DateTime.now().difference(uploadStart);
        avoidPrint("Uploaded images in ${uploadDuration.inSeconds}s");

        currentUrls.addAll(newPhotoUrls);
      }

      // Update postUrls
      updateData['postUrls'] = currentUrls;

      // Update Firestore
      final firestoreStart = DateTime.now();
      await _firestore.collection('posts').doc(postId).update(updateData);

      final firestoreDuration = DateTime.now().difference(firestoreStart);
      avoidPrint("Updated Firestore in ${firestoreDuration.inMilliseconds}ms");

      // Update reshares
      String? firstImage = currentUrls.isNotEmpty ? currentUrls.first : null;
      await _updateResharesOfPost(postId, postText, firstImage);

      final totalDuration = DateTime.now().difference(startTime);
      avoidPrint(
        "=== UPDATE POST COMPLETED in ${totalDuration.inSeconds}s ===",
      );

      res = 'success';
    } on FirebaseException catch (e) {
      avoidPrint("Firebase error in updatePost: ${e.code} - ${e.message}");
      if (e.code == 'permission-denied' || e.code == 'unauthorized') {
        return "Ảnh không hợp lệ hoặc quá lớn. Vui lòng chọn ảnh dưới 5MB";
      }
      return "Lỗi Firebase: ${e.message ?? e.code}";
    } catch (e) {
      avoidPrint("Error in updatePost: ${e.toString()}");
      if (e.toString().contains('quá lớn')) {
        return e.toString().replaceAll('Exception: ', '');
      }
      return "Đã xảy ra lỗi, vui lòng thử lại sau";
    }
    return res;
  }

  //like post
  Future<void> likePost(String postId, String uid, List likes) async {
    try {
      if (likes.contains(uid)) {
        //unlike the post
        await _firestore.collection('posts').doc(postId).update({
          'likes': FieldValue.arrayRemove([uid]),
          'likesCount': FieldValue.increment(-1),
        });
      } else {
        //like the post
        await _firestore.collection('posts').doc(postId).update({
          'likes': FieldValue.arrayUnion([uid]),
          'likesCount': FieldValue.increment(1),
        });
      }
    } on FirebaseException catch (e) {
      avoidPrint("Firebase error in likePost: ${e.code} - ${e.message}");
      throw 'Đã có lỗi xảy ra, vui lòng thử lại sau: ${e.message ?? e.code}';
    } catch (e) {
      avoidPrint("Unknown error in likePost: $e");
      throw 'Đã có lỗi xảy ra, vui lòng thử lại sau';
    }
  }

  Future<String> postComment(
    String postId,
    String text,
    String uid,
    String name,
    String profilePic,
  ) async {
    String res = "Một lỗi đã xảy ra";
    // get current time
    final now = DateTime.now();
    try {
      if (text.isNotEmpty) {
        String commentId = const Uuid().v1();

        // Create Comment object
        Comment comment = Comment(
          uid: uid,
          commentId: commentId,
          name: name,
          commentText: text,
          profilePic: profilePic,
          datePublished: now,
          dateUpdated: null,
          lastDateModified: now,
        );

        // Add comment to Firestore database
        await _firestore
            .collection('posts')
            .doc(postId)
            .collection('comments')
            .doc(commentId)
            .set(comment.toJson());

        res = 'success';
      } else {
        res = "Vui lòng nhập bình luận";
      }
    } catch (e) {
      avoidPrint(e.toString());
      res = "Đã xảy ra lỗi, vui lòng thử lại sau";
    }
    return res;
  }

  // Deleting comment
  Future<String> deleteComment(String postId, String commentId) async {
    String res = "Một lỗi đã xảy ra";
    try {
      // Get the comment document
      DocumentSnapshot commentDoc = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .get();

      if (userUid == commentDoc['uid']) {
        // Check if the document exists
        if (commentDoc.exists && commentDoc.data() != null) {
          // Delete comment from Firestore database
          await _firestore
              .collection('posts')
              .doc(postId)
              .collection('comments')
              .doc(commentId)
              .delete();

          res = 'success';
          return res;
        } else {
          res = 'Bình luận không tồn tại!';
          avoidPrint(res);
          return res;
        }
      } else {
        res = 'Bạn không có quyền xoá bình luận này!';
        avoidPrint(res);
        return res;
      }
    } catch (e) {
      avoidPrint("Error in deleteComment: ${e.toString()}");
      res = 'Đã xảy ra lỗi khi xoá bình luận';
    }
    return res;
  }

  //Deleting post
  Future<String> deletePost(String postId) async {
    String res = "Một lỗi đã xảy ra";
    try {
      // Get current user UID safely
      final currentUserUid = FirebaseAuth.instance.currentUser?.uid;

      if (currentUserUid == null) {
        return 'Không tìm thấy thông tin người dùng';
      }

      // Get the post document to retrieve the postUrl
      DocumentSnapshot postDoc = await _firestore
          .collection('posts')
          .doc(postId)
          .get();

      if (postDoc.data() == null || !postDoc.exists) {
        res = 'Bài viết không tồn tại hoặc đã bị xoá!';
        avoidPrint(res);
        return res;
      }

      final postData = postDoc.data() as Map<String, dynamic>;

      // Check ownership with null safety
      final postUid = postData['uid'] as String?;
      if (postUid == null || currentUserUid != postUid) {
        res = 'Bạn không có quyền xoá bài viết này!';
        avoidPrint(res);
        return res;
      }

      String originalPostId = postData['originalPostId'] ?? "";
      String status = postData['status'] ?? 'processing';

      // Check if this is a reshared post
      bool isReshare = originalPostId.isNotEmpty;

      if (isReshare) {
        // Just decrement reshareCount in original post if the reshare post is active
        if (status == 'active') {
          try {
            await _firestore.collection('posts').doc(originalPostId).update({
              'reshareCount': FieldValue.increment(-1),
            });
            avoidPrint(
              "Decremented reshareCount for original post $originalPostId",
            );
          } catch (e) {
            avoidPrint("Error decrementing reshareCount: ${e.toString()}");
          }
        }
      } else {
        // Delete multiple images from storage if postUrls is not empty
        List<String> imageUrls = postData['postUrls'] != null &&
                postData['postUrls'] is List
            ? List<String>.from(postData['postUrls'])
            : [];

        if (imageUrls.isNotEmpty) {
          try {
            await StorageMethods().deleteMultipleImagesFromStorage(imageUrls);
          } catch (storageError) {
            avoidPrint(
              "Storage deletion warning (images may be missing): $storageError",
            );
            // Continue with post deletion even if image deletion fails
          }
        }

        // Delete all comments in the post subcollection
        QuerySnapshot commentsSnapshot = await _firestore
            .collection('posts')
            .doc(postId)
            .collection('comments')
            .get();

        // Delete comments in batch
        if (commentsSnapshot.docs.isNotEmpty) {
          WriteBatch batch = _firestore.batch();
          for (var doc in commentsSnapshot.docs) {
            batch.delete(doc.reference);
          }

          try {
            await batch.commit();
            avoidPrint(
              "Deleted ${commentsSnapshot.docs.length} comments for post $postId",
            );
          } catch (e) {
            avoidPrint("Error deleting comments: ${e.toString()}");
            // Continue with post deletion even if comment deletion fails
          }
        }
      }

      // Delete post collection in Firestore database
      await _firestore.collection('posts').doc(postId).delete();

      res = 'success';
    } catch (e) {
      res = "Có lỗi xảy ra, vui lòng thử lại sau";
      avoidPrint("Error in deletePost: ${e.toString()}");
    }
    return res;
  }

  // Delete comment
  Future<String> updateComment(
    String postId,
    String commentId,
    String commentText,
  ) async {
    String res = "Một lỗi đã xảy ra";
    try {
      final now = DateTime.now();
      Map<String, dynamic> updateData = {
        'commentText': commentText,
        'dateUpdated': Timestamp.fromDate(now),
        'lastDateModified': Timestamp.fromDate(now),
      };

      if (commentText.isNotEmpty) {
        // Update the comment document with the new text and date
        await _firestore
            .collection('posts')
            .doc(postId)
            .collection('comments')
            .doc(commentId)
            .update(updateData);
      } else {
        res = "Vui lòng nhập bình luận";
        return res;
      }
      res = 'success';
    } catch (e) {
      avoidPrint(e.toString());
    }
    return res;
  }

  Future<void> followUser(String uid, String followId) async {
    try {
      //fetching all user data
      DocumentSnapshot snap = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      //getting following list
      List following = (snap.data()! as dynamic)['following'];

      //if already following then unfollow
      if (following.contains(followId)) {
        //remove follower
        await _firestore.collection('users').doc(followId).update({
          'followers': FieldValue.arrayRemove([uid]),
        });
        //remove following
        await _firestore.collection('users').doc(uid).update({
          'following': FieldValue.arrayRemove([followId]),
        });
      } else {
        //add follower
        await _firestore.collection('users').doc(followId).update({
          'followers': FieldValue.arrayUnion([uid]),
        });
        //add following
        await _firestore.collection('users').doc(uid).update({
          'following': FieldValue.arrayUnion([followId]),
        });
      }
    } catch (e) {
      avoidPrint(e.toString());
    }
  }

  // Update reshare post (text only)
  Future<String> updateResharePost(String postId, String postText) async {
    String res = "Một lỗi đã xảy ra";
    try {
      final now = DateTime.now();
      Map<String, dynamic> updateData = {
        'postText': postText,
        'dateUpdated': Timestamp.fromDate(now),
        'lastDateModified': Timestamp.fromDate(now),
      };

      // just update the text
      await _firestore.collection('posts').doc(postId).update(updateData);

      res = 'success';
    } catch (e) {
      avoidPrint(e.toString());
      res = "Đã xảy ra lỗi, vui lòng thử lại sau";
    }
    return res;
  }

  // Update all reshares
  Future<void> _updateResharesOfPost(
    String originalPostId,
    String newPostText,
    String? newPhotoUrl,
  ) async {
    try {
      // Query all posts that are reshares of the original post
      QuerySnapshot reshareSnapshot = await _firestore
          .collection('posts')
          .where('originalPostId', isEqualTo: originalPostId)
          .get();

      if (reshareSnapshot.docs.isEmpty) {
        avoidPrint("No reshares found for postId: $originalPostId");
        return; // No reshares to update
      }

      // Use batch to update all reshares efficiently
      WriteBatch batch = _firestore.batch();
      int updateCount = 0;

      for (var doc in reshareSnapshot.docs) {
        Map<String, dynamic> reshareUpdateData = {
          'originalPostText': newPostText,
        };

        // Only update postUrls if newPhotoUrls is provided
        if (newPhotoUrl != null) {
          reshareUpdateData['postUrls'] = [newPhotoUrl];
        }

        batch.update(doc.reference, reshareUpdateData);
        updateCount++;

        // Firestore batch limit is 500 operations
        if (updateCount >= 500) {
          await batch.commit();
          batch = _firestore.batch();
          updateCount = 0;
        }
      }

      // Commit remaining updates
      if (updateCount > 0) {
        await batch.commit();
      }

      avoidPrint(
        "Updated ${reshareSnapshot.docs.length} reshares for postId: $originalPostId",
      );
    } catch (e) {
      avoidPrint("Error updating reshares: ${e.toString()}");
    }
  }
}
