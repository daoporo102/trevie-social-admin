import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:social_media_admin/models/user.dart' as model;
import 'package:social_media_admin/resources/storage_methods.dart';
import 'package:social_media_admin/utils/utils.dart';

class AuthMethods {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<model.User> getUserDetails() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return model.User(
        uid: '',
        displayName: '',
        email: '',
        photoUrl: '',
        followers: [],
        following: [],
        bio: '',
        dateOfBirth: DateTime.now(),
      );
    }

    final DocumentSnapshot snap = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();
    if (!snap.exists) {
      return model.User(
        displayName: currentUser.displayName ?? '',
        uid: currentUser.uid,
        email: currentUser.email ?? '',
        photoUrl: currentUser.photoURL ?? '',
        followers: [],
        following: [],
        bio: '',
        dateOfBirth: DateTime.now(),
      );
    }
    return model.User.fromSnap(snap);
  }

  //sign up user
  Future<String> signUpUser({
    required String displayName,
    required String email,
    required String password,
    required Uint8List file,
  }) async {
    String res = "Một lỗi đã xảy ra";
    try {
      if (email.isNotEmpty && password.isNotEmpty && displayName.isNotEmpty) {
        //register user in auth with email and password
        UserCredential cred = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        //debugging print statement to verify user creation
        avoidPrint("Firebase Auth User UID: ${cred.user!.uid}");

        final photoUrl = await StorageMethods().uploadImageToStorage(
          'profilePics',
          file,
          false,
        );

        //add user to database
        final user = model.User(
          displayName: displayName,
          uid: cred.user!.uid,
          email: email,
          photoUrl: photoUrl,
          followers: [],
          following: [],
          bio: '',
          dateOfBirth: DateTime.now(),
        );

        //adding user in our database
        await _firestore
            .collection('users')
            .doc(cred.user!.uid)
            .set(user.toJson());

        res = "success";
      } else {
        res = "Vui lòng điền tất cả các thông tin";
      }
    } on FirebaseAuthException catch (err) {
      if (err.code == 'email-already-in-use') {
        res = "Email đã được sử dụng";
      } else if (err.code == 'invalid-email') {
        res = "Địa chỉ email không hợp lệ";
      } else if (err.code == 'weak-password') {
        res = "Mật khẩu phải có ít nhất 6 ký tự";
      } else if (err.code == 'network-request-failed') {
        res = "Lỗi mạng, vui lòng thử lại sau";
      } else {
        res = err.toString();
        avoidPrint(res);
        res = "Đã xảy ra lỗi, vui lòng thử lại sau";
      }
    }
    return res;
  }

  //login user
  Future<String> loginUser({
    required String email,
    required String password,
  }) async {
    String res = "Một lỗi đã xảy ra";
    try {
      if (email.isNotEmpty && password.isNotEmpty) {
        //login user in auth with email and password
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        res = "success";
      } else {
        res = "Vui lòng điền tất cả các thông tin";
      }
    } on FirebaseAuthException catch (err) {
      if (err.code == 'user-not-found') {
        res = "Không tìm thấy người dùng với email này";
      } else if (err.code == 'invalid-email') {
        res = "Địa chỉ email không hợp lệ";
      } else if (err.code == 'wrong-password') {
        res = "Mật khẩu không đúng";
      } else if (err.code == 'network-request-failed') {
        res = "Lỗi mạng, vui lòng thử lại sau";
      } else if (err.code == 'too-many-requests') {
        res = "Quá nhiều lần đăng nhập. Vui lòng thử lại sau.";
      } else if (err.code == 'invalid-credential') {
        res = "Email hoặc mật khẩu không hợp lệ.";
      } else {
        res = err.toString();
        avoidPrint(res);
        res = "Đã xảy ra lỗi, vui lòng thử lại sau";
      }
    }
    return res;
  }

  //sign out method
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // update user profile
  Future<String> updateUserProfile(
    String uid,
    String displayName,
    Uint8List? file,
    String? existingImageUrl,
    String? bio,
    DateTime? dateOfBirth,
  ) async {
    String res = "Một lỗi đã xảy ra";

    try {
      String? newPhotoUrl;
      Map<String, dynamic> updateData = {'displayName': displayName};

      // Add bio if provided
      if (bio != null && bio.isNotEmpty) {
        updateData['bio'] = bio;
      }

      // Add dateOfBirth if provided
      if (dateOfBirth != null) {
        updateData['dateOfBirth'] = Timestamp.fromDate(dateOfBirth);
      }
      if (file != null) {
        // Delete the old profile picture in firestore if it exists
        if (existingImageUrl != null && existingImageUrl.isNotEmpty) {
          await StorageMethods().deleteImageFromStorage(existingImageUrl);
        }

        // Upload the new profile picture
        newPhotoUrl = await StorageMethods().uploadImageToStorage(
          'profilePics',
          file,
          false,
        );

        updateData['photoUrl'] = newPhotoUrl;

        // Update the user document with the new display name, bio, photo URL and date of birth
        await _firestore.collection('users').doc(uid).update(updateData);
        // Update all posts with the new display name and profile image
        await _updateUserPosts(uid, displayName, newPhotoUrl);

        // Update all comments with the new display name and profile image
        await _updateUserComments(uid, displayName, newPhotoUrl);
        res = "success";
      } else {
        // If no new file is provided, update the display name ,bio and date of birth
        // on the user document
        await _firestore.collection('users').doc(uid).update(updateData);

        // Update all posts with the new display name and profile image
        await _updateUserPosts(uid, displayName, null);

        // Update all comments with the new display name and profile image
        await _updateUserComments(uid, displayName, null);
        res = "success";
      }
    } catch (e) {
      avoidPrint("Error updating user profile: ${e.toString()}");
    }
    return res;
  }
}

Future<void> _updateUserPosts(
  String uid,
  String displayName,
  String? newPhotoUrl,
) async {
  try {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    // Fetch all posts made by the user
    QuerySnapshot userPostsSnapshot = await firestore
        .collection('posts')
        .where('uid', isEqualTo: uid)
        .get();

    // Update each post
    WriteBatch batch = firestore.batch();

    for (var doc in userPostsSnapshot.docs) {
      Map<String, dynamic> updateData = {'displayName': displayName};

      // Only update proImage if a new photo was uploaded
      if (newPhotoUrl != null) {
        updateData['profImage'] = newPhotoUrl;
      }

      batch.update(doc.reference, updateData);
    }

    //Commit all updates at once
    await batch.commit();
  } catch (e) {
    avoidPrint("Error updating user posts: $e");
    rethrow;
  }
}

Future<void> _updateUserComments(
  String uid,
  String displayName,
  String? newPhotoUrl,
) async {
  try {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    // Fetch all posts to find comments made by the user
    QuerySnapshot allPostsSnapshot = await firestore.collection('posts').get();

    WriteBatch batch = firestore.batch();
    int operationCount = 0;
    int totalUpdated = 0;

    for (var postDoc in allPostsSnapshot.docs) {
      // Get comments subcollection for each post
      QuerySnapshot commentsSnapshot = await postDoc.reference
          .collection('comments')
          .where('uid', isEqualTo: uid)
          .get();

      for (var commentDoc in commentsSnapshot.docs) {
        Map<String, dynamic> updateData = {'name': displayName};

        // Only update profImage if a new photo was uploaded
        if (newPhotoUrl != null) {
          updateData['profImage'] = newPhotoUrl;
        }

        batch.update(commentDoc.reference, updateData);
        operationCount++;
        totalUpdated++;

        // Commit batch if operation count reaches 500
        if (operationCount >= 500) {
          await batch.commit();
          batch = firestore.batch();
          operationCount = 0;
        }
      }
    }

    //Commit remaining operations
    if (operationCount > 0) {
      await batch.commit();
    }

    avoidPrint("Updated $totalUpdated comments for user $uid");
  } catch (e) {
    avoidPrint("Error updating user comments: $e");
    rethrow;
  }
}
