import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/turkce_format.dart';
import '../../models/beyanname_belge_model.dart';
import '../../models/beyanname_denetim_rapor_model.dart';
import '../../providers/beyanname_provider.dart';
import '../../services/beyanname_denetim_servisi.dart';
import 'ai_denetim_rapor_dialog.dart';

/// Analiz tamamlandığında okunan mizan ve fatura verilerini tek bakışta gösteren,
/// tevkifat faturalarındaki VKN/tutarları anında düzeltmeye ve tek tıkla masalara aktarmaya
/// imkan tanıyan şeffaf özet paneli.
class OkunanVerilerOnizlemeKarti extends StatefulWidget {
  final BeyannameAjanRaporu rapor;
  final BeyannameProvider provider;

  const OkunanVerilerOnizlemeKarti({
    super.key,
    required this.rapor,
    required this.provider,
  });

  @override
  State<OkunanVerilerOnizlemeKarti> createState() => _OkunanVerilerOnizlemeKartiState();
}

class _OkunanVerilerOnizlemeKartiState extends State<OkunanVerilerOnizlemeKarti> {
  bool _daraltilmis = false;

  @override
  Widget build(BuildContext context) {
    final rapor = widget.rapor;
    final provider = widget.provider;
    final birimler = rapor.birimSonuclari.values.toList();
    if (birimler.isEmpty) return const SizedBox.shrink();

    // Tüm birimlerdeki tevkifat faturalarını topla
    final tevkifatListesi = <({String birimAdi, int index, Map<String, dynamic> fatura})>[];
    for (final b in birimler) {
      for (int i = 0; i < b.tevkifatFaturalari.length; i++) {
        tevkifatListesi.add((birimAdi: b.birimAdi, index: i, fatura: b.tevkifatFaturalari[i]));
      }
    }

    final uygulandi = rapor.uygulandiMi;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: rapor.kritikHataVarMi
              ? AppColors.danger.withAlpha(120)
              : AppColors.success.withAlpha(140),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Üst Başlık ve Hızlı Aktarım Barı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: rapor.kritikHataVarMi ? AppColors.dangerSubtle : AppColors.successSubtle,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(7),
                topRight: const Radius.circular(7),
                bottomLeft: _daraltilmis ? const Radius.circular(7) : Radius.zero,
                bottomRight: _daraltilmis ? const Radius.circular(7) : Radius.zero,
              ),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      rapor.kritikHataVarMi ? Icons.warning_amber_rounded : Icons.verified_rounded,
                      size: 18,
                      color: rapor.kritikHataVarMi ? AppColors.danger : AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      rapor.kritikHataVarMi
                          ? 'Okunan Veriler Konsolide Önizlemesi (${birimler.length} Birim · ${rapor.kritikHataSayisi} Kritik Uyarı)'
                          : 'Okunan Veriler Konsolide Önizlemesi (${birimler.length} Birim İncelendi)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: rapor.kritikHataVarMi ? AppColors.danger : AppColors.success,
                      ),
                    ),
                    if (uygulandi) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '✓ MASALARA AKTARILDI',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => AiDenetimRaporDialog.goster(
                        context,
                        rapor: rapor,
                        provider: provider,
                      ),
                      icon: const Icon(Icons.fact_check_outlined, size: 15),
                      label: Text(
                        'Konsolide Denetim Raporu (${rapor.denetimKontrolleri.length})',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      onPressed: () {
                        provider.aiAjanVerileriniUygula(rapor, uzerineEkle: false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✓ Mizan ve Fatura verileri KDV 1, KDV 2, Damga ve 600 Hasılat masalarına aktarıldı ve güncellendi!'),
                            backgroundColor: AppColors.success,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 15),
                      label: Text(
                        uygulandi ? 'Tüm Masaları Güncelle' : 'Tümünü Masalara Aktar',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: Icon(
                        _daraltilmis ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      tooltip: _daraltilmis ? 'Genişlet' : 'Daralt',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _daraltilmis = !_daraltilmis),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (!_daraltilmis) ...[
            // Mizan Özet Tablosu
            Builder(
              builder: (context) {
                final hasKdv1 = birimler.any((b) => b.hesaplananKdv1 > 0 || b.indirilecekKdv1 > 0);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: DataTable(
                    headingRowHeight: 30,
                    dataRowMinHeight: 32,
                    dataRowMaxHeight: 38,
                    columnSpacing: 14,
                    horizontalMargin: 8,
                    headingRowColor: WidgetStateProperty.all(AppColors.surfaceVariant),
                    columns: [
                      const DataColumn(label: Text('BİRİM', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                      const DataColumn(numeric: true, label: Text('600 AYLIK HASILAT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                      const DataColumn(numeric: true, label: Text('600 KÜMÜLATİF', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                      const DataColumn(numeric: true, label: Text('123 KREDİ KARTI', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                      if (hasKdv1)
                        const DataColumn(numeric: true, label: Text('391 KDV (%1)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                      const DataColumn(numeric: true, label: Text('391 KDV (%10)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                      const DataColumn(numeric: true, label: Text('391 KDV (%20)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                      if (hasKdv1)
                        const DataColumn(numeric: true, label: Text('191 İND. (%1)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                      const DataColumn(numeric: true, label: Text('191 İND. (%10)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                      const DataColumn(numeric: true, label: Text('191 İND. (%20)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                      const DataColumn(numeric: true, label: Text('360 DAMGA V.', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                      const DataColumn(numeric: true, label: Text('MUHTASAR GV', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                      const DataColumn(numeric: true, label: Text('MUHTASAR DV', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                      const DataColumn(numeric: true, label: Text('KDV 2 TEVKİFAT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                    ],
                    rows: birimler.map((BirimMizanAnalizSonucu b) {
                      final toplamTevkifat = b.tevkifatFaturalari.fold<double>(
                        0.0,
                        (sum, f) => sum + ((f['tevkifatTutari'] as num?)?.toDouble() ?? 0.0),
                      );
                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  b.birimAdi,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                if (b.yardimciMizanKullanildi) ...[
                                  const SizedBox(width: 4),
                                  Tooltip(
                                    message: b.aciklama ?? 'Yardımcı Defter (Muavin) incelendi ve arındırıldı',
                                    child: const Icon(Icons.verified_rounded, size: 14, color: AppColors.success),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          DataCell(_tutarText(b.hasilat600Aylik, highlight: true)),
                          DataCell(_tutarText(b.hasilat600Kumulatif)),
                          DataCell(_tutarText(b.krediKarti123)),
                          if (hasKdv1) DataCell(_tutarText(b.hesaplananKdv1)),
                          DataCell(_tutarText(b.hesaplananKdv10)),
                          DataCell(_tutarText(b.hesaplananKdv20)),
                          if (hasKdv1) DataCell(_tutarText(b.indirilecekKdv1)),
                          DataCell(_tutarText(b.indirilecekKdv10)),
                          DataCell(_tutarText(b.indirilecekKdv20)),
                          DataCell(_tutarText(b.damgaVergisi360)),
                          DataCell(_tutarText(b.muhtasarGelir360)),
                          DataCell(_tutarText(b.muhtasarDamga360)),
                          DataCell(
                            b.tevkifatFaturalari.isEmpty
                                ? const Text('-', style: TextStyle(fontSize: 11, color: AppColors.textMuted))
                                : Text(
                                    '${b.tevkifatFaturalari.length} Fatura (${TurkceFormat.para(toplamTevkifat)})',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.info),
                                  ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),

          // Tevkifat Faturaları Listesi (Varsa)
          if (tevkifatListesi.isNotEmpty) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, size: 15, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Okunan KDV 2 Tevkifat Faturaları (${tevkifatListesi.length} Adet) — VKN veya tutarı tıklayarak anında düzeltebilirsiniz:',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: tevkifatListesi.map((item) {
                      final f = item.fatura;
                      final firmaAdi = (f['firmaAdi'] ?? '').toString();
                      final vkn = (f['vergiTcNo'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
                      final oran = (f['tevkifatOrani'] ?? '9/10').toString();
                      final matrah = (f['matrahTutari'] as num?)?.toDouble() ?? 0.0;
                      final kdv = (f['kdvTutari'] as num?)?.toDouble() ?? 0.0;
                      final tevkifat = (f['tevkifatTutari'] as num?)?.toDouble() ?? 0.0;
                      final kdvOrani = (f['kdvOrani'] as num?)?.toInt() ??
                          ((matrah > 0 && kdv > 0 && ((kdv / matrah) * 100 - 10).abs() <= 2.5) ? 10 : 20);
                      final vknGecerli = (vkn.length == 10 && BeyannameDenetimServisi.dogrulaVkn(vkn)) ||
                          (vkn.length == 11 && BeyannameDenetimServisi.dogrulaTckn(vkn));

                      return InkWell(
                        onTap: () => _faturaDuzenleDialog(
                          context,
                          birimAdi: item.birimAdi,
                          faturaIndex: item.index,
                          fatura: f,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: vknGecerli ? AppColors.surfaceVariant : AppColors.dangerSubtle,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: vknGecerli ? AppColors.border : AppColors.danger,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                vknGecerli ? Icons.verified_rounded : Icons.error_outline_rounded,
                                size: 15,
                                color: vknGecerli ? AppColors.success : AppColors.danger,
                              ),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${item.birimAdi} · ${firmaAdi.isEmpty ? "İsimsiz Firma" : firmaAdi}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'VKN: ${vkn.isEmpty ? "EKSİK (Tıkla Gir)" : vkn} · KDV: %$kdvOrani · Oran: $oran · Matrah: ${TurkceFormat.para(matrah)} ₺ · Tevkifat: ${TurkceFormat.para(tevkifat)} ₺',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: vknGecerli ? FontWeight.normal : FontWeight.bold,
                                      color: vknGecerli ? AppColors.textSecondary : AppColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    ),
  );
  }

  Widget _tutarText(double val, {bool highlight = false}) {
    if (val.abs() < 0.01) {
      return const Text('-', style: TextStyle(fontSize: 11, color: AppColors.textMuted));
    }
    return Text(
      TurkceFormat.para(val),
      style: TextStyle(
        fontSize: 11,
        fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
        color: highlight ? AppColors.primary : AppColors.textPrimary,
      ),
    );
  }

  void _faturaDuzenleDialog(
    BuildContext context, {
    required String birimAdi,
    required int faturaIndex,
    required Map<String, dynamic> fatura,
  }) {
    final mevcutUnvan = (fatura['firmaAdi'] ?? '').toString();
    final mevcutVkn = (fatura['vergiTcNo'] ?? '').toString();
    final mevcutOran = (fatura['tevkifatOrani'] ?? '9/10').toString();
    final mevcutMatrah = (fatura['matrahTutari'] as num?)?.toDouble() ?? 0.0;
    final mevcutKdv = (fatura['kdvTutari'] as num?)?.toDouble() ?? 0.0;
    final mevcutTevkifat = (fatura['tevkifatTutari'] as num?)?.toDouble() ?? 0.0;
    final mevcutKdvOrani = (fatura['kdvOrani'] as num?)?.toInt() ??
        ((mevcutMatrah > 0 && mevcutKdv > 0 && ((mevcutKdv / mevcutMatrah) * 100 - 10).abs() <= 2.5) ? 10 : 20);

    final unvanCtrl = TextEditingController(text: mevcutUnvan);
    final vknCtrl = TextEditingController(text: mevcutVkn);
    final oranCtrl = TextEditingController(text: mevcutOran);
    final kdvOranCtrl = TextEditingController(text: mevcutKdvOrani.toString());
    final matrahCtrl = TextEditingController(text: mevcutMatrah.toStringAsFixed(2));
    final kdvCtrl = TextEditingController(text: mevcutKdv.toStringAsFixed(2));
    final tevkifatCtrl = TextEditingController(text: mevcutTevkifat.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            final girilenVkn = vknCtrl.text.replaceAll(RegExp(r'\D'), '');
            final isVknOk = (girilenVkn.length == 10 && BeyannameDenetimServisi.dogrulaVkn(girilenVkn)) ||
                (girilenVkn.length == 11 && BeyannameDenetimServisi.dogrulaTckn(girilenVkn));

            return AlertDialog(
              title: Text(
                '$birimAdi — Tevkifat Faturası Düzenle',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: unvanCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Satıcı Firma Ünvanı / Adı Soyadı',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: vknCtrl,
                      onChanged: (_) => setStateDialog(() {}),
                      decoration: InputDecoration(
                        labelText: 'Satıcı VKN (10 Hane) veya TCKN (11 Hane)',
                        isDense: true,
                        helperText: girilenVkn.isEmpty
                            ? 'Lütfen 10 haneli VKN veya 11 haneli TCKN giriniz'
                            : (isVknOk
                                ? '✓ GİB Algoritması Doğrulandı'
                                : '⚠ GİB Algoritmasına Göre Hatalı Numara'),
                        helperStyle: TextStyle(
                          color: isVknOk ? AppColors.success : AppColors.danger,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: oranCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Tevkifat Oranı (Örn: 9/10)',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: kdvOranCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'KDV Oranı (%10 / %20)',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: matrahCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'KDV Hariç Matrah (₺)',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: kdvCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Hesaplanan KDV (₺)',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: tevkifatCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Tevkif Edilen KDV 2 (₺)',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Vazgeç'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final yeniMatrah = double.tryParse(matrahCtrl.text.replaceAll(',', '.')) ?? mevcutMatrah;
                    final yeniKdv = double.tryParse(kdvCtrl.text.replaceAll(',', '.')) ?? mevcutKdv;
                    final yeniTevkifat = double.tryParse(tevkifatCtrl.text.replaceAll(',', '.')) ?? mevcutTevkifat;
                    final yeniKdvOrani = int.tryParse(kdvOranCtrl.text.replaceAll(RegExp(r'\D'), '')) ?? mevcutKdvOrani;
                    widget.provider.raporTevkifatFaturasiGuncelle(
                      birimAdi: birimAdi,
                      faturaIndex: faturaIndex,
                      yeniFatura: {
                        ...fatura,
                        'firmaAdi': unvanCtrl.text.trim(),
                        'vergiTcNo': vknCtrl.text.replaceAll(RegExp(r'\D'), ''),
                        'tevkifatOrani': oranCtrl.text.trim(),
                        'kdvOrani': yeniKdvOrani,
                        'matrahTutari': yeniMatrah,
                        'kdvTutari': yeniKdv,
                        'tevkifatTutari': yeniTevkifat,
                      },
                    );
                    Navigator.of(ctx).pop();
                  },
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Kaydet & Denetimi Yenile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
