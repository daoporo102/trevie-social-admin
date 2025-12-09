import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:social_media_admin/models/comment.dart';
import 'package:social_media_admin/utils/utils.dart';

enum CommentSortField { datePublished, name }

class CommentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all comments from all posts with pagination and filters
  Future<Map<String, dynamic>> getAllComments({
    int limit = 50,
    DocumentSnapshot? lastDocument,
    String? searchQuery,
    String? postId,
    String? authorName,
    DateTime? startDate,
    DateTime? endDate,
    CommentSortField sortBy = CommentSortField.datePublished,
    bool ascending = false,
  }) async {
    try {
      // Get all posts first
      QuerySnapshot postsSnapshot = await _firestore.collection('posts').get();

      List<Map<String, dynamic>> allComments = [];

      // Fetch comments from each post
      for (var postDoc in postsSnapshot.docs) {
        final postData = postDoc.data() as Map<String, dynamic>;

        // Skip this post if postId filter is applied and doesn't match
        if (postId != null && postId.isNotEmpty && postDoc.id != postId) {
          continue;
        }

        Query commentsQuery = postDoc.reference.collection('comments');

        // Apply date range filters
        if (startDate != null) {
          commentsQuery = commentsQuery.where(
            'datePublished',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          );
        }
        if (endDate != null) {
          commentsQuery = commentsQuery.where(
            'datePublished',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate),
          );
        }

        QuerySnapshot commentsSnapshot = await commentsQuery.get();

        for (var commentDoc in commentsSnapshot.docs) {
          final commentData = commentDoc.data() as Map<String, dynamic>;

          // Apply author name filter
          if (authorName != null &&
              authorName.isNotEmpty &&
              !commentData['name'].toString().toLowerCase().contains(
                authorName.toLowerCase(),
              )) {
            continue;
          }

          // Apply search query filter
          if (searchQuery != null && searchQuery.isNotEmpty) {
            final searchLower = searchQuery.toLowerCase();
            final matchText = commentData['commentText']
                .toString()
                .toLowerCase()
                .contains(searchLower);
            final matchName = commentData['name']
                .toString()
                .toLowerCase()
                .contains(searchLower);

            if (!matchText && !matchName) {
              continue;
            }
          }

          allComments.add({
            'comment': Comment.fromSnap(commentDoc),
            'postId': postDoc.id,
            'postText': postData['postText'] ?? '',
            'postAuthor': postData['displayName'] ?? '',
          });
        }
      }

      // Sort comments
      allComments.sort((a, b) {
        Comment commentA = a['comment'];
        Comment commentB = b['comment'];

        int comparison = 0;
        switch (sortBy) {
          case CommentSortField.datePublished:
            comparison = commentA.datePublished.compareTo(
              commentB.datePublished,
            );
            break;
          case CommentSortField.name:
            comparison = commentA.name.compareTo(commentB.name);
            break;
        }

        return ascending ? comparison : -comparison;
      });

      // Apply pagination
      int startIndex = 0;
      if (lastDocument != null) {
        // Find the index of the last document
        final lastCommentId = lastDocument.id;
        startIndex =
            allComments.indexWhere(
              (item) => (item['comment'] as Comment).commentId == lastCommentId,
            ) +
            1;
      }

      final endIndex = (startIndex + limit).clamp(0, allComments.length);
      final paginatedComments = allComments.sublist(startIndex, endIndex);

      DocumentSnapshot? newLastDoc;
      if (paginatedComments.isNotEmpty) {
        final lastComment = paginatedComments.last['comment'] as Comment;
        // Create a mock document snapshot for pagination
        newLastDoc = await _firestore
            .collection('posts')
            .doc(paginatedComments.last['postId'])
            .collection('comments')
            .doc(lastComment.commentId)
            .get();
      }

      return {
        'comments': paginatedComments,
        'lastDocument': newLastDoc,
        'hasMore': endIndex < allComments.length,
        'total': allComments.length,
      };
    } catch (e) {
      avoidPrint('Error getting all comments: $e');
      return {
        'comments': <Map<String, dynamic>>[],
        'lastDocument': null,
        'hasMore': false,
        'total': 0,
      };
    }
  }

  // Get all posts for dropdown filter
  Future<List<Map<String, dynamic>>> getAllPosts() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('posts').get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'postId': doc.id,
          'postText': data['postText'] ?? '',
          'displayName': data['displayName'] ?? '',
          'datePublished': data['datePublished'],
        };
      }).toList();
    } catch (e) {
      avoidPrint('Error getting posts: $e');
      return [];
    }
  }

  // Get total comments count
  Future<int> getTotalCommentsCount() async {
    try {
      QuerySnapshot postsSnapshot = await _firestore.collection('posts').get();
      int totalComments = 0;

      for (var postDoc in postsSnapshot.docs) {
        QuerySnapshot commentsSnapshot = await postDoc.reference
            .collection('comments')
            .get();
        totalComments += commentsSnapshot.size;
      }

      return totalComments;
    } catch (e) {
      avoidPrint('Error getting total comments count: $e');
      return 0;
    }
  }

  // Delete a comment
  Future<String> deleteComment(String postId, String commentId) async {
    try {
      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .delete();

      return 'success';
    } catch (e) {
      avoidPrint('Error deleting comment: $e');
      return 'Đã xảy ra lỗi khi xóa bình luận';
    }
  }
}