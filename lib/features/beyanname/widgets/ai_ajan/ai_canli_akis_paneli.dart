import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/beyanname_provider.dart';

/// Analiz sırasında adım adım bilgilendirme akışını ve terminal konsolunu
/// gösteren canlı ilerleme paneli.
class AiCanliAkisPaneli extends StatefulWidget {
  final BeyannameProvider provider;

  const AiCanliAkisPaneli({super.key, required this.provider});

  @override
  State<AiCanliAkisPaneli> createState() => _AiCanliAkisPaneliState();
}

class _AiCanliAkisPaneliState extends State<AiCanliAkisPaneli> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant AiCanliAkisPaneli oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Yeni log geldikçe otomatik en alta kaydır
    if (widget.provider.aiAjanLoglari.length != oldWidget.provider.aiAjanLoglari.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final loglar = provider.aiAjanLoglari;
    final ilerleme = provider.aiAjanIlerleme.clamp(0.0, 1.0);
    final yuzde = (ilerleme * 100).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Terminal koyu lacivert zemin
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Konsol Üst Çubuğu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(9),
                topRight: Radius.circular(9),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF38BDF8),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '🤖 AKILLI BEYANNAME AJANI — CANLI İŞLEM VE OKUMA AKIŞI',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF1F5F9),
                    ),
                  ),
                ),
                Text(
                  '%$yuzde',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF38BDF8),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 24,
                  child: OutlinedButton.icon(
                    onPressed: () => provider.aiAjanDurdur(),
                    icon: const Icon(Icons.stop_circle_rounded, size: 14, color: AppColors.danger),
                    label: const Text(
                      'Durdur',
                      style: TextStyle(fontSize: 10, color: AppColors.danger, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.danger),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // İlerleme Çubuğu
          LinearProgressIndicator(
            value: ilerleme,
            backgroundColor: const Color(0xFF334155),
            color: const Color(0xFF0284C7),
            minHeight: 3,
          ),

          // Log Akış Terminali
          Container(
            height: 180,
            padding: const EdgeInsets.all(12),
            child: loglar.isEmpty
                ? const Center(
                    child: Text(
                      'Bağlantı kuruluyor...',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: loglar.length,
                    itemBuilder: (context, index) {
                      final l = loglar[index];
                      Color textColor = const Color(0xFFE2E8F0);
                      if (l.isHata) textColor = const Color(0xFFF87171);
                      if (l.isBasarili) textColor = const Color(0xFF4ADE80);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '[${l.formatliZaman}] ',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                l.mesaj,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                  color: textColor,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
