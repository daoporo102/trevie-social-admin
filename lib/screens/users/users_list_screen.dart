import 'package:flutter/material.dart';
import 'package:social_media_admin/utils/colors.dart';

class UsersListScreen extends StatelessWidget {
  const UsersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: webBackgroundColor,
      appBar: AppBar(
        title: Text('Quản lí người dùng'),
        backgroundColor: webBackgroundColor,
        foregroundColor: primaryTextColor,
      ),
      body: Center(child: Text('Danh sách người dùng')),
    );
  }
}
