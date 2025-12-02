import 'package:flutter/material.dart';
import 'package:social_media_admin/utils/colors.dart';

enum SnackBarType { success, info, error }

class CustomSnackBar {
  static SnackBar buildSnackBar({
    required String text,
    required SnackBarType type,
    Duration duration = const Duration(seconds: 3),
  }) {
    Color backgroundColor;
    IconData icon;

    switch (type) {
      case SnackBarType.success:
        backgroundColor = appPrimaryColor;
        icon = Icons.check_circle;
        break;
      case SnackBarType.info:
        backgroundColor = infoBackgroundColor;
        icon = Icons.info;
        break;
      case SnackBarType.error:
        backgroundColor = errorBackgroundColor;
        icon = Icons.error;
        break;
    }

    return SnackBar(
      content: Row(
        children: [
          Icon(icon, color: onPrimaryColor),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: onPrimaryColor
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.all(12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
    );
  }
}
