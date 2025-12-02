import 'package:flutter/material.dart';
import 'package:social_media_admin/utils/colors.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: webBackgroundColor,
      appBar: AppBar(
        title: const Text('Quản lý báo cáo'),
        backgroundColor: webBackgroundColor,
        foregroundColor: primaryTextColor,
      ),
      body: const Center(
        child: Text('Danh sách báo cáo'),
      ),
    );
  }
}