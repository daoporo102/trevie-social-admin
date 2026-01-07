import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:social_media_admin/models/violation_log.dart';
import 'package:social_media_admin/services/admin_firestore_methods.dart';
import 'package:social_media_admin/utils/colors.dart';
import 'package:social_media_admin/widgets/semi_circle_score_widget.dart';

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SemiCircleScoreWidget(title: "Tổng hợp", score: log.aiConfidence),
            if (log.textScore > 0)
              SemiCircleScoreWidget(title: "Văn bản", score: log.textScore),
            if (log.imageScore > 0)
              SemiCircleScoreWidget(title: "Hình ảnh", score: log.imageScore),
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

        // Toxic Text Evidence
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

        // Multiple Images Evidence
        if (log.toxicImages.isNotEmpty) ...[
          // Header with count
          Row(
            children: [
              Icon(Icons.image, size: 16, color: Colors.orange),
              const SizedBox(width: 6),
              Text(
                'Hình ảnh vi phạm (${log.toxicImages.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: primaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Images Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // 2 images per row
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: log.toxicImages.length,
            itemBuilder: (context, index) {
              final imageData = log.toxicImages[index];
              final imageUrl = imageData.url;

              return GestureDetector(
                onTap: () {
                  // Show fullscreen image on tap
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      backgroundColor: Colors.transparent,
                      child: Stack(
                        children: [
                          Center(
                            child: InteractiveViewer(
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                  Icons.broken_image,
                                  size: 64,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 30,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            decoration: BoxDecoration(
                              color: secondaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.broken_image,
                                  size: 32,
                                  color: secondaryColor,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Không thể tải",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: secondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                              ),
                            );
                          },
                        ),
                      ),

                      // Image index badge
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${index + 1}/${log.toxicImages.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      // Expand icon
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.zoom_in,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
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
