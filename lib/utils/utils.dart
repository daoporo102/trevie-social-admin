import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

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