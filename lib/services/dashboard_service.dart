import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:social_media_admin/utils/utils.dart';

enum TimePeriod { week, month, year }

class DashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get total users count
  Future<int> getTotalUsersCount() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('users').get();
      return snapshot.size;
    } catch (e) {
      avoidPrint('Error getting total users count: $e');
      return 0;
    }
  }

  // Get total posts count
  Future<int> getTotalPostsCount() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('posts').get();
      return snapshot.size;
    } catch (e) {
      avoidPrint('Error getting total posts count: $e');
      return 0;
    }
  }

  // Get total comments count (aggregate from all posts)
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

  // Get new users today
  Future<int> getNewUsersToday() async {
    try {
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day);

      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .get();

      return snapshot.size;
    } catch (e) {
      avoidPrint('Error getting new users today: $e');
      return 0;
    }
  }

  // Get user growth data with time period selection
  Future<Map<DateTime, int>> getUserGrowthData({
    TimePeriod period = TimePeriod.week,
  }) async {
    try {
      final now = DateTime.now();
      DateTime startDate;
      int daysCount;

      switch (period) {
        case TimePeriod.week:
          startDate = now.subtract(const Duration(days: 7));
          daysCount = 7;
          break;
        case TimePeriod.month:
          startDate = now.subtract(const Duration(days: 30));
          daysCount = 30;
          break;
        case TimePeriod.year:
          startDate = now.subtract(const Duration(days: 365));
          daysCount = 365;
          break;
      }

      final startOfPeriod = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );

      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfPeriod),
          )
          .get();

      Map<DateTime, int> growthData = {};

      // Initialize map with zeros for each day
      for (int i = 0; i < daysCount; i++) {
        final date = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: daysCount - 1 - i));
        growthData[date] = 0;
      }

      // Count users per day
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['createdAt'] != null) {
          final timestamp = data['createdAt'] as Timestamp;
          final date = timestamp.toDate();
          final dayKey = DateTime(date.year, date.month, date.day);

          if (growthData.containsKey(dayKey)) {
            growthData[dayKey] = growthData[dayKey]! + 1;
          }
        }
      }

      return growthData;
    } catch (e) {
      avoidPrint('Error getting user growth data: $e');
      return {};
    }
  }

  // Get post activity data with time period selection
  Future<Map<DateTime, int>> getPostActivityData({
    TimePeriod period = TimePeriod.week,
  }) async {
    try {
      final now = DateTime.now();
      DateTime startDate;
      int daysCount;

      switch (period) {
        case TimePeriod.week:
          startDate = now.subtract(const Duration(days: 7));
          daysCount = 7;
          break;
        case TimePeriod.month:
          startDate = now.subtract(const Duration(days: 30));
          daysCount = 30;
          break;
        case TimePeriod.year:
          startDate = now.subtract(const Duration(days: 365));
          daysCount = 365;
          break;
      }

      final startOfPeriod = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );

      QuerySnapshot snapshot = await _firestore
          .collection('posts')
          .where(
            'datePublished',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfPeriod),
          )
          .get();

      Map<DateTime, int> activityData = {};

      // Initialize map with zeros for each day
      for (int i = 0; i < daysCount; i++) {
        final date = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: daysCount - 1 - i));
        activityData[date] = 0;
      }

      // Count posts per day
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['datePublished'] != null) {
          final timestamp = data['datePublished'] as Timestamp;
          final date = timestamp.toDate();
          final dayKey = DateTime(date.year, date.month, date.day);

          if (activityData.containsKey(dayKey)) {
            activityData[dayKey] = activityData[dayKey]! + 1;
          }
        }
      }

      return activityData;
    } catch (e) {
      avoidPrint('Error getting post activity data: $e');
      return {};
    }
  }

  // Get most active users (top 5 by post count)
  Future<List<Map<String, dynamic>>> getMostActiveUsers() async {
    try {
      final postsSnapshot = await _firestore.collection('posts').get();

      Map<String, Map<String, dynamic>> userPostCounts = {};

      for (var doc in postsSnapshot.docs) {
        final data = doc.data();
        final uid = data['uid'] as String;

        if (userPostCounts.containsKey(uid)) {
          userPostCounts[uid]!['count'] = userPostCounts[uid]!['count'] + 1;
        } else {
          userPostCounts[uid] = {'uid': uid, 'count': 1};
        }
      }

      // Sort by post count and get top 5
      final sortedUsers = userPostCounts.values.toList()
        ..sort((a, b) => b['count'].compareTo(a['count']));

      final top5Users = sortedUsers.take(5).toList();

      // Fetch user details (displayName and photoUrl) from users collection
      List<Map<String, dynamic>> usersWithDetails = [];

      for (var userData in top5Users) {
        try {
          final userDoc = await _firestore
              .collection('users')
              .doc(userData['uid'])
              .get();

          if (userDoc.exists) {
            final userSnap = userDoc.data() as Map<String, dynamic>;
            usersWithDetails.add({
              'uid': userData['uid'],
              'displayName': userSnap['displayName'] ?? 'Unknown User',
              'photoUrl': userSnap['photoUrl'] ?? '',
              'count': userData['count'],
            });
          } else {
            // User document doesn't exist, add with default values
            usersWithDetails.add({
              'uid': userData['uid'],
              'displayName': 'Deleted User',
              'photoUrl': '',
              'count': userData['count'],
            });
          }
        } catch (e) {
          avoidPrint('Error fetching user details for ${userData['uid']}: $e');
          // Add user with minimal info if fetch fails
          usersWithDetails.add({
            'uid': userData['uid'],
            'displayName': 'Unknown User',
            'photoUrl': '',
            'count': userData['count'],
          });
        }
      }

      return usersWithDetails;
    } catch (e) {
      avoidPrint('Error getting most active users: $e');
      return [];
    }
  }
}
