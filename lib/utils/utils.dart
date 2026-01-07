import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:social_media_admin/widgets/custom_snack_bar.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

void displaySnackBar(String text, BuildContext context, SnackBarType type) {
  // Check if context is still valid
  if (!context.mounted) return;

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(CustomSnackBar.buildSnackBar(text: text, type: type));
}

void avoidPrint(String s) {
  if (kDebugMode) {
    print(s);
  }
}

String formatTimestamp(Timestamp timestamp) {
  final now = DateTime.now();
  final messageTime = timestamp.toDate();
  final difference = now.difference(messageTime);

  if (difference.inDays == 0) {
    // Today: show HH:mm
    return DateFormat('HH:mm', 'vi').format(messageTime);
  } else if (difference.inDays == 1 && now.day > messageTime.day) {
    // Yesterday
    return 'Hôm qua';
  } else if (difference.inDays < 7) {
    // Within a week: show day of the week
    return DateFormat('EEEE', 'vi').format(messageTime);
  } else {
    // Older: show dd/MM/yyyy
    return DateFormat('dd/MM/yyyy', 'vi').format(messageTime);
  }
}

// ✅ NEW: Pick multiple images
Future<List<Uint8List>?> pickMultipleImages() async {
  final ImagePicker imagePicker = ImagePicker();
  final List<XFile> files = await imagePicker.pickMultiImage();

  if (files.isEmpty) {
    avoidPrint("No images selected");
    return null;
  }

  // Limit number of images (max 10)
  const maxImages = 10;
  if (files.length > maxImages) {
    avoidPrint("Too many images selected. Maximum is $maxImages");
    return null;
  }

  List<Uint8List> images = [];
  for (var file in files) {
    final bytes = await file.readAsBytes();
    // Auto-compress when picking
    final compressed = await compressImage(bytes);
    if (compressed != null) {
      images.add(compressed);
    }
  }

  return images;
}

// ✅ NEW: Compress single image
Future<Uint8List?> compressImage(Uint8List imageBytes) async {
  try {
    // Validate size before compress
    if (imageBytes.length > 10 * 1024 * 1024) {
      throw 'Ảnh gốc quá lớn (>10MB). Vui lòng chọn ảnh nhỏ hơn';
    }

    final result = await FlutterImageCompress.compressWithList(
      imageBytes,
      minWidth: 1920,
      minHeight: 1080,
      quality: 85,
      format: CompressFormat.jpeg,
    );

    // Check if compressed size is still too large
    if (result.length > 5 * 1024 * 1024) {
      throw 'Ảnh quá lớn (>5MB sau khi nén). Vui lòng chọn ảnh nhỏ hơn';
    }

    // Only use compression if result is smaller
    if (result.length < imageBytes.length) {
      final originalSize = imageBytes.length;
      final compressedSize = result.length;
      final ratio = ((originalSize - compressedSize) / originalSize * 100);

      avoidPrint('Original size: $originalSize bytes');
      avoidPrint('Compressed size: $compressedSize bytes');
      avoidPrint('Compression ratio: ${ratio.toStringAsFixed(1)}%');

      return result;
    } else {
      avoidPrint(
        'Image already optimized, keeping original (${imageBytes.length} bytes)',
      );
      return imageBytes;
    }
  } catch (e) {
    avoidPrint('Error compressing image: $e');
    rethrow;
  }
}

// ✅ NEW: Compress multiple images
Future<List<Uint8List>> compressImages(List<Uint8List> images) async {
  List<Uint8List> compressed = [];
  for (var image in images) {
    final result = await compressImage(image);
    if (result != null) {
      compressed.add(result);
    }
  }
  return compressed;
}

// ✅ UPDATED: Auto-compress when picking single image
Future<Uint8List?> pickImage(ImageSource source) async {
  final ImagePicker imagePicker = ImagePicker();
  final XFile? file = await imagePicker.pickImage(source: source);

  if (file != null) {
    final bytes = await file.readAsBytes();
    return await compressImage(bytes);
  }

  avoidPrint("No images selected");
  return null;
}
