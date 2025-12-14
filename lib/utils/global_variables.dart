import 'package:flutter/material.dart';
import 'package:social_media_admin/utils/colors.dart';

final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

Widget customCircularProgressIndicator() {
  return Center(
    child: CircularProgressIndicator(
      backgroundColor: secondaryColor,
      color: appPrimaryColor,
    ),
  );
}

const Map<String, String> fieldLabels = {
  // Basic Info
  'postId': 'ID Bài viết',
  'uid': 'ID Người đăng',
  'displayName': 'Tên hiển thị',
  'profImage': 'Ảnh đại diện (Link)',
  'role': 'Vai trò',
  'datePublished': 'Ngày đăng',
  'dateUpdated': 'Ngày cập nhật',
  'lastDateModified': 'Sửa đổi lần cuối',

  // Content Info
  'postText': 'Nội dung bài viết',
  'postUrl': 'Hình ảnh bài viết (Link)',

  // Interaction
  'likes': 'Danh sách Like (UID)',
  'likesCount': 'Số lượt thích',
  'reshareCount': 'Số lượt chia sẻ',

  // Reshare (original post info)
  'originalPostId': 'ID Bài gốc',
  'originalUid': 'ID Tác giả gốc',
  'originalPostText': 'Nội dung gốc',
  'originalDisplayName': 'Tên tác giả gốc',
  'originalProfImage': 'Avatar tác giả gốc',

  // Moderation Info
  'status': 'Trạng thái hiện tại',
  'aiReasonText': 'Lý do AI chặn (Văn bản)',
  'aiReasonImage': 'Lý do AI chặn (Hình ảnh)',
  'textChecked': 'Đã kiểm tra Văn bản bởi AI',
  'imageChecked': 'Đã kiểm tra Hình ảnh bởi AI',
  'adminReason': 'Lý do Admin chặn',
  'moderatedBy': 'Người kiểm duyệt',
  'moderatedAt': 'Thời gian kiểm duyệt',

  // Update Rollback
  'updateStatus': 'Trạng thái Cập nhật',
  'updateError': 'Lỗi cập nhật (Lý do)',
  'attemptedUpdateText': 'Nội dung định sửa (Vi phạm)',
};
