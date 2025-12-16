import 'package:flutter/material.dart';
import 'package:social_media_admin/models/post.dart';
import 'package:social_media_admin/utils/colors.dart';
import 'package:intl/intl.dart';

class PostViolationDialog extends StatelessWidget {
  final Post post;

  const PostViolationDialog({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive layout
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Determine dialog width based on screen size
    final dialogWidth = screenWidth > 800
        ? 600.0 // Desktop/Large tablet
        : screenWidth > 600
        ? screenWidth *
              0.85 // Small tablet
        : screenWidth * 0.95; // Mobile (shouldn't happen but just in case)

    return AlertDialog(
      backgroundColor: webBackgroundColor,
      title: Row(
        children: const [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text(
            'Lịch sử vi phạm cập nhật',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        // Add max height constraint for scrollability
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                screenHeight * 0.8, // Limit height to 80% of screen height
          ),
          child: SingleChildScrollView(
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

                // 4. Attempted update image
                if (post.attemptedUpdateImage != null &&
                    post.attemptedUpdateImage!.isNotEmpty) ...[
                  const Text(
                    'Hình ảnh định đăng (Đã bị chặn):',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        post.attemptedUpdateImage!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color: secondaryColor,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Không thể tải hình ảnh',
                                  style: TextStyle(color: secondaryColor),
                                ),
                              ],
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 5. Update status
                const Text(
                  'Trạng thái cập nhật:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: post.updateStatus == 'failed'
                        ? errorBackgroundColor.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: post.updateStatus == 'failed'
                          ? errorBackgroundColor.withValues(alpha: 0.3)
                          : Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        post.updateStatus == 'failed'
                            ? Icons.cancel
                            : Icons.help_outline,
                        size: 16,
                        color: post.updateStatus == 'failed'
                            ? errorBackgroundColor
                            : secondaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        post.updateStatus ?? 'Không rõ',
                        style: TextStyle(
                          fontSize: 12,
                          color: post.updateStatus == 'failed'
                              ? errorBackgroundColor
                              : secondaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 4. Timestamp
                Text(
                  'Thời gian phát hiện: ${DateFormat('HH:mm dd/MM/yyyy').format(post.moderatedAt ?? DateTime.now())}',
                  style: const TextStyle(fontSize: 12, color: secondaryColor),
                ),
              ],
            ),
          ),
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
