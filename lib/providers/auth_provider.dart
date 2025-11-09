import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _service = AuthService();
  final FirestoreService _firestore = FirestoreService();
  User? user;

  bool get isSignedIn => user != null && (user?.emailVerified ?? false);
  bool get isSignedInButUnverified =>
      user != null && !(user?.emailVerified ?? false);

  AuthProvider() {
    _service.userChanges.listen((u) {
      user = u;
      notifyListeners();
    });
  }

  Future<void> reloadUser() async {
    await user?.reload();
    user = _service.currentUser;
    notifyListeners();
  }

  Future<void> signUp(String email, String password, String name) async {
    final credential = await _service.signUp(email, password);
    if (credential.user != null) {
      // Save user profile to Firestore (name, email, verified, lastLogin)
      final u = credential.user!;
      final lastLogin = u.metadata.lastSignInTime ?? DateTime.now();
      await _firestore.saveUserName(u.uid,
          name: name,
          email: u.email,
          verified: u.emailVerified,
          lastLogin: lastLogin);
      // Send verification email
      await credential.user?.sendEmailVerification();
      // Reload user to get updated state
      await credential.user?.reload();
      user = credential.user;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    await _service.signIn(email, password);
    // Update Firestore user doc with latest email verification and last login
    final u = _service.currentUser;
    if (u != null) {
      final lastLogin = u.metadata.lastSignInTime ?? DateTime.now();
      await _firestore.saveUserName(u.uid,
          // don't overwrite name here; only update email/verified/lastLogin
          email: u.email,
          verified: u.emailVerified,
          lastLogin: lastLogin);
      user = u;
      notifyListeners();
    }
  }

  Future<void> resendVerificationEmail() async {
    await _service.resendVerificationEmail();
  }

  Future<void> signOut() async {
    await _service.signOut();
  }
}
