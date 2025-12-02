import 'package:flutter/material.dart';
import 'package:social_media_admin/utils/colors.dart';

class PostsListScreen extends StatelessWidget {
  const PostsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: webBackgroundColor,
      appBar: AppBar(
        title: const Text('Quản lý bài viết'),
        backgroundColor: webBackgroundColor,
        foregroundColor: primaryTextColor,
      ),
      body: const Center(
        child: Text('Danh sách bài viết'),
      ),
    );
  }
}