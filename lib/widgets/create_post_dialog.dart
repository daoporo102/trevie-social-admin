import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:social_media_admin/services/post_service.dart';
import 'package:social_media_admin/utils/colors.dart';
import 'package:social_media_admin/utils/global_variables.dart';
import 'package:social_media_admin/utils/utils.dart';
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
  Uint8List? _image;
  bool _isCreatingPost = false;

  @override
  void dispose() {
    _postTextController.dispose();
    super.dispose();
  }

  Future<void> _selectImage() async {
    final image = await pickImage(ImageSource.gallery);
    if (image != null) {
      setState(() {
        _image = image;
      });
    }
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

    if (_image == null) {
      displaySnackBar(
        'Vui lòng chọn hình ảnh',
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

      if (!userDoc.exists) {
        throw Exception('Không tìm thấy thông tin người dùng');
      }

      final userData = userDoc.data() as Map<String, dynamic>;

      final result = await _postService.createPost(
        postText: _postTextController.text.trim(),
        image: _image!,
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
      title: const Text('Tạo bài viết mới'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Picker
              Center(
                child: GestureDetector(
                  onTap: _isCreatingPost ? null : _selectImage,
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
                    child: _image != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              _image!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                size: 64,
                                color: appPrimaryColor,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Chọn hình ảnh',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: appPrimaryColor,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              if (_image != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: _isCreatingPost ? null : _selectImage,
                    icon: const Icon(Icons.edit),
                    label: const Text('Thay đổi hình ảnh'),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Post Text
              TextFieldInput(
                textEditingController: _postTextController,
                hintText: 'Nhập nội dung bài viết...',
                textInputType: TextInputType.multiline,
                prefixIcon: Icons.article_outlined,
                labelText: 'Nội dung bài viết',
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
        ElevatedButton.icon(
          onPressed: _isCreatingPost ? null : _createPost,
          icon: _isCreatingPost
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: customCircularProgressIndicator(),
                )
              : const Icon(Icons.post_add),
          label: Text(_isCreatingPost ? 'Đang tạo...' : 'Tạo bài viết'),
          style: ElevatedButton.styleFrom(
            backgroundColor: appPrimaryColor,
            foregroundColor: onPrimaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }
}