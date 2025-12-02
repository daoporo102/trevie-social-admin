import 'package:flutter/material.dart';
import 'package:social_media_admin/utils/colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: webBackgroundColor,
      appBar: AppBar(
        title: const Text('Cài đặt'),
        backgroundColor: webBackgroundColor,
        foregroundColor: primaryTextColor,
      ),
      body: const Center(
        child: Text('Danh sách cài đặt'),
      ),
    );
  }
}