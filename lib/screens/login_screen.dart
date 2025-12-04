import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:social_media_admin/services/admin_auth_service.dart';
import 'package:go_router/go_router.dart';
import 'package:social_media_admin/services/network_service.dart';
import 'package:social_media_admin/utils/colors.dart';
import 'package:social_media_admin/utils/utils.dart';
import 'package:social_media_admin/widgets/custom_inkwell.dart';
import 'package:social_media_admin/widgets/custom_snack_bar.dart';
import 'package:social_media_admin/widgets/network_status_banner.dart';
import 'package:social_media_admin/widgets/text_field_input.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _adminAuthService = AdminAuthService();
  final _networkService = NetworkService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _networkService.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Check network connectivity first
    final isConnected = await _networkService.checkConnectivity();

    if (!isConnected) {
      if (!mounted) return;
      displaySnackBar('Không có kết nối Internet', context, SnackBarType.error);
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      final result = await _adminAuthService.adminLogin(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;

      if (result == 'success') {
        // Show success message
        displaySnackBar('Đăng nhập thành công', context, SnackBarType.success);

        // Use GoRouter to navigate
        context.go('/dashboard');
      } else {
        // Show error message
        displaySnackBar(result, context, SnackBarType.error);
      }
    } catch (e) {
      if (!mounted) return;
      displaySnackBar(
        'Đã xảy ra lỗi, vui lòng thử lại sau.: $e',
        context,
        SnackBarType.error,
      );
      avoidPrint('Login error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NetworkStatusBanner(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: webBackgroundColor,
        body: SafeArea(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width / 3,
            ),
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset('assets/images/trevie.svg', height: 64),
                      Flexible(
                        child: Text(
                          'Trang Quản Trị',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: appPrimaryColor,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 32),
                      //text field input for email
                      TextFieldInput(
                        textEditingController: _emailController,
                        hintText: 'Nhập địa chỉ email của bạn',
                        textInputType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        labelText: 'Địa chỉ Email',
                      ),
                      const SizedBox(height: 24),
                      //text field input for password
                      TextFieldInput(
                        textEditingController: _passwordController,
                        hintText: 'Nhập mật khẩu của bạn',
                        textInputType: TextInputType.text,
                        isPass: true,
                        prefixIcon: Icons.lock_outline,
                        labelText: 'Mật khẩu',
                      ),
                      const SizedBox(height: 24),
                      CustomInkwell(
                        title: 'Đăng nhập',
                        onTap: _handleLogin,
                        isLoading: _isLoading,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
