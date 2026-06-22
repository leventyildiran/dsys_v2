import 'package:flutter/material.dart';

import '../models/danismanlik_model.dart';
import '../models/taksit_model.dart';

/// Danışmanlık modülü — YK ile uyumlu altın oran düzeni.
/// Ana içerik ≈ %76.4 (1 − 0.236), özet panel ≈ %23.6.
class DanismanlikLayout {
  DanismanlikLayout._();

  static const double sidebarOran = 0.28;
  static const double sidebarMin = 320;
  static const double sidebarMax = 600;

  static const double sayfaPadding = 16;
  static const double kartPadding = 16;
  static const double sectionGap = 12;

  static double sidebarGenislik(double maxWidth) =>
      (maxWidth * sidebarOran).clamp(sidebarMin, sidebarMax);

  /// Ana + yan panel satırı (sidebar sağda).
  static Widget ikiKolon({
    required Widget ana,
    required Widget yan,
    required double genislik,
    EdgeInsets? padding,
  }) {
    final sw = sidebarGenislik(genislik);
    return Padding(
      padding: padding ?? const EdgeInsets.all(sayfaPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: ana),
          const SizedBox(width: sectionGap),
          SizedBox(width: sw, child: yan),
        ],
      ),
    );
  }

  static Widget kompaktBaslik({
    required String baslik,
    String? altBaslik,
    Widget? aksiyon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.blueGrey.shade100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baslik,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.blueGrey.shade900,
                    letterSpacing: -0.3,
                  ),
                ),
                if (altBaslik != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    altBaslik,
                    style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade500),
                  ),
                ],
              ],
            ),
          ),
          if (aksiyon != null) aksiyon,
        ],
      ),
    );
  }

  static BoxDecoration kart({Color? arkaPlan}) => BoxDecoration(
        color: arkaPlan ?? Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blueGrey.shade100),
      );

  static Widget kartBaslik(String metin, {IconData? icon, Color? renk}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: renk ?? Colors.blueGrey.shade600),
          const SizedBox(width: 6),
        ],
        Text(
          metin,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: renk ?? Colors.blueGrey.shade700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

/// Dağıtım ekranına model + opsiyonel taksit taşır.
class DanismanlikRouteExtra {
  const DanismanlikRouteExtra({required this.model, this.taksit});

  final DanismanlikModel model;
  final TaksitModel? taksit;
}
