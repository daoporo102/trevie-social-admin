import 'package:flutter/material.dart';
import 'package:social_media_admin/utils/colors.dart';

class CommentsListScreen extends StatelessWidget {
  const CommentsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: webBackgroundColor,
      appBar: AppBar(
        title: const Text('Quản lý bình luận'),
        backgroundColor: webBackgroundColor,
        foregroundColor: primaryTextColor,
      ),
      body: const Center(
        child: Text('Danh sách bình luận'),
      ),
    );
  }
}