import 'package:firebase_auth/firebase_auth.dart';
import 'package:social_media_admin/utils/utils.dart';

class AdminAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Check if current user is admin
  Future<bool> isAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // Force refresh token to get latest claims
      final idTokenResult = await user.getIdTokenResult(true);
      return idTokenResult.claims?['admin'] == true;
    } catch (e) {
      avoidPrint('Error checking admin status: $e');
      return false;
    }
  }
  
  /// Admin login
  Future<String> adminLogin({required String email, required String password}) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        return 'Vui lòng điền đầy đủ thông tin';
      }

      // Sign in user
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Wait a bit for token to be available
      await Future.delayed(const Duration(milliseconds: 500));

      // Check if user has admin claim
      if (!await isAdmin()) {
        await _auth.signOut();
        return 'Tài khoản này không có quyền truy cập quản trị';
      }

      return 'success';
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'Không tìm thấy tài khoản';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email hoặc mật khẩu không đúng';
        case 'invalid-email':
          return 'Địa chỉ email không hợp lệ';
        case 'user-disabled':
          return 'Tài khoản đã bị vô hiệu hóa';
        case 'too-many-requests':
          return 'Quá nhiều lần thử. Vui lòng thử lại sau';
        case 'network-request-failed':
          return 'Lỗi kết nối mạng';
        default:
          avoidPrint('Login error: ${e.code} - ${e.message}');
          return 'Đã xảy ra lỗi: ${e.message}';
      }
    } catch (e) {
      avoidPrint('Unexpected login error: $e');
      return 'Đã xảy ra lỗi không xác định';
    }
  }

  /// Admin logout
  Future<void> adminLogout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      avoidPrint('Logout error: $e');
      rethrow;
    }
  }

  /// Get admin user info
  Future<Map<String, dynamic>?> getAdminInfo() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final idTokenResult = await user.getIdTokenResult();

    return {
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'isAdmin': idTokenResult.claims?['admin'] == true,
      'isSuperAdmin': idTokenResult.claims?['superAdmin'] == true,
    };
  }
}