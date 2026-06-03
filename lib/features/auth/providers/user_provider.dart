import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../../../core/services/firestore_service.dart';
import '../services/user_service.dart';
import 'auth_provider.dart';

class UserProvider extends ChangeNotifier {
  UserProvider({
    required AuthProvider authProvider,
    UserService? userService,
  })  : _authProvider = authProvider,
        _userService = userService ?? UserService() {
    _authProvider.addListener(_onAuthChanged);
    if (_authProvider.isAuthenticated) {
      _loadUserProfile();
    }
  }

  final AuthProvider _authProvider;
  final UserService _userService;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  UserRole? get currentRole => _currentUser?.role;
  bool get hasGlobalAccess => _currentUser?.role.isGlobal ?? false;
  String? get currentBirimId => _currentUser?.birimId;

  void _onAuthChanged() {
    if (_authProvider.isAuthenticated) {
      _loadUserProfile();
    } else {
      _currentUser = null;
      notifyListeners();
    }
  }

  Future<void> _loadUserProfile() async {
    final uid = _authProvider.user?.uid;
    if (uid == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _userService.getUser(uid);
      if (_currentUser == null) {
        _errorMessage = 'Kullanıcı profili bulunamadı. Yönetici ile iletişime geçin.';
      } else {
        final uniId = _currentUser!.universiteId;
        if (uniId != null && uniId.isNotEmpty) {
          FirestoreService.activeUniversiteId = uniId;
        }
      }
    } catch (e) {
      _errorMessage = 'Profil yüklenirken hata oluştu.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await _loadUserProfile();
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }
}
