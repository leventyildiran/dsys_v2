import 'package:flutter/material.dart';

import '../widgets/ebys_arka_plan.dart';
import '../widgets/ebys_giris_karti.dart';

/// DSYS v2 Kurumsal Giriş Ekranı.
/// Ferah dağ manzaralı arka plan, animasyonlu 3'lü nokta göstergesi
/// ve kurumsal giriş kartı içerir.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EbysArkaPlan(
        child: SafeArea(
          child: Column(
            children: [
              // Üst Bilgi / Dil Çubuğu
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Sol: Dil Seçimi (Türkçe)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.language, size: 16, color: Color(0xFF334155)),
                          SizedBox(width: 6),
                          Text(
                            'Türkçe',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),

                    // Sağ: DSYS v2 Sistem Etiketi
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, size: 15, color: Color(0xFF0284C7)),
                          SizedBox(width: 6),
                          Text(
                            'DSYS v2 Güvenli Giriş',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Ortalanmış Giriş Kartı
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: const EbysGirisKarti(),
                  ),
                ),
              ),

              // Alt Telif ve Sürüm Bilgisi
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '© ${DateTime.now().year} Uşak Üniversitesi Döner Sermaye İşletme Müdürlüğü',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
