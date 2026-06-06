import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/batch_fatura_provider.dart';

class FaturaCalibrationDialog extends StatefulWidget {
  const FaturaCalibrationDialog({super.key});

  @override
  State<FaturaCalibrationDialog> createState() => _FaturaCalibrationDialogState();
}

class _FaturaCalibrationDialogState extends State<FaturaCalibrationDialog> {
  final GlobalKey _stackKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BatchFaturaProvider>();
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.95,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('⚙️ Şablon Ayarı (Sabit Büyük A4)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('Kaydet'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);
                          
                          await provider.saveCoordinates();
                          
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Kalibrasyon ayarları başarıyla kaydedildi!'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                          
                          navigator.pop();
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.blue), 
                        tooltip: 'Fabrika Ayarlarına Dön',
                        onPressed: () async {
                          await provider.resetCoordinates();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tüm etiketler varsayılan yerlerine sıfırlandı!'),
                                backgroundColor: Colors.blue,
                              ),
                            );
                          }
                        }
                      ),
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Text(
                'İpucu: Fatura tamamen sabittir ve A4 boyutunda dev gibi açılır. Gerekirse sağ ve alt kaydırma çubuklarıyla faturayı kaydırın, yazıları sürükleyip bırakın.',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                color: Colors.grey.shade300,
                width: double.infinity,
                child: InteractiveViewer(
                  constrained: false,
                  scaleEnabled: false,
                  boundaryMargin: const EdgeInsets.all(50),
                  child: Container(
                    width: 595,
                    height: 842,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ]
                    ),
                    child: Stack(
                      key: _stackKey,
                      clipBehavior: Clip.none,
                      children: [
                        Image.asset('assets/images/fatura_sablon.jpeg', fit: BoxFit.fill, width: 595, height: 842),
                        ...provider.coordinates.entries.where((entry) {
                          if (!provider.isNakliYekunAktif && entry.key.startsWith('nakliYekun')) {
                            return false;
                          }
                          return true;
                        }).map((entry) {
                          return Positioned(
                            left: entry.value.dx,
                            top: entry.value.dy,
                            child: GestureDetector(
                              onPanUpdate: (details) {
                                final RenderBox stackBox = _stackKey.currentContext!.findRenderObject() as RenderBox;
                                final Offset localCurrent = stackBox.globalToLocal(details.globalPosition);
                                final Offset localPrevious = stackBox.globalToLocal(details.globalPosition - details.delta);
                                final Offset localDelta = localCurrent - localPrevious;
                                
                                provider.updateCoordinate(
                                  entry.key, 
                                  entry.value + localDelta
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
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
