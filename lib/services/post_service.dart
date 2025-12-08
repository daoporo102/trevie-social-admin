import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:social_media_admin/models/post.dart';
import 'package:social_media_admin/utils/utils.dart';

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
}