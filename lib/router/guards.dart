import 'package:flutter/material.dart';
import '../features/auth/providers/auth_provider.dart';

/// Guard to allow only admin users to access a route.
class AdminGuard {
  final AuthProvider auth;
  const AdminGuard(this.auth);

  /// Returns true if the current user has admin role.
  bool canActivate() => auth.isAdmin;
}

/// Guard to allow editors (admin or editor roles) to access a route.
class EditorGuard {
  final AuthProvider auth;
  const EditorGuard(this.auth);

  bool canActivate() => auth.isAdmin || auth.isEditor;
}
