import 'package:flutter/material.dart';
import 'package:social_media_admin/models/user.dart' as model;
import 'package:social_media_admin/utils/colors.dart';

class DeleteUserDialog extends StatefulWidget {
  final model.User user;

  const DeleteUserDialog({super.key, required this.user});

  @override
  State<DeleteUserDialog> createState() => _DeleteUserDialogState();
}

class _DeleteUserDialogState extends State<DeleteUserDialog> {
  final TextEditingController _reasonController = TextEditingController();
  String? _selectedReason;

  final List<String> _predefinedReasons = [
    'Vi phạm chính sách cộng đồng',
    'Spam hoặc lạm dụng',
    'Nội dung không phù hợp',
    'Yêu cầu của người dùng',
    'Tài khoản giả mạo',
    'Lý do khác',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String? _getDeletionReason() {
    if (_selectedReason == 'Lý do khác') {
      final customReason = _reasonController.text.trim();
      return customReason.isNotEmpty ? customReason : null;
    }
    return _selectedReason;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: webBackgroundColor,
      title: Row(
        children: [
          Icon(Icons.delete, color: errorBackgroundColor),
          const SizedBox(width: 8),
          const Text(
            'Xác nhận xóa người dùng',
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
              // User Preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: widget.user.photoUrl.isNotEmpty
                          ? NetworkImage(widget.user.photoUrl)
                          : null,
                      child: widget.user.photoUrl.isEmpty
                          ? Icon(Icons.person, size: 24, color: appPrimaryColor)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.user.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.user.email,
                            style: TextStyle(
                              fontSize: 13,
                              color: secondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Main confirmation message
              const Text(
                'Bạn có chắc chắn muốn xóa người dùng này?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: primaryTextColor,
                ),
              ),

              const SizedBox(height: 16),

              // Reason dropdown
              const Text(
                'Lý do xóa: *',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedReason,
                decoration: InputDecoration(
                  hintText: 'Chọn lý do xóa',
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
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: primaryTextColor,
                  ),
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

              const SizedBox(height: 16),

              // Warning message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: errorBackgroundColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: errorBackgroundColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: errorBackgroundColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Người dùng sẽ được chuyển vào thùng rác và có thể khôi phục sau.',
                        style: TextStyle(
                          fontSize: 13,
                          color: errorBackgroundColor,
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
        ElevatedButton.icon(
          onPressed: () {
            final reason = _getDeletionReason();
            if (reason == null || reason.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Vui lòng chọn hoặc nhập lý do xóa'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            Navigator.pop(context, reason);
          },
          icon: const Icon(Icons.delete),
          label: const Text('Xóa người dùng'),
          style: ElevatedButton.styleFrom(
            backgroundColor: errorBackgroundColor,
            foregroundColor: onPrimaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }
}
