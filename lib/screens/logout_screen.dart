import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:social_media_admin/services/admin_auth_service.dart';
import 'package:social_media_admin/utils/colors.dart';

class LogoutScreen extends StatefulWidget {
  const LogoutScreen({super.key});

  @override
  State<LogoutScreen> createState() => _LogoutScreenState();
}

class _LogoutScreenState extends State<LogoutScreen> {
  final AdminAuthService _authService = AdminAuthService();

  @override
  void initState() {
    super.initState();
    _performLogout();
  }

  Future<void> _performLogout() async {
    try{
      await _authService.adminLogout();
    }catch (_){
      // ignore errors on logout

    }finally{
      if (!mounted) return;
      context.go('/login');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: webBackgroundColor,
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Đang đăng xuất...'),
          ],
        ),
      ),
    );
  }
}