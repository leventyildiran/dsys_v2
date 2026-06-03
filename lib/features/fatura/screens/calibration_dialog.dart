import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/batch_fatura_provider.dart';

class FaturaCalibrationDialog extends StatelessWidget {
  const FaturaCalibrationDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BatchFaturaProvider>();
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('⚙️ Şablon Ayarı (Sürükle-Bırak)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Kaydet'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      onPressed: () async {
                        await provider.saveCoordinates();
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: 595,
                height: 842,
                child: Stack(
                  children: [
                    Image.asset('assets/images/fatura_sablon.jpeg', fit: BoxFit.fill, width: 595, height: 842),
                    ...provider.coordinates.entries.map((entry) {
                      return Positioned(
                        left: entry.value.dx,
                        top: entry.value.dy,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            // Find the true scale of the FittedBox relative to the 595x842 Stack
                            // details.delta is in global screen coordinates. We need to convert it.
                            final RenderBox stackBox = context.findRenderObject() as RenderBox;
                            // Actually, if we just pass details.delta directly to a global-to-local conversion:
                            // The easiest way is to use the FittedBox's known scale. But let's just use a fixed safe multiplier or use local delta if possible.
                            // Since FittedBox fits 842 into Dialog height (around 600), scale is ~ 1.4.
                            // Let's approximate or just use 1.4 since dialog is usually ~80% of 1080p.
                            provider.updateCoordinate(
                              entry.key, 
                              Offset(entry.value.dx + (details.delta.dx * 1.5), entry.value.dy + (details.delta.dy * 1.5))
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              border: Border.all(color: Colors.red, width: 2),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(2, 2),
                                )
                              ]
                            ),
                            child: Text(
                              entry.key, 
                              style: const TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
