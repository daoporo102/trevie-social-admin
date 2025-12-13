import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:social_media_admin/utils/colors.dart';
import 'package:social_media_admin/utils/global_variables.dart';

class PostDetailDialog extends StatelessWidget {
  // Get all raw data of the post from Firestore
  final Map<String, dynamic> data;

  const PostDetailDialog({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // 1. Categorize data into groups.
    final Map<String, dynamic> basicInfo = {};
    final Map<String, dynamic> contentInfo = {};
    final Map<String, dynamic> reshareInfo = {};
    final Map<String, dynamic> moderationInfo = {};
    final Map<String, dynamic> metricsInfo = {};
    final Map<String, dynamic> otherInfo = {};

    data.forEach((key, value) {
      if ([
        'postId',
        'uid',
        'displayName',
        'profImage',
        'role',
        'datePublished',
        'dateUpdated',
        'lastDateModified',
      ].contains(key)) {
        basicInfo[key] = value;
      } else if (['postText', 'postUrl'].contains(key)) {
        contentInfo[key] = value;
      } else if (key.startsWith('original')) {
        // Automatically group fields starting with 'original' into Reshare group
        reshareInfo[key] = value;
      } else if ([
        'status',
        'aiReason',
        'adminReason',
        'moderatedBy',
        'moderatedByAdminEmail',
        'moderatedAt',
        'updateStatus',
        'updateError',
        'attemptedUpdateText',
      ].contains(key)) {
        moderationInfo[key] = value;
      } else if (['likes', 'likesCount', 'reshareCount'].contains(key)) {
        metricsInfo[key] = value;
      } else {
        // Any other fields
        otherInfo[key] = value;
      }
    });

    return AlertDialog(
      backgroundColor: webBackgroundColor,
      title: Row(
        children: const [
          Icon(Icons.data_usage, color: appPrimaryColor),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Chi tiết dữ liệu bài viết (Raw Data)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
          ),
        ],
      ),
      content: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: 800,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionCard(
                context,
                'Nội dung chính',
                infoBackgroundColor,
                Icons.article,
                contentInfo,
              ),

              // Just show Reshare section if applicable
              if (reshareInfo.isNotEmpty &&
                  reshareInfo['originalPostId'] != null) ...[
                const SizedBox(height: 16),
                _buildSectionCard(
                  context,
                  'Thông tin bài gốc (Reshare)',
                  appPrimaryColor,
                  Icons.repeat,
                  reshareInfo,
                ),
              ],

              const SizedBox(height: 16),
              _buildSectionCard(
                context,
                'Trạng thái kiểm duyệt & Update',
                Colors.orange,
                Icons.verified_user,
                moderationInfo,
                highlightError: true,
              ),

              const SizedBox(height: 16),
              _buildSectionCard(
                context,
                'Thông tin cơ bản',
                secondaryColor,
                Icons.info_outline,
                basicInfo,
              ),

              const SizedBox(height: 16),
              _buildSectionCard(
                context,
                'Tương tác',
                Colors.purple,
                Icons.thumb_up,
                metricsInfo,
              ),

              if (otherInfo.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSectionCard(
                  context,
                  'Dữ liệu khác',
                  primaryTextColor,
                  Icons.more_horiz,
                  otherInfo,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('Đóng'),
        ),
      ],
    );
  }

  // --- Widgets children support display ---

  Widget _buildSectionCard(
    BuildContext context,
    String title,
    Color color,
    IconData icon,
    Map<String, dynamic> groupData, {
    bool highlightError = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(left: BorderSide(color: color, width: 4)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),

          // Section Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildGroup(
              context,
              groupData,
              highlightError: highlightError,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(
    BuildContext context,
    Map<String, dynamic> groupData, {
    bool highlightError = false,
  }) {
    if (groupData.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Center(
          child: Text(
            'Không có dữ liệu',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: secondaryColor,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    // Sort keys "alphabetically" for consistent display
    var sortedKeys = groupData.keys.toList()..sort();

    return Column(
      children: sortedKeys.asMap().entries.map((entry) {
        final index = entry.key;
        final key = entry.value;
        final isLast = index == sortedKeys.length - 1;

        return _buildRow(
          context,
          key,
          groupData[key],
          highlightError: highlightError,
          isLast: isLast,
        );
      }).toList(),
    );
  }

  Widget _buildRow(
    BuildContext context,
    String key,
    dynamic value, {
    bool highlightError = false,
    bool isLast = false,
  }) {
    String displayValue = 'null';
    Color valueColor = primaryTextColor;
    String displayLabel = fieldLabels.containsKey(key)
        ? fieldLabels[key]!
        : key;

    // Hide empty values
    if (value == null || (value is String && value.isEmpty)) {
      return const SizedBox.shrink();
    }

    // Format value
    if (value != null) {
      if (value is Timestamp) {
        displayValue = DateFormat('HH:mm dd/MM/yyyy').format(value.toDate());
        valueColor = infoBackgroundColor;
      } else if (value is bool) {
        displayValue = value ? 'True' : 'False';
        valueColor = value ? appPrimaryColor : errorBackgroundColor;
      } else if (value is List) {
        displayValue = '[Danh sách ${value.length} items]';
        valueColor = Colors.purple;
      } else {
        displayValue = value.toString();
      }
    }

    // Highlight in red if it is erroneous information (Error/Reason/Failed).
    if (highlightError) {
      if ((key.contains('Error') || key.contains('Reason')) && value != null) {
        valueColor = errorBackgroundColor;
      }
      if (value == 'failed') {
        valueColor = errorBackgroundColor;
      }
    }

    // Highlight in green if it is status active
    if (key == 'status' && value == 'active') {
      valueColor = appPrimaryColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(
                  color: primaryTextColor.withValues(alpha: 0.08),
                  width: 1,
                ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field name (Key)
          SizedBox(
            width: 180,
            child: Tooltip(
              message: 'Field gốc: $key',
              child: Text(
                displayLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: secondaryColor,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Value with selectable text
          Expanded(
            child: SelectableText(
              displayValue,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
                fontSize: 13,
              ),
            ),
          ),

          // Copy button
          if (value != null)
            Tooltip(
              message: 'Sao chép',
              child: InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value.toString()));
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.copy, size: 16, color: appPrimaryColor),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
