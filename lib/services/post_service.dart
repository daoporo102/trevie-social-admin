import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:social_media_admin/models/post.dart';
import 'package:social_media_admin/resources/storage_methods.dart';
import 'package:social_media_admin/utils/utils.dart';
import 'package:uuid/uuid.dart';

enum PostSortField { datePublished, likes, reshareCount, dateUpdated }

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get paginated posts list
  Future<Map<String, dynamic>> getPosts({
    int limit = 20,
    DocumentSnapshot? lastDocument,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    PostSortField sortBy = PostSortField.datePublished,
    bool ascending = false,
  }) async {
    try {
      Query query = _firestore.collection('posts');

      // Apply sorting
      String sortField = 'datePublished';
      switch (sortBy) {
        case PostSortField.datePublished:
          sortField = 'datePublished';
          break;
        case PostSortField.dateUpdated:
          sortField = 'dateUpdated';
          break;
        case PostSortField.likes:
          sortField = 'likesCount';
          break;
        case PostSortField.reshareCount:
          sortField = 'reshareCount';
          break;
      }

      query = query.orderBy(sortField, descending: !ascending);

      // Apply pagination
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();

      List<Post> posts = snapshot.docs
          .map((doc) => Post.fromSnap(doc))
          .toList();

      // Apply search filter in memory (Firestore doesn't support full-text search)
      if (searchQuery != null && searchQuery.isNotEmpty) {
        posts = posts.where((post) {
          final searchLower = searchQuery.toLowerCase();
          return post.postText.toLowerCase().contains(searchLower) ||
              post.displayName.toLowerCase().contains(searchLower);
        }).toList();
      }

      return {
        'posts': posts,
        'lastDocument': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        'hasMore': snapshot.docs.length == limit,
      };
    } catch (e) {
      avoidPrint('Error getting posts: $e');
      return {
        'posts': <Post>[],
        'lastDocument': null,
        'hasMore': false,
      };
    }
  }

  // Get total posts count
  Future<int> getTotalPostsCount() async {
    try {
      final snapshot = await _firestore.collection('posts').get();
      return snapshot.size;
    } catch (e) {
      avoidPrint('Error getting total posts count: $e');
      return 0;
    }
  }

  // Delete a post
  Future<String> deletePost(String postId) async {
    try {
      // Get post document
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      
      if (!postDoc.exists) {
        return 'Bài viết không tồn tại';
      }

      final postData = postDoc.data() as Map<String, dynamic>;
      final isReshare = postData['originalPostId'] != null;

      // Delete all comments
      final commentsSnapshot = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .get();

      WriteBatch batch = _firestore.batch();
      for (var commentDoc in commentsSnapshot.docs) {
        batch.delete(commentDoc.reference);
      }

      // Delete the post
      batch.delete(postDoc.reference);
      await batch.commit();

      // Update reshare count if this is a reshare
      if (isReshare && postData['originalPostId'] != null) {
        try {
          await _firestore
              .collection('posts')
              .doc(postData['originalPostId'])
              .update({
            'reshareCount': FieldValue.increment(-1),
          });
        } catch (e) {
          avoidPrint('Could not update reshare count: $e');
        }
      }

      return 'success';
    } catch (e) {
      avoidPrint('Error deleting post: $e');
      return 'Đã xảy ra lỗi khi xóa bài viết';
    }
  }

  // ...existing code...

  // Create a new post (for admins)
  Future<String> createPost({
    required String postText,
    required Uint8List image,
    required String uid,
    required String displayName,
    required String profImage,
  }) async {
    try {
      // Upload image to storage
      final photoUrl = await StorageMethods().uploadImageToStorage(
        'posts',
        image,
        true,
      );

      if (photoUrl.isEmpty) {
        return 'Lỗi tải ảnh lên, vui lòng thử lại';
      }

      // Create unique post ID
      final postId = const Uuid().v1();
      final now = DateTime.now();

      // Create post object
      final post = Post(
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
        role: 'admin',
      );

      // Save to Firestore
      await _firestore.collection('posts').doc(postId).set(post.toJson());

      return 'success';
    } catch (e) {
      avoidPrint('Error creating post: $e');
      return 'Đã xảy ra lỗi khi tạo bài viết';
    }
  }
}