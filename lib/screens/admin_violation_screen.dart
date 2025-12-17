import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:social_media_admin/models/violation_log.dart';
import 'package:social_media_admin/screens/violation_detail_modal.dart';
import 'package:social_media_admin/utils/colors.dart';
import 'package:social_media_admin/utils/global_variables.dart';

class AdminViolationScreen extends StatefulWidget {
  const AdminViolationScreen({super.key});

  @override
  State<AdminViolationScreen> createState() => _AdminViolationScreenState();
}

class _AdminViolationScreenState extends State<AdminViolationScreen> {
  final _violationStream = FirebaseFirestore.instance
      .collection('violation_logs')
      .orderBy('createdAt', descending: true)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: webBackgroundColor,
      appBar: AppBar(
        title: const Text('Quản lý Vi Phạm AI'),
        backgroundColor: webBackgroundColor,
        foregroundColor: primaryTextColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _violationStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: customCircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('Hệ thống chưa ghi nhận vi phạm nào.'),
            );
          }
          final violationDocs = snapshot.data!.docs;
          final logs = violationDocs
              .map((doc) => ViolationLog.fromSnap(doc))
              .toList();

          return _buildDataTable(logs);
        },
      ),
    );
  }

  Widget _buildDataTable(List<ViolationLog> logs) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: secondaryColor.withValues(alpha: 0.1),
            spreadRadius: 2,
            blurRadius: 5,
          ),
        ],
      ),
      child: DataTable2(
        columnSpacing: 12,
        horizontalMargin: 12,
        minWidth: 900,
        dataRowHeight: 70,
        headingRowHeight: 56,
        columns: const [
          DataColumn2(label: Text('Mức độ'), size: ColumnSize.S),
          DataColumn2(label: Text('Lý do vi phạm'), size: ColumnSize.L),
          DataColumn2(label: Text('Người dùng'), size: ColumnSize.M),
          DataColumn2(label: Text('Loại'), size: ColumnSize.S),
          DataColumn2(label: Text('Thời gian'), size: ColumnSize.M),
          DataColumn2(label: Text('Trạng thái'), size: ColumnSize.S),
        ],
        rows: logs.map((log) => _buildDataRow(log)).toList(),
      ),
    );
  }

  DataRow2 _buildDataRow(ViolationLog log) {
    final dateStr = DateFormat('HH:mm dd/MM/yyyy').format(log.createdAt);
    final severityColor = _getSeverityColor(log.aiConfidence);

    return DataRow2(
      onTap: () => _showViolationDetails(context, log),
      color: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.hovered)) {
          return appPrimaryColor.withValues(alpha: 0.08);
        }
        return log.isRead ? Colors.white : Colors.green.withValues(alpha: 0.05);
      }),
      cells: [
        // Severity
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: severityColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              "${(log.aiConfidence * 100).toStringAsFixed(2)}%",
              style: TextStyle(
                color: severityColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        // Reason
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                log.reason,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: primaryTextColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (log.violationLabels.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: log.violationLabels
                      .take(3)
                      .map(
                        (label) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: errorBackgroundColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            label.replaceAll('banned_object:', ''),
                            style: const TextStyle(
                              color: errorBackgroundColor,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        // User
        DataCell(
          Tooltip(
            message: log.uid,
            child: Text(
              '...${log.uid.substring(log.uid.length - 8)}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
        // Type
        DataCell(Text(log.actionType.toUpperCase())),
        // Date
        DataCell(Text(dateStr, style: const TextStyle(fontSize: 13))),
        // Status
        DataCell(
          log.isRead
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, color: secondaryColor, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Đã xem',
                      style: TextStyle(color: secondaryColor, fontSize: 12),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: appPrimaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Mới',
                      style: TextStyle(
                        color: appPrimaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Color _getSeverityColor(double confidence) {
    if (confidence >= 0.9) return errorBackgroundColor;
    if (confidence >= 0.75) return Colors.orange;
    return infoBackgroundColor;
  }

  void _showViolationDetails(BuildContext context, ViolationLog log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ViolationDetailModal(log: log),
    );
  }
}
