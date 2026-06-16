import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    // If already approved, redirect to home
    if (auth.canAccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/');
      });
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Onay Bekleniyor')),
      body: const Center(
        child: Text(
          'Kayıt talebiniz admin onayı bekliyor.\nLütfen bekleyiniz.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
