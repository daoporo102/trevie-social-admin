import 'package:flutter/material.dart';
import 'package:social_media_admin/utils/colors.dart';

Widget customCircularProgressIndicator() {
  return Center(
    child: CircularProgressIndicator(
      backgroundColor: secondaryColor,
      color: appPrimaryColor,
    ),
  );
}