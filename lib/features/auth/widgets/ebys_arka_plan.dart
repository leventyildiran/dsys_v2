import 'dart:math' as math;
import 'package:flutter/material.dart';

/// DSYS v2 Kurumsal Giriş Arkaplanı:
/// EBYS'nin ferah ve prestijli dağ silüeti atmosferinden ilham alan,
/// Uşak Üniversitesi ve DSYS kurumsal kimliğine özgü vektörel dağ manzarası.
class EbysArkaPlan extends StatelessWidget {
  const EbysArkaPlan({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Vektörel Dağ Manzarası - Tepeden sarkan/inen dağlar
        Positioned.fill(
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationX(math.pi), // Dikey ters çevir (dağlar tepeden gelir)
            child: CustomPaint(
              painter: _DsysDaglariPainter(),
            ),
          ),
        ),
        // Giriş kartı ve arayüz elemanları
        Positioned.fill(
          child: child,
        ),
      ],
    );
  }
}

class _DsysDaglariPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Gökyüzü: Ferah, dingin gri-mavi atmosfer gradyanı
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFD6DFE8), // Yumuşak açık sis
          Color(0xFFBAC7D5), // Orta ufuk
          Color(0xFFA2B4C5), // Dağ ardı pus
        ],
        stops: [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    // 2. Arka Sıra Dağlar (Uzak ve sisli, açık petrol mavisi)
    final backMountainPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF6C8294),
          Color(0xFF4F6577),
        ],
      ).createShader(Rect.fromLTWH(0, h * 0.28, w, h * 0.72));

    final backPath = Path()
      ..moveTo(0, h * 0.56)
      ..lineTo(w * 0.12, h * 0.49)
      ..lineTo(w * 0.26, h * 0.54)
      ..lineTo(w * 0.40, h * 0.41)
      ..lineTo(w * 0.54, h * 0.48)
      ..lineTo(w * 0.72, h * 0.35) // Karakteristik sağ zirve
      ..lineTo(w * 0.84, h * 0.45)
      ..lineTo(w * 0.94, h * 0.40)
      ..lineTo(w, h * 0.45)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(backPath, backMountainPaint);

    // 3. Orta Sıra Dağlar (Alp mavisi ve derin okyanus tonu)
    final midMountainPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF2B4D63),
          Color(0xFF1B3547),
        ],
      ).createShader(Rect.fromLTWH(0, h * 0.36, w, h * 0.64));

    final midPath = Path()
      ..moveTo(0, h * 0.66)
      ..lineTo(w * 0.09, h * 0.60)
      ..lineTo(w * 0.22, h * 0.63)
      ..lineTo(w * 0.36, h * 0.53)
      ..lineTo(w * 0.49, h * 0.59)
      ..lineTo(w * 0.68, h * 0.48)
      ..lineTo(w * 0.75, h * 0.38) // Zirve noktası
      ..lineTo(w * 0.81, h * 0.47)
      ..lineTo(w * 0.88, h * 0.43)
      ..lineTo(w * 0.96, h * 0.55)
      ..lineTo(w, h * 0.52)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(midPath, midMountainPaint);

    // 4. Ön Sıra Dağlar (Derin lacivert / gece mavisi kurumsal gövde)
    final foreMountainPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF162B3A),
          Color(0xFF0C1924),
        ],
      ).createShader(Rect.fromLTWH(0, h * 0.52, w, h * 0.48));

    final forePath = Path()
      ..moveTo(0, h * 0.72)
      ..lineTo(w * 0.16, h * 0.59) // Sol ön tepe
      ..lineTo(w * 0.30, h * 0.73)
      ..lineTo(w * 0.42, h * 0.67)
      ..lineTo(w * 0.64, h * 0.76)
      ..lineTo(w * 0.80, h * 0.64)
      ..lineTo(w * 0.92, h * 0.71)
      ..lineTo(w, h * 0.66)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(forePath, foreMountainPaint);

    // 5. Alt Bölge Yumuşak Gradyanı
    final bottomGlow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          const Color(0xFF08121A).withValues(alpha: 0.75),
        ],
      ).createShader(Rect.fromLTWH(0, h * 0.78, w, h * 0.22));

    canvas.drawRect(Rect.fromLTWH(0, h * 0.78, w, h * 0.22), bottomGlow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
