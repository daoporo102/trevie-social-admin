import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:social_media_admin/models/user.dart' as model;
import 'package:social_media_admin/resources/auth_methods.dart';

class UserProvider with ChangeNotifier {
  model.User? _user;
  final AuthMethods _authMethod = AuthMethods();

  UserProvider() {
    FirebaseAuth.instance.authStateChanges().listen((firebaseUser) {
      if (firebaseUser == null) {
        _user = null;
        notifyListeners();
      } else {
        refreshUser();
      }
    });
  }

  // Getter that can return null if user is not loaded
  model.User? get getUserrOrNull => _user;

  Future<void> refreshUser() async {
    model.User user = await _authMethod.getUserDetails();
    _user = user;
    notifyListeners();
  }
}