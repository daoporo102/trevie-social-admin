import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:social_media_admin/utils/utils.dart';

class AdminManagementService {
  // Khai báo rõ vùng 'us-central1'
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Set admin claim for a user by email
  Future<String> setAdminClaim(String email) async {
    try {
      // Ensure client sends a fresh token that contains up-to-date custom claims
      await _auth.currentUser?.getIdToken(true);

      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('setAdminClaim');
      final result = await callable.call({'email': email});

      avoidPrint('Admin claim result: ${result.data}');
      return 'success';
    } on FirebaseFunctionsException catch (e) {
      avoidPrint('Functions error: ${e.code} - ${e.message}');

      switch (e.code) {
        case 'unauthenticated':
          return 'Bạn phải đăng nhập để thực hiện hành động này';
        case 'permission-denied':
          return 'Bạn không có quyền thực hiện hành động này';
        case 'invalid-argument':
          return 'Email không hợp lệ';
        default:
          return e.message ?? 'Đã xảy ra lỗi';
      }
    } catch (e) {
      avoidPrint('Unexpected error: $e');
      return 'Đã xảy ra lỗi không xác định';
    }
  }

  /// Remove admin claim from a user
  Future<String> removeAdminClaim(String email) async {
    try {
      // Ensure client sends a fresh token that contains up-to-date custom claims
      await _auth.currentUser?.getIdToken(true);

      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('removeAdminClaim');
      final result = await callable.call({'email': email});

      avoidPrint('Remove admin result: ${result.data}');
      return 'success';
    } on FirebaseFunctionsException catch (e) {
      avoidPrint('Functions error: ${e.code} - ${e.message}');
      return e.message ?? 'Đã xảy ra lỗi';
    } catch (e) {
      avoidPrint('Unexpected error: $e');
      return 'Đã xảy ra lỗi không xác định';
    }
  }

  /// Check if a user has admin status
  Future<Map<String, bool>> checkAdminStatus(String email) async {
    try {
      final callable = _functions.httpsCallable('checkAdminStatus');
      final result = await callable.call({'email': email});

      return {
        'isAdmin': result.data['isAdmin'] ?? false,
        'isSuperAdmin': result.data['isSuperAdmin'] ?? false,
      };
    } catch (e) {
      avoidPrint('Error checking admin status: $e');
      return {'isAdmin': false, 'isSuperAdmin': false};
    }
  }

  /// Force token refresh to get updated claims
  Future<void> refreshUserToken() async {
    try {
      await _auth.currentUser?.getIdToken(true);
    } catch (e) {
      avoidPrint('Error refreshing token: $e');
    }
  }
}
