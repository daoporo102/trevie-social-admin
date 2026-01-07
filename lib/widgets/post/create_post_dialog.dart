import 'dart:typed_data';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:social_media_admin/services/post_service.dart';
import 'package:social_media_admin/utils/colors.dart';
import 'package:social_media_admin/utils/global_variables.dart';
import 'package:social_media_admin/utils/utils.dart';
import 'package:social_media_admin/widgets/custom_button.dart';
import 'package:social_media_admin/widgets/custom_snack_bar.dart';
import 'package:social_media_admin/widgets/text_field_input.dart';

class CreatePostDialog extends StatefulWidget {
  final VoidCallback onPostCreated;
  const CreatePostDialog({super.key, required this.onPostCreated});

  @override
  State<CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<CreatePostDialog> {
  final TextEditingController _postTextController = TextEditingController();
  final PostService _postService = PostService();
  List<Uint8List> _images = [];
  bool _isCreatingPost = false;
  static const int maxImages = 10;

  @override
  void dispose() {
    _postTextController.dispose();
    super.dispose();
  }

  Future<void> _selectImages() async {
    return showDialog(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          backgroundColor: webBackgroundColor,
          title: const Text('Chọn ảnh cho bài đăng'),
          children: [
            SimpleDialogOption(
              padding: const EdgeInsets.all(20),
              child: const Text('Chọn ảnh từ thư viện'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                // Check limit
                if (_images.length >= maxImages) {
                  if (!mounted) return;
                  displaySnackBar(
                    'Bạn đã đạt giới hạn $maxImages ảnh',
                    context,
                    SnackBarType.error,
                  );
                  return;
                }

                try {
                  List<Uint8List>? files = await pickMultipleImages();
                  if (!mounted) return;

                  if (files == null || files.isEmpty) {
                    displaySnackBar(
                      'Không có ảnh nào được chọn',
                      context,
                      SnackBarType.error,
                    );
                    return;
                  }

                  // Calculate remaining slots
                  int remainingSlots = maxImages - _images.length;

                  if (files.length > remainingSlots) {
                    displaySnackBar(
                      'Chỉ có thể thêm $remainingSlots ảnh nữa (tối đa $maxImages ảnh)',
                      context,
                      SnackBarType.warning,
                    );
                    files = files.sublist(0, remainingSlots);
                  }

                  setState(() {
                    _images.addAll(files!);
                  });

                  displaySnackBar(
                    'Đã thêm ${files.length} ảnh (${_images.length}/$maxImages)',
                    context,
                    SnackBarType.success,
                  );
                } catch (e) {
                  if (!mounted) return;
                  displaySnackBar(
                    'Có lỗi xảy ra khi chọn ảnh',
                    context,
                    SnackBarType.error,
                  );
                  avoidPrint(e.toString());
                }
              },
            ),
            SimpleDialogOption(
              padding: const EdgeInsets.all(20),
              child: const Text('Hủy'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Remove image at index
  void _removeImage(int index) {
    setState(() {
      if (index >= 0 && index < _images.length) {
        _images.removeAt(index);
      }
    });
  }

  Future<void> _createPost() async {
    // Validate
    if (_postTextController.text.trim().isEmpty) {
      displaySnackBar(
        'Vui lòng nhập nội dung bài viết',
        context,
        SnackBarType.error,
      );
      return;
    }

    if (_postTextController.text.trim().length > 500) {
      displaySnackBar(
        'Nội dung bài viết không được vượt quá 500 ký tự',
        context,
        SnackBarType.error,
      );
      return;
    }

    if (_images.isEmpty) {
      displaySnackBar(
        'Vui lòng chọn ít nhất một ảnh',
        context,
        SnackBarType.error,
      );
      return;
    }

    setState(() {
      _isCreatingPost = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Bạn chưa đăng nhập');
      }

      // Get user data from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (!userDoc.exists) {
        throw Exception('Không tìm thấy thông tin người dùng');
      }

      final userData = userDoc.data() as Map<String, dynamic>;

      final result = await _postService.createPost(
        postText: _postTextController.text.trim(),
        images: _images,
        uid: user.uid,
        displayName: userData['displayName'] ?? 'Admin',
        profImage: userData['photoUrl'] ?? '',
      );

      if (!mounted) return;

      if (result == 'success') {
        displaySnackBar(
          'Đã tạo bài viết thành công',
          context,
          SnackBarType.success,
        );
        widget.onPostCreated();
        Navigator.pop(context);
      } else {
        displaySnackBar(result, context, SnackBarType.error);
      }
    } catch (e) {
      if (!mounted) return;
      displaySnackBar(
        'Đã xảy ra lỗi khi tạo bài viết: ${e.toString()}',
        context,
        SnackBarType.error,
      );
      avoidPrint('Error creating post: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingPost = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: webBackgroundColor,
      title: Row(
        children: const [
          Icon(Icons.post_add, color: appPrimaryColor),
          SizedBox(width: 8),
          Text(
            'Tạo bài viết mới',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: infoBackgroundColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: infoBackgroundColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: infoBackgroundColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bài viết sẽ được gửi qua hệ thống kiểm duyệt AI trước khi hiển thị công khai.',
                        style: TextStyle(
                          fontSize: 13,
                          color: infoBackgroundColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Image Picker Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hình ảnh: * (${_images.length}/$maxImages)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: _images.length >= maxImages
                          ? errorBackgroundColor
                          : primaryTextColor,
                    ),
                  ),
                  if (_images.isNotEmpty)
                    TextButton.icon(
                      onPressed: _images.length >= maxImages
                          ? null
                          : _selectImages,
                      icon: Icon(
                        Icons.add_photo_alternate,
                        size: 16,
                        color: _images.length >= maxImages
                            ? secondaryColor
                            : appPrimaryColor,
                      ),
                      label: Text(
                        _images.length >= maxImages ? 'Đã đủ' : 'Thêm ảnh',
                        style: TextStyle(
                          fontSize: 13,
                          color: _images.length >= maxImages
                              ? secondaryColor
                              : appPrimaryColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Image Preview or Empty State
              _images.isEmpty
                  ? GestureDetector(
                      onTap: _isCreatingPost ? null : _selectImages,
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: appPrimaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: appPrimaryColor.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 64,
                              color: appPrimaryColor,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Nhấn để chọn hình ảnh',
                              style: TextStyle(
                                fontSize: 14,
                                color: appPrimaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tối đa $maxImages ảnh',
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SizedBox(
                      height: 150,
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                          },
                          scrollbars: true,
                        ),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _images.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 150,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: appPrimaryColor.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child: Image.memory(
                                      _images[index],
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 12,
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: onPrimaryColor,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: Icon(
                                        Icons.close,
                                        size: 16,
                                        color: secondaryColor,
                                      ),
                                      onPressed: () => _removeImage(index),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 4,
                                  left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: onPrimaryColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${index + 1}/${_images.length}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: secondaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),

              const SizedBox(height: 24),

              // Post Text Section
              const Text(
                'Nội dung bài viết: *',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),

              TextFieldInput(
                textEditingController: _postTextController,
                hintText: 'Nhập nội dung bài viết của bạn...',
                textInputType: TextInputType.multiline,
                prefixIcon: Icons.article_outlined,
                labelText: 'Nội dung',
                isLoading: !_isCreatingPost,
                helperText: 'Tối đa 500 ký tự',
                maxLines: 5,
                maxLength: 500,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreatingPost ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        CustomButton(
          onPressed: _isCreatingPost ? () {} : () => _createPost(),
          child: _isCreatingPost
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: customCircularProgressIndicator(),
                )
              : const Text(
                  'Tạo bài viết',
                  style: TextStyle(color: onPrimaryColor),
                ),
        ),
      ],
    );
  }
}
