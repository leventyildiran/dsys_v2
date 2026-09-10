import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import 'uc_nokta_animasyon.dart';

/// DSYS v2 Kurumsal Giriş Kartı:
/// EBYS tasarım dilinin ferahlığından ilham alan, fakat DSYS v2 ve Uşak Üniversitesi
/// kurumsal kimliğine özel olarak tasarlanmış modern giriş modülü.
class EbysGirisKarti extends StatefulWidget {
  const EbysGirisKarti({super.key});

  @override
  State<EbysGirisKarti> createState() => _EbysGirisKartiState();
}

class _EbysGirisKartiState extends State<EbysGirisKarti> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _beniHatirla = true;
  String? _hataMesaji;

  static const String _prefKeyHatirla = 'dsys_beni_hatirla';
  static const String _prefKeyKullanici = 'dsys_hatirlanan_kullanici';

  @override
  void initState() {
    super.initState();
    _hatirlananBilgileriYukle();
  }

  Future<void> _hatirlananBilgileriYukle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hatirla = prefs.getBool(_prefKeyHatirla) ?? true;
      final kullanici = prefs.getString(_prefKeyKullanici) ?? '';
      if (mounted) {
        setState(() {
          _beniHatirla = hatirla;
          if (hatirla && kullanici.isNotEmpty) {
            _usernameController.text = kullanici;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _hatirlananBilgileriKaydet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyHatirla, _beniHatirla);
      if (_beniHatirla) {
        await prefs.setString(_prefKeyKullanici, _usernameController.text.trim());
      } else {
        await prefs.remove(_prefKeyKullanici);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _girisYap() async {
    setState(() => _hataMesaji = null);
    if (!_formKey.currentState!.validate()) return;

    final rawUsername = _usernameController.text.trim();
    // Kullanıcı adında @ yoksa otomatik olarak kurumsal uzantı ekle
    final email = rawUsername.contains('@') ? rawUsername : '$rawUsername@usak.edu.tr';

    final authProvider = context.read<AuthProvider>();
    authProvider.clearError();

    final success = await authProvider.signInWithEmailAndPassword(
      email: email,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      await _hatirlananBilgileriKaydet();
    } else {
      setState(() {
        _hataMesaji = authProvider.errorMessage ??
            'Girdiğiniz kullanıcı ismi ve/veya şifre hatalı. Lütfen tekrar deneyiniz.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.08),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 34),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Logo ve Başlık Alanı
            Center(
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Kurumsal Başlık
            const Text(
              'UŞAK ÜNİVERSİTESİ',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.2,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'DÖNER SERMAYE\nYÖNETİM SİSTEMİ',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                height: 1.25,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 20),

            // 4. Kullanıcı İsmi / E-posta
            TextFormField(
              controller: _usernameController,
              focusNode: _usernameFocusNode,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                labelText: 'Kullanıcı İsmi',
                hintText: 'ad.soyad veya e-posta',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.person_outline, size: 20, color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.8),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Kullanıcı ismi gereklidir.';
                return null;
              },
              onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
            ),
            const SizedBox(height: 14),

            // 5. Şifre
            TextFormField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                labelText: 'Şifre',
                prefixIcon: const Icon(Icons.key_outlined, size: 20, color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 19,
                    color: const Color(0xFF64748B),
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.8),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Şifre gereklidir.';
                if (v.length < 6) return 'Şifre en az 6 karakter olmalıdır.';
                return null;
              },
              onFieldSubmitted: (_) => _girisYap(),
            ),
            const SizedBox(height: 10),

            // 6. Beni Hatırla
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _beniHatirla,
                    activeColor: const Color(0xFF0284C7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (v) => setState(() => _beniHatirla = v ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _beniHatirla = !_beniHatirla),
                  child: const Text(
                    'Beni Hatırla',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),

            // 7. Hata Mesajı (EBYS görselindeki gibi kırmızı stil)
            if (_hataMesaji != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, size: 17, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _hataMesaji!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFB91C1C),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 22),

            // 8. Giriş Yap Butonu (Koyu lacivert EBYS butonu)
            Selector<AuthProvider, bool>(
              selector: (_, p) => p.isLoading,
              builder: (context, isLoading, child) {
                return SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF162A45),
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isLoading ? null : _girisYap,
                    child: isLoading
                        ? const UcNoktaAnimasyon(
                            noktaRengi: Colors.white,
                            noktaBoyutu: 7.0,
                            aralik: 6.0,
                          )
                        : const Text(
                            'Giriş',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
