import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> signInWithGoogle() async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _authService.signInWithGoogle();
      if (result == null) {
        _setError('Sign-in was cancelled.');
      }
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e));
    } on SocketException catch (_) {
      _setError('No internet connection. Please check your network.');
    } catch (e) {
      _setError('Something went wrong. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authService.signOut();
    } catch (_) {
      _setError('Failed to sign out. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  void clearError() => _clearError();

  // ── Private Helpers ──

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      case 'invalid-credential':
        return 'Invalid credentials. Please try again.';
      case 'operation-not-allowed':
        return 'Google sign-in is not enabled. Contact support.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
