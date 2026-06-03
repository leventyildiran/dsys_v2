import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance {
    _authSubscription = _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  final FirebaseAuth _auth;
  StreamSubscription<User?>? _authSubscription;

  User? _user;
  bool _isLoading = true;
  String? _errorMessage;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  void _onAuthStateChanged(User? user) {
    _user = user;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e);
      return false;
    } catch (e) {
      _errorMessage = 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e);
      return false;
    } catch (e) {
      _errorMessage = 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      _errorMessage = 'Çıkış yapılırken bir hata oluştu.';
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found': return 'Bu e-posta adresine ait bir hesap bulunamadı.';
      case 'wrong-password': return 'Girilen şifre hatalı.';
      case 'invalid-email': return 'Geçersiz e-posta adresi.';
      case 'user-disabled': return 'Bu hesap devre dışı bırakılmıştır. Yönetici ile iletişime geçin.';
      case 'email-already-in-use': return 'Bu e-posta adresi zaten kayıtlı.';
      case 'weak-password': return 'Şifre çok zayıf. Daha güçlü bir şifre belirleyin.';
      case 'too-many-requests': return 'Çok fazla başarısız deneme. Lütfen bir süre bekleyip tekrar deneyin.';
      case 'invalid-credential': return 'E-posta veya şifre hatalı.';
      case 'invalid-login-credentials': return 'E-posta veya şifre hatalı.';
      case 'operation-not-allowed': return 'E-posta ile giriş kapalı (Firebase ayarları).';
      case 'network-request-failed': return 'İnternet bağlantınızı kontrol edin.';
      default: return 'Giriş başarısız (Kod: ${e.code}). Lütfen tekrar deneyin.';
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
