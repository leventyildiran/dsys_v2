import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Kullanıcının özellikle istediği:
/// Sayfa açılırken ve form üzerinde zarifçe sağa-sola gidip gelen (salınan) 3'lü turkuaz nokta animasyonu.
class UcNoktaAnimasyon extends StatefulWidget {
  const UcNoktaAnimasyon({
    super.key,
    this.noktaRengi = const Color(0xFF22D3EE),
    this.noktaBoyutu = 9.0,
    this.aralik = 10.0,
  });

  final Color noktaRengi;
  final double noktaBoyutu;
  final double aralik;

  @override
  State<UcNoktaAnimasyon> createState() => _UcNoktaAnimasyonState();
}

class _UcNoktaAnimasyonState extends State<UcNoktaAnimasyon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true); // İki yöne gidip gelme efekti
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;

        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            // Dalga fazı: 0, 1 ve 2. noktalar sırayla dalgalanır
            final phase = (t * 2 * math.pi) - (index * (math.pi / 2.5));
            final sinVal = math.sin(phase);
            
            // Dikey zıplama ve hafif yatay salınım
            final offsetY = -sinVal.abs() * 5.0;
            // Opaklık ve boyut nabzı
            final scale = 0.8 + (sinVal.abs() * 0.4);
            final opacity = 0.35 + (sinVal.abs() * 0.65);

            return Container(
              margin: EdgeInsets.symmetric(horizontal: widget.aralik / 2),
              transform: Matrix4.translationValues(0, offsetY, 0),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity.clamp(0.2, 1.0),
                  child: Container(
                    width: widget.noktaBoyutu,
                    height: widget.noktaBoyutu,
                    decoration: BoxDecoration(
                      color: widget.noktaRengi,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.noktaRengi.withValues(alpha: 0.55),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
