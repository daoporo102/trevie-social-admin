import 'package:flutter/material.dart';
import 'package:social_media_admin/models/post.dart';
import 'package:social_media_admin/utils/colors.dart';

class RejectPostDialog extends StatefulWidget {
  final Post post;
  final bool isOverridingAI;

  const RejectPostDialog({
    super.key,
    required this.post,
    this.isOverridingAI = false,
  });

  @override
  State<RejectPostDialog> createState() => _RejectPostDialogState();
}

class _RejectPostDialogState extends State<RejectPostDialog> {
  final TextEditingController _reasonController = TextEditingController();
  String? _selectedReason;

  final List<String> _predefinedReasons = [
    'Vi phạm chính sách cộng đồng',
    'Nội dung không phù hợp',
    'Spam hoặc quảng cáo',
    'Ngôn từ gây thù ghét',
    'Nội dung bạo lực',
    'Thông tin sai lệch',
    'Vi phạm bản quyền',
    'Nội dung người lớn',
    'Lý do khác',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill if post was already rejected by admin
    if (widget.post.status == 'rejected' &&
        widget.post.adminReason != null &&
        widget.post.moderatedBy == 'admin') {
      if (_predefinedReasons.contains(widget.post.adminReason)) {
        _selectedReason = widget.post.adminReason;
      } else {
        _selectedReason = 'Lý do khác';
        _reasonController.text = widget.post.adminReason!;
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String? _getRejectionReason() {
    if (_selectedReason == 'Lý do khác') {
      final customReason = _reasonController.text.trim();
      return customReason.isNotEmpty ? customReason : null;
    }
    return _selectedReason;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Từ chối bài viết'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
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
                          backgroundImage: widget.post.profImage.isNotEmpty
                              ? NetworkImage(widget.post.profImage)
                              : null,
                          child: widget.post.profImage.isEmpty
                              ? Icon(
                                  Icons.person,
                                  size: 16,
                                  color: appPrimaryColor,
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.post.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.post.postText,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Override warning if rejecting an AI-approved post
              if (widget.isOverridingAI) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bạn đang ghi đè quyết định của AI. Bài viết này đã được AI duyệt là an toàn.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              const Text(
                'Lý do từ chối: *',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),

              // Predefined reasons dropdown
              DropdownButtonFormField<String>(
                value: _selectedReason,
                decoration: InputDecoration(
                  hintText: 'Chọn lý do từ chối',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: _predefinedReasons.map((reason) {
                  return DropdownMenuItem(value: reason, child: Text(reason));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedReason = value;
                    if (value != 'Lý do khác') {
                      _reasonController.clear();
                    }
                  });
                },
              ),

              // Custom reason text field
              if (_selectedReason == 'Lý do khác') ...[
                const SizedBox(height: 16),
                const Text(
                  'Chi tiết: *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _reasonController,
                  decoration: InputDecoration(
                    hintText: 'Nhập lý do chi tiết...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  maxLines: 3,
                  maxLength: 200,
                ),
              ],

              const SizedBox(height: 12),

              // Warning message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.block, color: errorBackgroundColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bài viết sẽ bị ẩn khỏi ứng dụng và người dùng sẽ được thông báo về lý do từ chối.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red.shade800,
                        ),
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
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () {
            final reason = _getRejectionReason();
            if (reason == null || reason.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Vui lòng chọn hoặc nhập lý do từ chối'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            Navigator.pop(context, {'reason': reason});
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text('Từ chối'),
        ),
      ],
    );
  }
}
