import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:social_media_admin/utils/utils.dart';

class AdminAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Force refresh the authentication token to get updated custom claims
  Future<void> refreshUserToken() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.getIdToken(true); // Force refresh
        avoidPrint('Token refreshed successfully');
      }
    } catch (e) {
      avoidPrint('Error refreshing token: $e');
    }
  }

  /// Check if current user is admin (with forced token refresh)
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

  /// Check if current user is super admin (with forced token refresh)
  Future<bool> isSuperAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // Force refresh token to get latest claims
      final idTokenResult = await user.getIdTokenResult(true);
      return idTokenResult.claims?['superAdmin'] == true;
    } catch (e) {
      avoidPrint('Error checking super admin status: $e');
      return false;
    }
  }

  /// Admin login
  Future<String> adminLogin({
    required String email,
    required String password,
  }) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        return 'Vui lòng điền đầy đủ thông tin';
      }

      // Sign in user
      await _auth.signInWithEmailAndPassword(email: email, password: password);

      // Wait a bit for token to be available
      await Future.delayed(const Duration(milliseconds: 500));

      // Check if user has admin claim
      if (!await isAdmin()) {
        await _auth.signOut();
        return 'Tài khoản này không có quyền truy cập quản trị';
      }

      // Ensure user document exists in Firestore
      await ensureUserDocumentExists();

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

    final idTokenResult = await user.getIdTokenResult(true); // Force refresh

    return {
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'isAdmin': idTokenResult.claims?['admin'] == true,
      'isSuperAdmin': idTokenResult.claims?['superAdmin'] == true,
    };
  }

   /// Create user document in Firestore if it doesn't exist
  Future<String> ensureUserDocumentExists() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'Người dùng chưa đăng nhập';

      // Check if user document exists
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        // Create user document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'uid': user.uid,
          'email': user.email ?? '',
          'displayName': user.displayName ?? 'Admin',
          'photoUrl': user.photoURL ?? '',
          'bio': '',
          'dateOfBirth': null,
          'createdAt': Timestamp.now(),
          'followers': [],
          'following': [],
          'isSuspended': false,
          'suspendedAt': null,
          'isDeleted': false,
          'deletedAt': null,
          'deletionReason': null,
          'suspensionReason': null,
          'role': 'admin',
        });
        
        avoidPrint('Created user document for admin: ${user.email}');
        return 'success';
      }

      return 'success';
    } catch (e) {
      avoidPrint('Error ensuring user document: $e');
      return 'Đã xảy ra lỗi khi tạo tài liệu người dùng';
    }
  }
}
