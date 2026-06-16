import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/models/user_request_model.dart';
import '../../auth/models/user_model.dart';
import '../../auth/services/user_request_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Kayıt Ol')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'E‑posta'),
                validator: (v) => v == null || v.isEmpty ? 'Gerekli' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'İsim'),
                validator: (v) => v == null || v.isEmpty ? 'Gerekli' : null,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: const Text(
                  'Yeni kullanıcılar Birim Sekreteri rolü ile başlar. '
                  'Yetki yükseltme yalnızca yönetici onayı ile yapılır.',
                ),
              ),
              const SizedBox(height: 24),
              _isSubmitting
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () async {
                        if (!_formKey.currentState!.validate()) return;
                        final messenger = ScaffoldMessenger.of(context);
                        final router = GoRouter.of(context);
                        setState(() => _isSubmitting = true);
                        final requestService = UserRequestService();
                        if (!mounted) return;
                        await requestService.submitRequest(
                          UserRequestModel(
                            email: _emailCtrl.text.trim(),
                            name: _nameCtrl.text.trim(),
                            role: UserRole.birimSekreteri.value,
                          ),
                        );
                        if (!mounted) return;
                        await auth.signOut();
                        if (!mounted) return;
                        setState(() => _isSubmitting = false);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Kayıt talebiniz gönderildi, onay bekleniyor.',
                            ),
                          ),
                        );
                        router.go('/pending-approval');
                      },
                      child: const Text('Gönder'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
