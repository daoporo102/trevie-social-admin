import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:social_media_admin/widgets/custom_snack_bar.dart';

void avoidPrint(String s) {
  if (kDebugMode) {
    print(s);
  }
}

Future<Uint8List?> pickImage(ImageSource source) async {
  // Your image picking logic here
  final ImagePicker imagePicker = ImagePicker();
  final XFile? file = await imagePicker.pickImage(source:  source);
  if (file==null) {
    avoidPrint("No image selected");
    return null;
  }
  return await file.readAsBytes();
}

void displaySnackBar(String text, BuildContext context, SnackBarType type) {
  ScaffoldMessenger.of(context).showSnackBar(
    CustomSnackBar.buildSnackBar(
      text: text,
      type: type,
    ),
  );
}