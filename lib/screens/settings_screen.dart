import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:social_media_admin/services/admin_auth_service.dart';
import 'package:social_media_admin/utils/colors.dart';
import 'package:social_media_admin/utils/utils.dart';
import 'package:social_media_admin/widgets/custom_snack_bar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );
  final AdminAuthService _adminAuthService = AdminAuthService();

  bool _isInitializing = false;
  bool _isSuperAdmin = false;
  bool _showAdvancedSettings = false; // Toggle for advanced features

  @override
  void initState() {
    super.initState();
    _checkSuperAdminStatus();
  }

  // Check if current user is super admin
  Future<void> _checkSuperAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _adminAuthService.refreshUserToken();
      final isSuperAdmin = await _adminAuthService.isSuperAdmin();
      setState(() {
        _isSuperAdmin = isSuperAdmin;
      });
    }
  }

  Future<void> _initializeCounters() async {
    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Xác nhận khởi tạo'),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn khởi tạo lại counters?\n\n'
          'Thao tác này sẽ đếm lại tất cả users, posts, comments và violations từ Firestore.\n\n'
          '⚠️ Chỉ nên chạy 1 lần khi lần đầu setup hoặc khi cần reset counters.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor),
            child: const Text('Khởi tạo'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isInitializing = true;
    });

    try {
      final callable = _functions.httpsCallable('initializeCounters');
      final result = await callable.call();

      if (!mounted) return;

      final counters = result.data['counters'];

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: appPrimaryColor),
              const SizedBox(width: 8),
              const Text('Khởi tạo thành công'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Đã khởi tạo counters thành công:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildCounterRow('Người dùng:', counters['users']),
              _buildCounterRow('Bài viết:', counters['posts']),
              _buildCounterRow('Bình luận:', counters['comments']),
              _buildCounterRow('Vi phạm:', counters['violations']),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: infoBackgroundColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: infoBackgroundColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Counters đã được lưu vào Firestore',
                        style: TextStyle(
                          fontSize: 12,
                          color: infoBackgroundColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );

      displaySnackBar(
        'Đã khởi tạo counters thành công',
        context,
        SnackBarType.success,
      );
    } catch (e) {
      if (!mounted) return;

      displaySnackBar(
        'Lỗi khởi tạo counters: ${e.toString()}',
        context,
        SnackBarType.error,
      );
      avoidPrint('Error initializing counters: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Widget _buildCounterRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: appPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: webBackgroundColor,
      appBar: AppBar(
        title: const Text('Cài đặt hệ thống'),
        backgroundColor: webBackgroundColor,
        foregroundColor: primaryTextColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // GENERAL SETTINGS SECTION
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: onPrimaryColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: secondaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.settings, color: appPrimaryColor),
                      const SizedBox(width: 8),
                      const Text(
                        'Cài đặt chung',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Placeholder for general settings
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: webBackgroundColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Cài đặt hệ thống',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Các tính năng cài đặt sẽ được thêm vào sau này.',
                          style: TextStyle(fontSize: 13, color: secondaryColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ADVANCED SETTINGS - Only for Super Admin
            if (_isSuperAdmin) ...[
              const SizedBox(height: 24),

              // Toggle button to show/hide advanced settings
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showAdvancedSettings = !_showAdvancedSettings;
                  });
                },
                icon: Icon(
                  _showAdvancedSettings
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                ),
                label: Text(
                  _showAdvancedSettings
                      ? 'Ẩn cài đặt nâng cao'
                      : 'Hiển thị cài đặt nâng cao (Super Admin)',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                ),
              ),

              // Advanced settings content
              if (_showAdvancedSettings) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange),
                          const SizedBox(width: 8),
                          const Text(
                            'Cài đặt nâng cao (Nguy hiểm)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '⚠️ Chỉ sử dụng khi cần thiết. Các thao tác dưới đây có thể ảnh hưởng đến toàn bộ hệ thống.',
                        style: TextStyle(
                          fontSize: 13,
                          color: secondaryColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // System Maintenance Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: onPrimaryColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calculate,
                                  size: 20,
                                  color: appPrimaryColor,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Khởi tạo Counters',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Khởi tạo bộ đếm cho dashboard (users, posts, comments, violations). '
                              'Chỉ nên chạy 1 lần khi setup hoặc khi cần reset dữ liệu.',
                              style: TextStyle(
                                fontSize: 13,
                                color: secondaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isInitializing
                                    ? null
                                    : _initializeCounters,
                                icon: _isInitializing
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: onPrimaryColor,
                                        ),
                                      )
                                    : const Icon(Icons.play_arrow),
                                label: Text(
                                  _isInitializing
                                      ? 'Đang khởi tạo...'
                                      : 'Khởi tạo Counters',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: appPrimaryColor,
                                  foregroundColor: onPrimaryColor,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}