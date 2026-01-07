import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:social_media_admin/utils/utils.dart';

enum TimePeriod { week, month, year }

class DashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get counters from aggregated collection
  Future<Map<String, int>> getCounters() async {
    try {
      final counterDoc = await _firestore
          .collection('_counters')
          .doc('stats')
          .get();

      if (!counterDoc.exists) {
        avoidPrint(
          'Counters not initialized. Please run initializeCounters function.',
        );
        // Fallback to old method
        // return {
        //   'totalUsers': await _getTotalUsersCountFallback(),
        //   'totalPosts': await _getTotalPostsCountFallback(),
        //   'totalComments': await _getTotalCommentsCountFallback(),
        //   'totalViolations': await _getTotalViolationsCountFallback(),
        // };
      }

      final data = counterDoc.data() as Map<String, dynamic>;

      return {
        'totalUsers': data['totalUsers'] ?? 0,
        'totalPosts': data['totalPosts'] ?? 0,
        'totalComments': data['totalComments'] ?? 0,
        'totalViolations': data['totalViolations'] ?? 0,
      };
    } catch (e) {
      avoidPrint('Error getting counters: $e');
      return {
        'totalUsers': 0,
        'totalPosts': 0,
        'totalComments': 0,
        'totalViolations': 0,
      };
    }
  }

  // // Get total users count
  // Future<int> getTotalUsersCount() async {
  //   try {
  //     QuerySnapshot snapshot = await _firestore.collection('users').get();
  //     return snapshot.size;
  //   } catch (e) {
  //     avoidPrint('Error getting total users count: $e');
  //     return 0;
  //   }
  // }

  // // Get total posts count
  // Future<int> getTotalPostsCount() async {
  //   try {
  //     QuerySnapshot snapshot = await _firestore.collection('posts').get();
  //     return snapshot.size;
  //   } catch (e) {
  //     avoidPrint('Error getting total posts count: $e');
  //     return 0;
  //   }
  // }

  // // Get total comments count (aggregate from all posts)
  // Future<int> getTotalCommentsCount() async {
  //   try {
  //     QuerySnapshot postsSnapshot = await _firestore.collection('posts').get();
  //     int totalComments = 0;

  //     for (var postDoc in postsSnapshot.docs) {
  //       QuerySnapshot commentsSnapshot = await postDoc.reference
  //           .collection('comments')
  //           .get();
  //       totalComments += commentsSnapshot.size;
  //     }

  //     return totalComments;
  //   } catch (e) {
  //     avoidPrint('Error getting total comments count: $e');
  //     return 0;
  //   }
  // }

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
      // Get posts aggregated by user (real-time data)
      final postsSnapshot = await _firestore.collection('posts').get();

      Map<String, int> userPostCounts = {};

      for (var doc in postsSnapshot.docs) {
        final data = doc.data();
        final uid = data['uid'] as String;

        userPostCounts[uid] = (userPostCounts[uid] ?? 0) + 1;
      }

      // Sort and get top 5
      final sortedUsers = userPostCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final topUsers = sortedUsers.take(5).toList();

      // Batch get user details
      List<Map<String, dynamic>> usersWithDetails = [];

      // Create batch of user IDs
      final userIds = topUsers.map((e) => e.key).toList();

      // Fetch all users in parallel
      final userDocs = await Future.wait(
        userIds.map((uid) => _firestore.collection('users').doc(uid).get()),
      );

      for (int i = 0; i < userDocs.length; i++) {
        final userDoc = userDocs[i];
        final postCount = topUsers[i].value;

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          usersWithDetails.add({
            'uid': userIds[i],
            'displayName': userData['displayName'] ?? 'Unknown User',
            'photoUrl': userData['photoUrl'] ?? '',
            'count': postCount,
          });
        } else {
          usersWithDetails.add({
            'uid': userIds[i],
            'displayName': 'Deleted User',
            'photoUrl': '',
            'count': postCount,
          });
        }
      }

      return usersWithDetails;
    } catch (e) {
      avoidPrint('Error getting most active users: $e');
      return [];
    }
  }

  // Get violation stats for chart
  Future<Map<DateTime, int>> getViolationActivityData({
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
          .collection('violation_logs')
          .where(
            'createdAt',
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

      // Count violations per day
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['createdAt'] != null) {
          final timestamp = data['createdAt'] as Timestamp;
          final date = timestamp.toDate();
          final dayKey = DateTime(date.year, date.month, date.day);

          if (activityData.containsKey(dayKey)) {
            activityData[dayKey] = activityData[dayKey]! + 1;
          }
        }
      }

      return activityData;
    } catch (e) {
      avoidPrint('Error getting violation activity data: $e');
      return {};
    }
  }
}
