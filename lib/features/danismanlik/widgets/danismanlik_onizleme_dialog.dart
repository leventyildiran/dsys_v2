import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/dagitim_model.dart';
import '../models/danismanlik_model.dart';
import '../models/taksit_model.dart';
import '../services/danismanlik_belge_servisi.dart';

/// Danışmanlık dağıtım tablosunu A4 oranında popup içinde önizler; yazdırma ve paylaşım destekler.
Future<void> showDanismanlikOnizlemeDialog(
  BuildContext context, {
  required DanismanlikModel danismanlik,
  required DagitimHesapSonuc sonuc,
  TaksitModel? taksit,
}) {
  final baslik = danismanlik.firmaUnvan ?? danismanlik.konusu;
  final taksitEtiket = taksit != null ? ' · Ay ${taksit.ayNo}' : '';

  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxH = MediaQuery.of(ctx).size.height * 0.92;
          // A4 dikey oranı: 1 : 1.414
          final govdeH = maxH - 56;
          final a4W = govdeH / 1.4142;
          final govdeW = a4W.clamp(480.0, MediaQuery.of(ctx).size.width * 0.94);

          return SizedBox(
            width: govdeW,
            height: maxH,
            child: Column(
              children: [
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf_outlined, size: 20, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Dağıtım Önizleme — $baslik$taksitEtiket',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Kapat',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PdfPreview(
                    build: (_) => DanismanlikBelgeServisi.dagitimPdfUret(
                      danismanlik: danismanlik,
                      sonuc: sonuc,
                      taksit: taksit,
                    ),
                    allowSharing: true,
                    allowPrinting: true,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    maxPageWidth: govdeW - 32,
                    pdfFileName: 'danismanlik_dagitim_${danismanlik.id}.pdf',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
