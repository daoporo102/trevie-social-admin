import 'package:flutter/material.dart';
import 'package:social_media_admin/models/post.dart';
import 'package:social_media_admin/utils/colors.dart';
import 'package:intl/intl.dart';

class PostViolationDialog extends StatelessWidget {
  final Post post;

  const PostViolationDialog({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.history_edu, color: Colors.deepPurple),
          SizedBox(width: 8),
          Text('Lịch sử vi phạm cập nhật'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bài viết này đang hiển thị bình thường (Active), nhưng người dùng đã cố gắng cập nhật nội dung vi phạm sau đây:',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: secondaryColor,
              ),
            ),
            const SizedBox(height: 20),

            // 1. Reasons AI blocks
            const Text(
              'Lý do AI chặn:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                post.updateError ?? 'Không rõ lý do',
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 2. Attempted updated text
            const Text(
              'Nội dung định đăng (Đã bị chặn):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              // Display the attempted updated text or a placeholder if null
              child: Text(
                post.attemptedUpdateText ?? "Không có dữ liệu chi tiết",
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 3. Timestamp
            Text(
              'Thời gian phát hiện: ${DateFormat('HH:mm dd/MM/yyyy').format(post.moderatedAt ?? DateTime.now())}',
              style: const TextStyle(fontSize: 12, color: secondaryColor),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}
