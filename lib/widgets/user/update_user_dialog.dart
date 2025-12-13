import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:social_media_admin/models/user.dart' as model;
import 'package:social_media_admin/services/user_service.dart';
import 'package:social_media_admin/utils/colors.dart';
import 'package:social_media_admin/utils/global_variables.dart';
import 'package:social_media_admin/utils/utils.dart';
import 'package:social_media_admin/widgets/custom_snack_bar.dart';
import 'package:social_media_admin/widgets/text_field_input.dart';

class UpdateUserDialog extends StatefulWidget {
  final model.User user;
  final VoidCallback onUserUpdated;

  const UpdateUserDialog({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<UpdateUserDialog> createState() => _UpdateUserDialogState();
}

class _UpdateUserDialogState extends State<UpdateUserDialog> {
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  late TextEditingController _dateOfBirthController;
  Uint8List? _newImage;
  DateTime? _selectedDateOfBirth;
  bool _isUpdating = false;

  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.user.displayName,
    );
    _bioController = TextEditingController(text: widget.user.bio ?? '');
    _selectedDateOfBirth = widget.user.dateOfBirth;
    _dateOfBirthController = TextEditingController(
      text: widget.user.dateOfBirth != null
          ? DateFormat('dd/MM/yyyy').format(widget.user.dateOfBirth!)
          : '',
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }

  Future<void> _selectImage() async {
    final image = await pickImage(ImageSource.gallery);
    if (image != null) {
      setState(() {
        _newImage = image;
      });
    }
  }

  Future<void> _selectDateOfBirth() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: appPrimaryColor,
              onPrimary: onPrimaryColor,
              onSurface: primaryTextColor,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() {
        _selectedDateOfBirth = date;
        _dateOfBirthController.text = DateFormat('dd/MM/yyyy').format(date);
      });
    }
  }

  Future<void> _updateUser() async {
    if (_displayNameController.text.trim().isEmpty) {
      displaySnackBar(
        'Vui lòng nhập tên hiển thị',
        context,
        SnackBarType.error,
      );
      return;
    }

    if (_bioController.text.trim().isNotEmpty &&
        _bioController.text.trim().length > 150) {
      displaySnackBar(
        'Tiểu sử không được vượt quá 150 ký tự',
        context,
        SnackBarType.error,
      );
      return;
    }

    if (_selectedDateOfBirth != null &&
        _selectedDateOfBirth!.isAfter(DateTime.now())) {
      displaySnackBar('Ngày sinh không hợp lệ', context, SnackBarType.error);
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final result = await _userService.updateUserProfile(
        uid: widget.user.uid,
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim().isNotEmpty
            ? _bioController.text.trim()
            : null,
        dateOfBirth: _selectedDateOfBirth,
        image: _newImage,
        existingImageUrl: widget.user.photoUrl,
      );

      if (!mounted) return;

      if (result == 'success') {
        displaySnackBar(
          'Cập nhật người dùng thành công',
          context,
          SnackBarType.success,
        );
        widget.onUserUpdated();
        Navigator.pop(context);
      } else {
        displaySnackBar(result, context, SnackBarType.error);
      }
    } catch (e) {
      if (!mounted) return;
      displaySnackBar(
        'Đã xảy ra lỗi khi cập nhật người dùng',
        context,
        SnackBarType.error,
      );
      avoidPrint('Error updating user: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: webBackgroundColor,
      title: Row(
        children: [
          Icon(Icons.edit, color: infoBackgroundColor),
          const SizedBox(width: 8),
          const Text(
            'Cập nhật thông tin người dùng',
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
              // Profile Image Picker
              const Text(
                'Ảnh đại diện:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: _isUpdating ? null : _selectImage,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: appPrimaryColor.withValues(alpha: 0.1),
                          border: Border.all(
                            color: appPrimaryColor.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: _newImage != null
                            ? ClipOval(
                                child: Image.memory(
                                  _newImage!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : widget.user.photoUrl.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  widget.user.photoUrl,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(
                                Icons.person,
                                size: 48,
                                color: appPrimaryColor,
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          onTap: _isUpdating ? null : _selectImage,
                          customBorder: const CircleBorder(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: appPrimaryColor,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.edit,
                              size: 20,
                              color: appPrimaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Email (Read-only)
              const Text(
                'Email: (Không thể thay đổi)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: TextEditingController(text: widget.user.email),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
                enabled: false,
              ),
              const SizedBox(height: 16),

              // Display Name
              const Text(
                'Tên hiển thị: *',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              TextFieldInput(
                textEditingController: _displayNameController,
                hintText: 'Nhập tên hiển thị',
                textInputType: TextInputType.text,
                prefixIcon: Icons.person_outline,
                labelText: 'Tên hiển thị',
                isLoading: !_isUpdating,
              ),
              const SizedBox(height: 16),

              // Bio
              const Text(
                'Tiểu sử: (Tùy chọn)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              TextFieldInput(
                textEditingController: _bioController,
                hintText: 'Nhập tiểu sử ngắn gọn',
                textInputType: TextInputType.multiline,
                prefixIcon: Icons.info_outline,
                labelText: 'Tiểu sử',
                isLoading: !_isUpdating,
                helperText: 'Tối đa 150 ký tự',
                maxLines: 3,
                maxLength: 150,
              ),
              const SizedBox(height: 16),

              // Date of Birth
              const Text(
                'Ngày sinh: (Tùy chọn)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _isUpdating ? null : _selectDateOfBirth,
                child: AbsorbPointer(
                  child: TextField(
                    controller: _dateOfBirthController,
                    decoration: InputDecoration(
                      labelText: 'Ngày sinh',
                      hintText: 'Chọn ngày sinh',
                      prefixIcon: const Icon(Icons.cake_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: _dateOfBirthController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _isUpdating
                                  ? null
                                  : () {
                                      setState(() {
                                        _selectedDateOfBirth = null;
                                        _dateOfBirthController.clear();
                                      });
                                    },
                            )
                          : null,
                    ),
                    enabled: !_isUpdating,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUpdating ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton.icon(
          onPressed: _isUpdating ? null : _updateUser,
          icon: _isUpdating
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: customCircularProgressIndicator(),
                )
              : const Icon(Icons.save),
          label: Text(_isUpdating ? 'Đang cập nhật...' : 'Cập nhật'),
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
