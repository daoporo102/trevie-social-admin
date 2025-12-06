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