import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:social_media_admin/models/violation_log.dart';
import 'package:social_media_admin/services/admin_firestore_methods.dart';
import 'package:social_media_admin/utils/colors.dart';

class ViolationDetailModal extends StatelessWidget {
  final ViolationLog log;

  const ViolationDetailModal({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Center(
        child: GestureDetector(
          onTap: () {}, // Prevent closing when tapping on the dialog
          child: Container(
            width: 600,
            height: screenHeight * 0.85,
            decoration: BoxDecoration(
              color: webBackgroundColor,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Chi tiết Vi phạm',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: secondaryColor),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Đóng',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoSection(),
                        const SizedBox(height: 24),
                        _buildAiAnalysisSection(),
                        const SizedBox(height: 24),
                        if (log.violationLabels.isNotEmpty) ...[
                          _buildDetectedLabelsSection(),
                          const SizedBox(height: 24),
                        ],
                        _buildEvidenceSection(),
                      ],
                    ),
                  ),
                ),

                // Actions
                const Divider(height: 1),
                _buildActionButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Thông tin chung",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildInfoRow("User ID:", log.uid, isCopiable: true),
        _buildInfoRow("Hành động:", log.actionType.toUpperCase()),
        _buildInfoRow("Xử lý bởi:", log.moderatedBy),
        _buildInfoRow(
          "Thời gian:",
          DateFormat('HH:mm dd/MM/yyyy').format(log.createdAt),
        ),
      ],
    );
  }

  Widget _buildAiAnalysisSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Phân tích AI",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildScoreBadge("Tổng hợp", log.aiConfidence),
            if (log.textScore > 0) _buildScoreBadge("Văn bản", log.textScore),
            if (log.imageScore > 0)
              _buildScoreBadge("Hình ảnh", log.imageScore),
          ],
        ),
      ],
    );
  }

  Widget _buildDetectedLabelsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Các lỗi phát hiện",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: errorBackgroundColor,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: log.violationLabels
              .map(
                (label) => Chip(
                  label: Text(
                    label.replaceAll('banned_object:', ''),
                    style: const TextStyle(
                      color: errorBackgroundColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: errorBackgroundColor.withValues(alpha: 0.1),
                  side: BorderSide(
                    color: errorBackgroundColor.withValues(alpha: 0.2),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildEvidenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Bằng chứng vi phạm",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
        const SizedBox(height: 10),
        if (log.toxicText != null && log.toxicText!.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.orange..withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
            ),
            child: Text(
              log.toxicText!,
              style: const TextStyle(
                color: primaryTextColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (log.toxicImageUrl != null && log.toxicImageUrl!.isNotEmpty)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  log.toxicImageUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: secondaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text("Không thể tải ảnh bằng chứng"),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () async {
              await AdminFirestoreMethod().markLogAsRead(log.logId);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Đã xem / Bỏ qua"),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: errorBackgroundColor,
              foregroundColor: onPrimaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => _confirmSuspendUser(context, log.uid),
            icon: const Icon(Icons.block),
            label: const Text("Đình chỉ người dùng"),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isCopiable = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: secondaryColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: const TextStyle(color: primaryTextColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBadge(String title, double score) {
    Color color = score > 0.8
        ? errorBackgroundColor
        : (score > 0.5 ? Colors.orange : appPrimaryColor);
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: secondaryColor,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
          ),
          child: Center(
            child: Text(
              "${(score * 100).toStringAsFixed(0)}%",
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmSuspendUser(BuildContext context, String uid) {
    // This can be replaced with your existing SuspendUserDialog for full consistency
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Xác nhận đình chỉ người dùng"),
        content: Text(
          "Bạn có chắc chắn muốn đình chỉ người dùng với UID: $uid?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: errorBackgroundColor,
              foregroundColor: onPrimaryColor,
            ),
            onPressed: () async {
              // For simplicity, directly calling suspend. Ideally, this would open the full SuspendUserDialog.
              await AdminFirestoreMethod().suspendUser(uid);
              if (context.mounted) {
                Navigator.of(dialogContext).pop(); // Close dialog
                Navigator.of(context).pop(); // Close modal
              }
            },
            child: const Text("Đình chỉ"),
          ),
        ],
      ),
    );
  }
}
