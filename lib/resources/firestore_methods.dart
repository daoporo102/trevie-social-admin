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
    Uint8List file,
    String uid,
    String displayName,
    String profImage,
  ) async {
    // asking uid here because we dont want to make extra calls to firebase auth when we can just get from our state management
    String res = "Một lỗi đã xảy ra";

    // Check network connectivity
    if (!await _checkNetwork()) {
      return "Không có kết nối Internet";
    }
    
    try {
      // Validate proImage before proceeding
      if (profImage.isEmpty) {
        return "Ảnh đại diện không hợp lệ";
      }

      String photoUrl = await StorageMethods().uploadImageToStorage(
        'posts',
        file,
        true,
      );

      // Check if upload succeeded
      if (photoUrl.isEmpty) {
        return "Lỗi tải ảnh lên, vui lòng thử lại";
      }
      // creates unique id based on time
      String postId = const Uuid().v1();
      // get current time
      final now = DateTime.now();

      Post post = Post(
        postId: postId,
        uid: uid,
        postText: postText,
        displayName: displayName,
        postUrl: photoUrl,
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
        status: 'processing',
        adminReason: null,
        aiReasonText: null,
        aiReasonImage: null,
        textChecked: false,
        imageChecked: false,
      );

      _firestore.collection('posts').doc(postId).set(post.toJson());

      res = "success";
    } catch (e) {
      avoidPrint("Error in uploadPost: ${e.toString()}");
      res = "Đã xảy ra lỗi, vui lòng thử lại sau";
    }
    return res;
  }

  //update post
  Future<String> updatePost(
    String postId,
    String postText,
    Uint8List? file,
    String? existingImageUrl,
  ) async {
    String res = "Một lỗi đã xảy ra";
    try {
      final now = DateTime.now();
      Map<String, dynamic> updateData = {
        'postText': postText,
        'dateUpdated': Timestamp.fromDate(now),
        'lastDateModified': Timestamp.fromDate(now),
      };

      String? newPhotoUrl;

      // Only update image if user selected a new one
      if (file != null) {
        // Delete the old image from storage if it exists
        if (existingImageUrl != null && existingImageUrl.isNotEmpty) {
          try {
            await StorageMethods().deleteImageFromStorage(existingImageUrl);
          } catch (storageError) {
            avoidPrint(
              "Storage deletion warning (old image may be missing): $storageError",
            );
          }
        }

        // Upload the new image to storage
        newPhotoUrl = await StorageMethods().uploadImageToStorage(
          'posts',
          file,
          true,
        );

        //  Check if upload succeeded
        if (newPhotoUrl.isEmpty) {
          return "Lỗi tải ảnh lên, vui lòng thử lại";
        }

        // Add the new photo Url to updateData
        updateData['postUrl'] = newPhotoUrl;

        // Update the post document with the new image URL, text and date
        await _firestore.collection('posts').doc(postId).update(updateData);

        // Update all reshared posts that reference this original post
        await _updateResharesOfPost(
          postId,
          postText,
          newPhotoUrl, // Will be null if no new image was uploaded
        );

        res = 'success';
      } else {
        // If no new file is provided, just update the text
        await _firestore.collection('posts').doc(postId).update(updateData);

        // Update all reshared posts that reference this original post
        await _updateResharesOfPost(
          postId,
          postText,
          newPhotoUrl, // Will be null if no new image was uploaded
        );
      }
      res = 'success';
    } catch (e) {
      avoidPrint("Error in updatePost: ${e.toString()}");
      res = "Đã xảy ra lỗi, vui lòng thử lại sau";
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

      // Check ownership
      if (userUid != postDoc['uid']) {
        res = 'Bạn không có quyền xoá bài viết này!';
        avoidPrint(res);
        return res;
      }

      String postUrl = postData['postUrl'];

      // Check if this is a reshared post
      bool isReshare = postData['originalPostId'] != null;

      // Delete post collection in Firestore database
      await _firestore.collection('posts').doc(postId).delete();

      // Only delete image if it's not a reshared post (reshares reuse the original image)
      if (!isReshare && postUrl.isNotEmpty) {
        try {
          await StorageMethods().deleteImageFromStorage(postUrl);
        } catch (storageError) {
          avoidPrint(
            "Storage deletion warning (post already deleted): $storageError",
          );
        }
      }

      // If this is a post is a reshared post
      if (isReshare && postData['originalPostId'] != null) {
        String originalPostId = postData['originalPostId'];

        try {
          // get original post document
          DocumentSnapshot originalPostDoc = await _firestore
              .collection('posts')
              .doc(originalPostId)
              .get();

          // Only decrement if the original post exists
          if (originalPostDoc.exists && originalPostDoc.data() != null) {
            // Decrement reshareCount on the original post
            await _firestore.collection('posts').doc(originalPostId).update({
              'reshareCount': FieldValue.increment(-1),
            });
            avoidPrint("Decremented reshareCount for post $originalPostId");
          } else {
            avoidPrint(
              "Original post $originalPostId doesn't exist, skipping reshareCount decrement",
            );
          }
        } catch (e) {
          avoidPrint(
            "Could not decrement reshareCount (original post may be deleted): ${e.toString()}",
          );
        }
      }

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

  // Reshare post
  Future<String> resharePost(
    String postText,
    Post originalPost,
    String uid,
    String displayName,
    String profImage,
  ) async {
    String res = "Một lỗi đã xảy ra";
    try {
      // creates unique id based on time
      String postId = const Uuid().v1();
      // get current time
      final now = DateTime.now();

      // Create the new post data
      Post newPost = Post(
        postId: postId,
        uid: uid,
        postText: postText,
        displayName: displayName,
        postUrl: originalPost.postUrl,
        profImage: profImage,
        datePublished: now,
        likes: [],
        dateUpdated: null,
        lastDateModified: now,
        reshareCount: 0,
        originalPostId: originalPost.postId,
        originalUid: originalPost.uid,
        originalPostText: originalPost.postText,
        originalDisplayName: originalPost.displayName,
        originalProfImage: originalPost.profImage,
        likesCount: 0,
        status: 'processing',
        adminReason: null,
        aiReasonText: null,
        aiReasonImage: null,
        textChecked: false,
        imageChecked: false,
      );

      // Reference to the original post
      DocumentReference originalPostRef = _firestore
          .collection('posts')
          .doc(originalPost.postId);

      // Original post exists, proceed with resharing
      if (await originalPostRef.snapshots().isEmpty) {
        avoidPrint('Original post does not exist.');
        res = 'Bài viết gốc không tồn tại hoặc đã bị xoá!';
        return res;
      }

      // Add the new post to Firestore
      await _firestore.collection('posts').doc(postId).set(newPost.toJson());

      // Increment reshareCount on the original post
      await _firestore.collection('posts').doc(originalPost.postId).update({
        'reshareCount': FieldValue.increment(1),
      });

      res = 'success';
    } catch (e) {
      avoidPrint("Error in resharePost: ${e.toString()}");
      res = "Đã xảy ra lỗi, vui lòng thử lại sau";
    }
    return res;
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

  // New helper method to update all reshares
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
          'lastDateModified': Timestamp.now(),
        };

        // Only update photoUrl if a new one is provided
        if (newPhotoUrl != null) {
          reshareUpdateData['postUrl'] = newPhotoUrl;
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