import 'package:flutter/material.dart';
import 'package:social_media_admin/models/post.dart';
import 'package:social_media_admin/utils/colors.dart';

class DeletePostDialog extends StatelessWidget {
  final Post post;

  const DeletePostDialog({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: webBackgroundColor,
      title: Row(
        children: [
          Icon(Icons.delete_forever, color: errorBackgroundColor),
          const SizedBox(width: 8),
          const Text(
            'Xác nhận xóa bài viết',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Post Preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: post.profImage.isNotEmpty
                              ? NetworkImage(post.profImage)
                              : null,
                          child: post.profImage.isEmpty
                              ? Icon(
                                  Icons.person,
                                  size: 16,
                                  color: appPrimaryColor,
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            post.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      post.postText,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.favorite, size: 14, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(
                          '${post.likes.length} lượt thích',
                          style: TextStyle(fontSize: 12, color: secondaryColor),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.repeat, size: 14, color: appPrimaryColor),
                        const SizedBox(width: 4),
                        Text(
                          '${post.reshareCount} lượt chia sẻ',
                          style: TextStyle(fontSize: 12, color: secondaryColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Main warning message
              const Text(
                'Bạn có chắc chắn muốn xóa bài viết này?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: primaryTextColor,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Hành động này sẽ xóa vĩnh viễn bài viết và KHÔNG THỂ HOÀN TÁC!',
                style: TextStyle(
                  fontSize: 14,
                  color: errorBackgroundColor,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 16),

              // Warning box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: errorBackgroundColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: errorBackgroundColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: errorBackgroundColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Dữ liệu sẽ bị xóa bao gồm:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: errorBackgroundColor,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWarningItem('• Nội dung bài viết'),
                          _buildWarningItem('• Hình ảnh đính kèm'),
                          _buildWarningItem(
                            '• Tất cả bình luận (${post.likes.length} bình luận)',
                          ),
                          _buildWarningItem(
                            '• Lượt thích và chia sẻ',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.delete_forever),
          label: const Text('Xóa vĩnh viễn'),
          style: ElevatedButton.styleFrom(
            backgroundColor: errorBackgroundColor,
            foregroundColor: onPrimaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildWarningItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: errorBackgroundColor.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}