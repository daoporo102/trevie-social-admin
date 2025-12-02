import 'package:flutter/material.dart';
import 'package:social_media_admin/utils/colors.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: webBackgroundColor,
      appBar: AppBar(
        title: Text('Bảng điều khiển'),
        backgroundColor: webBackgroundColor,
        foregroundColor: primaryTextColor,
      ),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chào mừng đến với trang quản trị TreVie',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tổng quan hệ thống.',
              style: TextStyle(fontSize: 16, color: secondaryColor),
            ),
            // TODO: Add dashboard widgets here
          ],
        ),
      ),
    );
  }
}
