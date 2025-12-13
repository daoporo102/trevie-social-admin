import 'package:flutter/material.dart';
import 'package:social_media_admin/models/user.dart' as model;
import 'package:social_media_admin/utils/colors.dart';

class SuspendUserDialog extends StatefulWidget {
  final model.User user;
  final bool isCurrentlySuspended;

  const SuspendUserDialog({
    super.key,
    required this.user,
    required this.isCurrentlySuspended,
  });

  @override
  State<SuspendUserDialog> createState() => _SuspendUserDialogState();
}

class _SuspendUserDialogState extends State<SuspendUserDialog> {
  final TextEditingController _reasonController = TextEditingController();
  String? _selectedReason;

  final List<String> _predefinedReasons = [
    'Vi phạm điều khoản dịch vụ',
    'Hành vi không phù hợp',
    'Spam hoặc lừa đảo',
    'Ngôn từ gây thù ghét',
    'Lý do bảo mật',
    'Lý do khác',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isCurrentlySuspended && widget.user.suspensionReason != null) {
      if (_predefinedReasons.contains(widget.user.suspensionReason)) {
        _selectedReason = widget.user.suspensionReason;
      } else {
        _selectedReason = 'Lý do khác';
        _reasonController.text = widget.user.suspensionReason!;
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String? _getSuspensionReason() {
    if (_selectedReason == 'Lý do khác') {
      final customReason = _reasonController.text.trim();
      return customReason.isNotEmpty ? customReason : null;
    }
    return _selectedReason;
  }

  @override
  Widget build(BuildContext context) {
    final isActivating = widget.isCurrentlySuspended;

    return AlertDialog(
      backgroundColor: webBackgroundColor,
      title: Row(
        children: [
          Icon(
            isActivating ? Icons.check_circle : Icons.block,
            color: isActivating ? appPrimaryColor : Colors.orange,
          ),
          const SizedBox(width: 8),
          Text(
            isActivating ? 'Kích hoạt người dùng' : 'Đình chỉ người dùng',
            style: const TextStyle(
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
              Text(
                isActivating
                    ? 'Bạn có chắc chắn muốn kích hoạt lại người dùng này?'
                    : 'Bạn có chắc chắn muốn đình chỉ người dùng này?',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: primaryTextColor,
                ),
              ),

              // Show reason selection only when suspending
              if (!isActivating) ...[
                const SizedBox(height: 16),
                const Text(
                  'Lý do đình chỉ: *',
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
                    hintText: 'Chọn lý do đình chỉ',
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
              ],

              // Show current suspension reason when activating
              if (isActivating && widget.user.suspensionReason != null) ...[
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Lý do đình chỉ trước đó:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.user.suspensionReason!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Info message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isActivating ? appPrimaryColor : Colors.orange)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (isActivating ? appPrimaryColor : Colors.orange)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isActivating
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_rounded,
                      color: isActivating ? appPrimaryColor : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isActivating
                            ? 'Người dùng sẽ có thể đăng nhập và sử dụng tất cả các tính năng.'
                            : 'Người dùng sẽ không thể đăng nhập và sử dụng ứng dụng.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isActivating ? appPrimaryColor : Colors.orange,
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
            if (!isActivating) {
              final reason = _getSuspensionReason();
              if (reason == null || reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng chọn hoặc nhập lý do đình chỉ'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context, reason);
            } else {
              Navigator.pop(context, '');
            }
          },
          icon: Icon(isActivating ? Icons.check_circle : Icons.block),
          label: Text(isActivating ? 'Kích hoạt' : 'Đình chỉ'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isActivating ? appPrimaryColor : Colors.orange,
            foregroundColor: onPrimaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }
}
