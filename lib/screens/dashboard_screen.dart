import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:social_media_admin/services/admin_management_service.dart';
import 'package:social_media_admin/services/dashboard_service.dart';
import 'package:social_media_admin/utils/colors.dart';
import 'package:social_media_admin/utils/global_variables.dart';
import 'package:social_media_admin/utils/utils.dart';
import 'package:social_media_admin/widgets/line_chart_widget.dart';
import 'package:social_media_admin/widgets/stat_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardService _dashboardService = DashboardService();
  final AdminManagementService _adminService = AdminManagementService();

  // Statistics
  int _totalUsers = 0;
  int _totalPosts = 0;
  int _totalComments = 0;
  int _newUsersToday = 0;
  int _totalViolations = 0;

  // Chart data
  Map<DateTime, int> _userGrowthData = {};
  Map<DateTime, int> _postActivityData = {};
  List<Map<String, dynamic>> _mostActiveUsers = [];
  Map<DateTime, int> _violationActivityData = {};

  // Loading states
  bool _isLoadingStats = true;
  bool _isLoadingCharts = true;

  // Time period selections
  TimePeriod _userGrowthPeriod = TimePeriod.week;
  TimePeriod _postActivityPeriod = TimePeriod.week;
  TimePeriod _violationActivityPeriod = TimePeriod.week;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _verifyAdminAccess();
  }

  Future<void> _verifyAdminAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        avoidPrint("Đang chuẩn bị kiểm tra quyền...");
        final status = await _adminService.checkAdminStatus(user.email!);
        avoidPrint("Kết quả check: $status");
        if (status['isAdmin'] == true) {
          // Nếu là admin, lại refresh lần nữa để đảm bảo các request sau này (như tạo user) ok
          await user.getIdToken(true);
          avoidPrint("Đã đồng bộ quyền Admin thành công!");
          // FIXED: Check mounted before setState
          if (mounted) {
            setState(() {
              // Cập nhật UI nếu cần
            });
          }
        } else {
          avoidPrint("Tài khoản này không có quyền truy cập Dashboard");
        }
      } catch (e) {
        avoidPrint("Lỗi khi verify admin: $e");
      }
    } else {
      avoidPrint("User chưa đăng nhập (User is null)");
    }
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    // Load statistics
    setState(() {
      _isLoadingStats = true;
    });

    final results = await Future.wait([
      _dashboardService.getCounters(),
      _dashboardService.getNewUsersToday(),
    ]);

    if (!mounted) return;

    final counters = results[0] as Map<String, int>;

    setState(() {
      _totalUsers = counters['totalUsers'] ?? 0;
      _totalPosts = counters['totalPosts'] ?? 0;
      _totalComments = counters['totalComments'] ?? 0;
      _totalViolations = counters['totalViolations'] ?? 0;
      _newUsersToday = results[1] as int;
      _isLoadingStats = false;
    });

    // Load chart data with current period selections
    await _loadChartData();
  }

  Future<void> _loadChartData() async {
    if (!mounted) return;

    setState(() {
      _isLoadingCharts = true;
    });

    final chartResults = await Future.wait([
      _dashboardService.getUserGrowthData(period: _userGrowthPeriod),
      _dashboardService.getPostActivityData(period: _postActivityPeriod),
      _dashboardService.getViolationActivityData(period: _violationActivityPeriod), // ✅ NEW
      _dashboardService.getMostActiveUsers(),
    ]);

    if (!mounted) return;

    setState(() {
      _userGrowthData = chartResults[0] as Map<DateTime, int>;
      _postActivityData = chartResults[1] as Map<DateTime, int>;
      _violationActivityData = chartResults[2] as Map<DateTime, int>;
      _mostActiveUsers = chartResults[3] as List<Map<String, dynamic>>;
      _isLoadingCharts = false;
    });
  }

  // Handle violation period change
  Future<void> _onViolationActivityPeriodChanged(TimePeriod period) async {
    if (!mounted) return;
    setState(() {
      _violationActivityPeriod = period;
      _isLoadingCharts = true;
    });

    final data = await _dashboardService.getViolationActivityData(period: period);

    if (!mounted) return;
    setState(() {
      _violationActivityData = data;
      _isLoadingCharts = false;
    });
  }

  Future<void> _onUserGrowthPeriodChanged(TimePeriod period) async {
    if (!mounted) return;

    setState(() {
      _userGrowthPeriod = period;
      _isLoadingCharts = true;
    });

    final data = await _dashboardService.getUserGrowthData(period: period);

    if (!mounted) return;

    setState(() {
      _userGrowthData = data;
      _isLoadingCharts = false;
    });
  }

  Future<void> _onPostActivityPeriodChanged(TimePeriod period) async {
    if (!mounted) return;
    setState(() {
      _postActivityPeriod = period;
      _isLoadingCharts = true;
    });

    final data = await _dashboardService.getPostActivityData(period: period);

    if (!mounted) return;
    setState(() {
      _postActivityData = data;
      _isLoadingCharts = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: webBackgroundColor,
      appBar: AppBar(
        title: Text('Bảng điều khiển'),
        backgroundColor: webBackgroundColor,
        foregroundColor: primaryTextColor,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Làm mới dữ liệu',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chào mừng đến với bảng điều khiển quản trị TreVie',
                style: TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                'Tổng quan về hoạt động nền tảng của bạn',
                style: TextStyle(fontSize: 16.0, color: secondaryColor),
              ),
              const SizedBox(height: 24.0),

              // Statistics Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 1200
                      ? 5
                      : constraints.maxWidth > 800
                      ? 3
                      : 2;
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16.0,
                    mainAxisSpacing: 16.0,
                    shrinkWrap: true,
                    childAspectRatio: 1.8,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      StatCard(
                        title: 'Tổng số người dùng',
                        value: _totalUsers.toString(),
                        icon: Icons.person,
                        iconColor: appPrimaryColor,
                        isLoading: _isLoadingStats,
                      ),
                      StatCard(
                        title: 'Tổng số bài đăng',
                        value: _totalPosts.toString(),
                        icon: Icons.post_add,
                        iconColor: infoBackgroundColor,
                        isLoading: _isLoadingStats,
                      ),
                      StatCard(
                        title: 'Tổng số bình luận',
                        value: _totalComments.toString(),
                        icon: Icons.comment,
                        iconColor: Colors.orange,
                        isLoading: _isLoadingStats,
                      ),
                      StatCard(
                        title: 'Tổng số vi phạm',
                        value: _totalViolations.toString(),
                        icon: Icons.warning,
                        iconColor: errorBackgroundColor,
                        isLoading: _isLoadingStats,
                      ),
                      StatCard(
                        title: 'Người dùng mới hôm nay',
                        value: _newUsersToday.toString(),
                        icon: Icons.person_add,
                        iconColor: Colors.purple,
                        isLoading: _isLoadingStats,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32.0),

              // Charts Section
              if (!_isLoadingCharts) ...[
                LineChartWidget(
                  title: 'Tăng trưởng người dùng',
                  data: _userGrowthData,
                  lineColor: appPrimaryColor,
                  currentPeriod: _userGrowthPeriod, // Add this
                  onPeriodChanged: _onUserGrowthPeriodChanged,
                ),
                const SizedBox(height: 24.0),
                LineChartWidget(
                  title: 'Hoạt động bài đăng',
                  data: _postActivityData,
                  lineColor: infoBackgroundColor,
                  currentPeriod: _postActivityPeriod, // Add this
                  onPeriodChanged: _onPostActivityPeriodChanged,
                ),
                const SizedBox(height: 24.0),

                // Violation activity chart
                LineChartWidget(
                  title: 'Vi phạm phát hiện',
                  data: _violationActivityData,
                  lineColor: errorBackgroundColor,
                  currentPeriod: _violationActivityPeriod,
                  onPeriodChanged: _onViolationActivityPeriodChanged,
                ),
                const SizedBox(height: 24.0),

                // Most Active Users
                MostActiveUsersWidget(
                  title: 'Người dùng hoạt động nhiều nhất',
                  users: _mostActiveUsers,
                  lineColor: infoBackgroundColor,
                ),
              ] else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: customCircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class MostActiveUsersWidget extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> users;
  final Color lineColor;

  const MostActiveUsersWidget({
    super.key,
    required this.title,
    required this.users,
    required this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 16.0),
          if (users.isEmpty)
            const Center(
              child: Text(
                'Chưa có người dùng hoạt động',
                style: TextStyle(fontSize: 16.0, color: secondaryColor),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: users.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final user = users[index];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: appPrimaryColor.withValues(alpha: 0.1),
                    child:
                        user['photoUrl'] != null && user['photoUrl'].isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              user['photoUrl'],
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.person,
                                  color: appPrimaryColor,
                                  size: 24,
                                );
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    );
                                  },
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            color: appPrimaryColor,
                            size: 24,
                          ),
                  ),
                  title: Text(
                    user['displayName'],
                    style: const TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6.0,
                      horizontal: 12.0,
                    ),
                    decoration: BoxDecoration(
                      color: lineColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: Text(
                      '${user['count']} bài đăng',
                      style: TextStyle(
                        fontSize: 14.0,
                        color: lineColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
