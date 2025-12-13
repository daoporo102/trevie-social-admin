import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:social_media_admin/services/user_service.dart';
import 'package:social_media_admin/utils/colors.dart';
import 'package:social_media_admin/utils/global_variables.dart';
import 'package:social_media_admin/utils/utils.dart';
import 'package:social_media_admin/widgets/custom_snack_bar.dart';
import 'package:social_media_admin/widgets/text_field_input.dart';

class AddUserDialog extends StatefulWidget {
  final VoidCallback onUserCreated;
  const AddUserDialog({super.key, required this.onUserCreated});

  @override
  State<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _dateOfBirthController = TextEditingController();
  Uint8List? _image;
  DateTime? _selectedDateOfBirth;
  bool _isCreatingUser = false;

  final UserService _userService = UserService();
  final emailRegexForValidation = emailRegex;

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _bioController.dispose();
    _dateOfBirthController.dispose();
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

  Future<void> _selectDateOfBirth() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
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

  Future<void> _createUser() async {
    // Validation
    if (_displayNameController.text.trim().isEmpty) {
      displaySnackBar(
        'Vui lòng nhập tên hiển thị',
        context,
        SnackBarType.error,
      );
      return;
    }

    if (_emailController.text.trim().isEmpty) {
      displaySnackBar('Vui lòng nhập email', context, SnackBarType.error);
      return;
    }

    if (!emailRegexForValidation.hasMatch(_emailController.text.trim())) {
      displaySnackBar(
        'Địa chỉ email không hợp lệ',
        context,
        SnackBarType.error,
      );
      return;
    }

    if (_passwordController.text.trim().isEmpty) {
      displaySnackBar('Vui lòng nhập mật khẩu', context, SnackBarType.error);
      return;
    }

    if (_passwordController.text.trim().length < 6) {
      displaySnackBar(
        'Mật khẩu phải có ít nhất 6 ký tự',
        context,
        SnackBarType.error,
      );
      return;
    }

    if (_image == null) {
      displaySnackBar(
        'Vui lòng chọn ảnh đại diện',
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
      _isCreatingUser = true;
    });

    try {
      final user = await _userService.createUserforSuperAdmin(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim().isNotEmpty
            ? _bioController.text.trim()
            : null,
        dateOfBirth: _selectedDateOfBirth,
        image: _image!,
      );

      if (!mounted) return;

      if (user != null) {
        displaySnackBar(
          'Đã tạo người dùng "${user.displayName}" thành công',
          context,
          SnackBarType.success,
        );
        widget.onUserCreated();
        Navigator.pop(context);
      } else {
        displaySnackBar(
          'Không thể tạo người dùng. Vui lòng thử lại.',
          context,
          SnackBarType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      displaySnackBar(
        'Đã xảy ra lỗi khi tạo người dùng: ${e.toString()}',
        context,
        SnackBarType.error,
      );
      avoidPrint('Error creating user: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingUser = false;
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
          Icon(Icons.person_add, color: appPrimaryColor),
          const SizedBox(width: 8),
          const Text(
            'Thêm người dùng mới',
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
                        'Chỉ Super Admin mới có quyền tạo người dùng mới trong hệ thống.',
                        style: TextStyle(
                          fontSize: 13,
                          color: infoBackgroundColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Profile Image Picker
              const Text(
                'Ảnh đại diện: *',
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
                      onTap: _isCreatingUser ? null : _selectImage,
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
                        child: _image != null
                            ? ClipOval(
                                child: Image.memory(_image!, fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person,
                                    size: 48,
                                    color: appPrimaryColor,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Chọn ảnh',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: appPrimaryColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
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
                          onTap: _isCreatingUser ? null : _selectImage,
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
                              _image == null ? Icons.add_a_photo : Icons.edit,
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
                isLoading: !_isCreatingUser,
              ),
              const SizedBox(height: 16),

              // Email
              const Text(
                'Địa chỉ Email: *',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              TextFieldInput(
                textEditingController: _emailController,
                hintText: 'Nhập địa chỉ email',
                textInputType: TextInputType.emailAddress,
                prefixIcon: Icons.email_outlined,
                labelText: 'Email',
                isLoading: !_isCreatingUser,
              ),
              const SizedBox(height: 16),

              // Password
              const Text(
                'Mật khẩu: *',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              TextFieldInput(
                textEditingController: _passwordController,
                hintText: 'Nhập mật khẩu (tối thiểu 6 ký tự)',
                textInputType: TextInputType.text,
                prefixIcon: Icons.lock_outline,
                labelText: 'Mật khẩu',
                isLoading: !_isCreatingUser,
                isPass: true,
                helperText: 'Tối thiểu 6 ký tự',
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
                isLoading: !_isCreatingUser,
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
                onTap: _isCreatingUser ? null : _selectDateOfBirth,
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
                              onPressed: _isCreatingUser
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
                    enabled: !_isCreatingUser,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreatingUser ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton.icon(
          onPressed: _isCreatingUser ? null : _createUser,
          icon: _isCreatingUser
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: customCircularProgressIndicator(),
                )
              : const Icon(Icons.person_add),
          label: Text(_isCreatingUser ? 'Đang tạo...' : 'Tạo người dùng'),
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
