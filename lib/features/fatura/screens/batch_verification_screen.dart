import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/turkce_format.dart';
import '../models/fatura_model.dart';
import '../providers/batch_fatura_provider.dart';
import 'calibration_dialog.dart';
import 'fatura_arsiv_arama_dialog.dart';
import '../components/firma_secici_dialog.dart';
import '../components/hizmet_secici_dialog.dart';
import '../../../core/models/firma_model.dart';
import '../../../core/models/hizmet_model.dart';

class BatchVerificationScreen extends StatefulWidget {
  const BatchVerificationScreen({super.key});

  @override
  State<BatchVerificationScreen> createState() =>
      _BatchVerificationScreenState();
}

class _BatchVerificationScreenState extends State<BatchVerificationScreen> {
  final Set<int> _expandedCards = {0};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _kontrolYilBasiArsiv();
      _bildirGeriYuklenenKuyruk();
    });
  }

  Future<void> _bildirGeriYuklenenKuyruk() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final adet = context
        .read<BatchFaturaProvider>()
        .consumeGeriYuklemeBildirimi();
    if (adet == null || adet <= 0) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Önceki oturumdan $adet fatura taslağı geri yüklendi.'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _kontrolYilBasiArsiv() async {
    if (!mounted) return;
    final provider = context.read<BatchFaturaProvider>();
    await provider.yukleArsivDurumu();
    if (!mounted) return;
    if (!await provider.yilBasiTemizlikDialoguGosterilmeli()) return;
    if (!mounted) return;
    _showYilBasiTemizlikDialog(provider);
  }

  Future<void> _showYilBasiTemizlikDialog(BatchFaturaProvider provider) async {
    final uyarisi = provider.arsivUyarisi;
    if (uyarisi == null || !uyarisi.gosterilmeli) return;

    final yilListesi = uyarisi.eskiYillar
        .map((y) => '• ${y.yil}: ${y.adet} fatura')
        .join('\n');

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.archive_outlined,
          color: Colors.orange.shade700,
          size: 36,
        ),
        title: const Text('Geçici arşiv temizliği'),
        content: Text(
          'Yeni yıl başladı. Geçici Firestore arşivinde önceki yıllara ait '
          '${uyarisi.toplamEskiKayit} fatura kaydı var.\n\n'
          'Silmeden önce arşivi bilgisayarınıza indirmeniz önerilir '
          '(ZIP: JSON + Excel CSV).\n\n$yilListesi',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await provider.yilBasiUyarisiErtele();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Daha sonra'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.indigo.shade700,
            ),
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Sadece indir'),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                final adet = await provider.indirEskiArsivZip();
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('$adet fatura ZIP olarak indirildi.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
            ),
            icon: const Icon(Icons.download_done, size: 18),
            label: const Text('İndir ve sil'),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final onay = await showDialog<bool>(
                context: ctx,
                builder: (confirmCtx) => AlertDialog(
                  icon: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red.shade700,
                  ),
                  title: const Text('Arşivi silmek istediğinize emin misiniz?'),
                  content: const Text(
                    'Önce ZIP indirilecek, ardından eski yıllara ait geçici arşiv '
                    'Firestore\'dan kalıcı olarak silinecek. Bu işlem geri alınamaz.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(confirmCtx, false),
                      child: const Text('Vazgeç'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                      ),
                      onPressed: () => Navigator.pop(confirmCtx, true),
                      child: const Text('İndir ve sil'),
                    ),
                  ],
                ),
              );
              if (!ctx.mounted) return;
              if (onay != true) return;
              Navigator.pop(ctx);
              try {
                final sonuc = await provider.indirVeSilEskiArsiv();
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      '${sonuc.indirilen} fatura indirildi, '
                      '${sonuc.silinen} kayıt Firestore\'dan silindi.',
                    ),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 5),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Hata: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BatchFaturaProvider>();
    final gercekKuyruk = provider.pendingInvoices
        .where((f) => !BatchFaturaProvider.yerTutucuMu(f))
        .length;

    final formGoster = provider.pendingInvoices.any(
      (f) => !BatchFaturaProvider.yerTutucuMu(f),
    );

    return Container(
      color: AppTheme.backgroundColor,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildMatbuBanner(provider),
          const SizedBox(height: 16),
          _buildUploadBar(context, provider),
          const SizedBox(height: 16),
          _buildToolbar(context, provider, gercekKuyruk),
          const SizedBox(height: 12),
          if (!formGoster)
            _buildEmptyState(context, provider)
          else
            ...provider.pendingInvoices
                .asMap()
                .entries
                .where((e) => !BatchFaturaProvider.yerTutucuMu(e.value))
                .map(
                  (e) => _buildInvoiceCard(context, provider, e.value, e.key),
                ),
        ],
      ),
    );
  }

  Widget _buildMatbuBanner(BatchFaturaProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade800, Colors.indigo.shade600],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.receipt_long,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Matbu Fatura Doldurma',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Matbu A4 kağıdı yazıcıya takın. Sistem yalnızca boş alanlara metin basar — çizgi ve başlıklar kağıtta zaten var.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Matbu mod',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Switch(
                    value: provider.matbuBaskiModu,
                    activeThumbColor: Colors.lightGreenAccent,
                    onChanged: (v) {
                      provider.setMatbuBaskiModu(v);
                      provider.saveMatbuAyarlari();
                    },
                  ),
                ],
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Kalibrasyon'),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const FaturaCalibrationDialog(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadBar(BuildContext context, BatchFaturaProvider provider) {
    final tiles = [
      _uploadTile(
        icon: Icons.upload_file_rounded,
        title: 'Evrak Yükle',
        subtitle: 'PDF, Excel, CSV veya TXT dosyası seç',
        color: Colors.indigo,
        onTap: () => _uploadFaturaDocument(context, provider),
      ),
      _uploadTile(
        icon: Icons.table_view_rounded,
        title: 'Excel / Toplu Liste',
        subtitle: 'Sadece Excel veya CSV dosyası',
        color: Colors.green.shade700,
        onTap: () => _uploadExcel(context, provider),
      ),
      _uploadTile(
        icon: Icons.edit_note,
        title: 'Manuel Fatura',
        subtitle: 'Boş fatura ekle, elle doldur',
        color: Colors.blueGrey.shade700,
        onTap: () {
          provider.addBlankInvoice();
          setState(() {
            _expandedCards
              ..clear()
              ..add(provider.pendingInvoices.length - 1);
          });
        },
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                tiles[i],
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: tiles[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _uploadTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color,
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    BatchFaturaProvider provider,
    int count,
  ) {
    return Row(
      children: [
        Text(
          'Kuyruk: $count fatura',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const Spacer(),
        FilterChip(
          label: const Text('Nakli yekün'),
          selected: provider.isNakliYekunAktif,
          onSelected: provider.toggleNakliYekunGlobal,
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          key: const ValueKey('fatura_arsiv_dialog_ac'),
          icon: const Icon(Icons.search, size: 18),
          label: const Text('Fatura Arşivi'),
          onPressed: () => showFaturaArsivAramaDialog(context),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          icon: const Icon(Icons.upload_file, size: 18),
          label: const Text('Evrak Yükle'),
          onPressed: () => _uploadFaturaDocument(context, provider),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.content_paste, size: 18),
          label: const Text('Metin Yapıştır'),
          onPressed: () => _showRawTextDialog(context, provider),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          key: const ValueKey('fatura_tumunu_onayla'),
          icon: const Icon(Icons.done_all, size: 18),
          label: const Text('Tümünü Onayla'),
          style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
          onPressed: () => _approveAll(context, provider),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, BatchFaturaProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.upload_file, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'Başlamak için PDF, Excel, CSV veya TXT dosyası yükleyin\nveya Manuel Fatura kartına tıklayın',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Dosya Seç'),
            onPressed: () => _uploadFaturaDocument(context, provider),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _showRawTextDialog(context, provider),
            child: const Text('Metin yapıştırmak istiyorum'),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(
    BuildContext context,
    BatchFaturaProvider provider,
    FaturaModel invoice,
    int index,
  ) {
    final eksik = provider.eksikAlanlarForInvoice(invoice);
    final hazir = eksik.isEmpty;
    final expanded = _expandedCards.contains(index);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              if (expanded) {
                _expandedCards.remove(index);
              } else {
                _expandedCards.add(index);
              }
            }),
            child: Container(
              color: hazir ? Colors.green.shade50 : Colors.orange.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: hazir ? Colors.green : Colors.orange,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.firmaAdi.isEmpty
                              ? 'Firma adı girilmedi'
                              : invoice.firmaAdi,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${invoice.numuneNo.isEmpty ? "Numune yok" : "N: ${invoice.numuneNo}"} · '
                          '${TurkceFormat.para(invoice.genelToplam)} · ${invoice.parsedBy}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!hazir)
                    Tooltip(
                      message: eksik.join(', '),
                      child: Chip(
                        label: Text(
                          '${eksik.length} eksik',
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor: Colors.orange.shade100,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _buildFormBody(context, provider, invoice, index),
            ),
            _buildActions(context, provider, invoice, index, hazir),
          ],
        ],
      ),
    );
  }

  Widget _buildFormBody(
    BuildContext context,
    BatchFaturaProvider provider,
    FaturaModel invoice,
    int index,
  ) {
    // dialogUpdateCounter: firma veya birim seçiciden dönerken artar.
    // Bu sayede IBAN/HesapAdı alanları yeniden kurulur (initialValue güncellenir).
    // Kullanıcı yazarken counter değişmediğinden odak kaybı OLMAZ.
    final dialogCounter = provider.dialogUpdateCounter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.business, size: 18),
              label: const Text('Kayıtlı Firma'),
              onPressed: () => _showFirmaSecici(context, provider, index),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey(
                  'birim_${index}_${provider.seciliBirimFor(index)}',
                ),
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Birim (IBAN otomatik)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  suffixIcon: (invoice.iban?.trim().isNotEmpty == true)
                      ? Icon(
                          Icons.check_circle,
                          color: Colors.green.shade600,
                          size: 18,
                        )
                      : null,
                ),
                initialValue: provider.seciliBirimFor(index),
                items: provider.birimler
                    .map(
                      (b) => DropdownMenuItem(
                        value: b.id,
                        child: Text(
                          '${b.kisaAd} — ${b.ad}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: (b.iban?.trim().isNotEmpty == true)
                                ? null
                                : Colors.orange.shade800,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val == null) return;
                  provider.setSeciliBirim(index, val);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // --- DİNAMİK ALANLAR ---
        _buildDinamikAlanlar(context, provider, invoice, index, provider.getBirimKategori(provider.seciliBirimFor(index))),
        const SizedBox(height: 8),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  _field(
                    'Firma Adı *',
                    invoice.firmaAdi,
                    (v) => provider.updateField(index, 'firmaAdi', v),
                    cardIndex: index,
                  ),
                  _field(
                    'Adres',
                    invoice.adres,
                    (v) => provider.updateField(index, 'adres', v),
                    cardIndex: index,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          'Vergi Dairesi',
                          invoice.vergiDairesi,
                          (v) => provider.updateField(index, 'vergiDairesi', v),
                          cardIndex: index,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _field(
                          'VKN / TC',
                          invoice.vergiNo,
                          (v) => provider.updateField(index, 'vergiNo', v),
                          cardIndex: index,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _field(
                    'Tarih *',
                    invoice.tarih,
                    (v) => provider.updateField(index, 'tarih', v),
                    cardIndex: index,
                  ),
                  _field(
                    'İrsaliye No',
                    invoice.irsaliyeNo,
                    (v) => provider.updateField(index, 'irsaliyeNo', v),
                    cardIndex: index,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _field(
                'MELBES No *',
                invoice.melbesNo,
                (v) => provider.updateField(index, 'melbesNo', v),
                cardIndex: index,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _field(
                'Numune No *',
                invoice.numuneNo,
                (v) => provider.updateField(index, 'numuneNo', v),
                cardIndex: index,
              ),
            ),
          ],
        ),
        // IBAN ve Hesap Adı: dialogCounter key'e dahil edilir.
        // Birim/firma seçiciden dönerken counter artar → alan yenilenir (yeni IBAN gösterilir).
        // Kullanıcı yazarken counter sabit → odak kaybolmaz.
        _field(
          'IBAN *',
          invoice.iban ?? '',
          (v) => provider.updateField(index, 'iban', v),
          rebuildKey: ValueKey('iban_${index}_$dialogCounter'),
        ),
        _field(
          'Hesap Adı *',
          invoice.hesapAdi ?? '',
          (v) => provider.updateField(index, 'hesapAdi', v),
          maxLines: 2,
          rebuildKey: ValueKey('hesap_${index}_$dialogCounter'),
        ),
        _field(
          'Numune Açıklaması',
          invoice.numuneAciklamasi,
          (v) => provider.updateField(index, 'numuneAciklamasi', v),
          maxLines: 2,
          cardIndex: index,
        ),
        _field(
          'Genel Açıklama',
          invoice.aciklama ?? '',
          (v) => provider.updateField(index, 'aciklama', v),
          maxLines: 2,
          cardIndex: index,
        ),
        const SizedBox(height: 8),
        _buildKalemler(context, provider, invoice, index),
        const SizedBox(height: 8),
        _buildTotals(provider, invoice, index),
      ],
    );
  }

  Widget _field(
    String label,
    String value,
    ValueChanged<String> onChanged, {
    int maxLines = 1,
    Key? rebuildKey,
    int cardIndex = 0,
  }) {
    final empty = value.trim().isEmpty;
    final required = label.contains('*');
    final warn = required && empty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        // Key = kart indexi + label. Değer key'e dahil edilmez → odak korunur.
        // Birden fazla kart aynı anda açık olsa da key çakışmaz.
        key: rebuildKey ?? ValueKey('field_${cardIndex}_$label'),
        initialValue: value,
        maxLines: maxLines,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label.replaceAll(' *', ''),
          isDense: true,
          filled: true,
          fillColor: warn
              ? Colors.red.shade50
              : (empty ? Colors.grey.shade50 : Colors.green.shade50),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: warn ? Colors.red.shade300 : Colors.grey.shade300,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKalemler(
    BuildContext context,
    BatchFaturaProvider provider,
    FaturaModel invoice,
    int index,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: const Text(
              'Kalemler',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: Wrap(
              spacing: 6,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.post_add, size: 16),
                  label: const Text('Fiyat listesi'),
                  onPressed: () => _showHizmetSecici(context, provider, index),
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Kalem'),
                  onPressed: () => provider.addKalem(index),
                ),
              ],
            ),
          ),
          if (invoice.kalemler.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'En az bir kalem ekleyin',
                style: TextStyle(color: Colors.red),
              ),
            )
          else
            ...invoice.kalemler.asMap().entries.map((e) {
              final k = e.value;
              final ki = e.key;
              return Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        // Sabit key: sadece fatura index + kalem index. Değer key'e dahil edilmez.
                        key: ValueKey('kalem_${index}_${ki}_cinsi'),
                        initialValue: k['cinsi']?.toString() ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Hizmet',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) =>
                            provider.updateKalem(index, ki, 'cinsi', v),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 56,
                      child: TextFormField(
                        key: ValueKey('kalem_${index}_${ki}_miktar'),
                        initialValue: k['miktar']?.toString() ?? '1',
                        decoration: const InputDecoration(
                          labelText: 'Adet',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => provider.updateKalem(
                          index,
                          ki,
                          'miktar',
                          int.tryParse(v) ?? 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 90,
                      child: TextFormField(
                        key: ValueKey('kalem_${index}_${ki}_fiyat'),
                        initialValue: k['fiyat']?.toString() ?? '0',
                        decoration: const InputDecoration(
                          labelText: 'Fiyat',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => provider.updateKalem(
                          index,
                          ki,
                          'fiyat',
                          double.tryParse(v) ?? 0,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      onPressed: () => provider.removeKalem(index, ki),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTotals(
    BatchFaturaProvider provider,
    FaturaModel invoice,
    int index,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Switch(
            value: invoice.isKdvMuaf,
            onChanged: (v) => provider.toggleKdvMuaf(index, v),
          ),
          const Text('KDV muaf', style: TextStyle(fontSize: 12)),
          const Spacer(),
          _totalChip('Matrah', TurkceFormat.para(invoice.matrah)),
          const SizedBox(width: 8),
          if (!invoice.isKdvMuaf)
            DropdownButton<double>(
              value: invoice.kdvOrani,
              items: const [0.0, 1.0, 10.0, 20.0]
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text('KDV %${v.toInt()}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) provider.updateField(index, 'kdvOrani', v);
              },
            ),
          const SizedBox(width: 8),
          _totalChip(
            'Toplam',
            TurkceFormat.para(invoice.genelToplam),
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _totalChip(String label, String value, {bool bold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildActions(
    BuildContext context,
    BatchFaturaProvider provider,
    FaturaModel invoice,
    int index,
    bool hazir,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey.shade50,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          OutlinedButton.icon(
            key: ValueKey('fatura_sil_$index'),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Sil'),
            onPressed: () => provider.removeInvoice(index),
          ),
          OutlinedButton.icon(
            key: ValueKey('fatura_kopyala_$index'),
            icon: const Icon(Icons.copy_all),
            label: const Text('Kopyala'),
            onPressed: () {
              provider.duplicateInvoice(index);
              setState(() => _expandedCards.add(index + 1));
            },
          ),
          OutlinedButton.icon(
            key: ValueKey('fatura_onizle_$index'),
            icon: const Icon(Icons.visibility),
            label: const Text('Önizle'),
            onPressed: () => _showPreview(context, provider, invoice),
          ),
          FilledButton.icon(
            key: ValueKey('fatura_matbu_yazdir_$index'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.deepOrange.shade700,
            ),
            icon: const Icon(Icons.print),
            label: const Text('Matbu Yazdır'),
            onPressed: () async {
              final eksik = provider.eksikAlanlarForInvoice(invoice);
              if (eksik.isNotEmpty) {
                final devam = await _confirmEksikAlanDevam(
                  context,
                  baslik: 'Eksik alanlarla yazdırılsın mı?',
                  aciklama:
                      'Bu faturada bazı alanlar eksik. Yine de matbu yazdırmak istiyor musunuz?',
                  eksikAlanlar: eksik,
                  devamEtMetni: 'Yine de Yazdır',
                );
                if (devam != true) return;
              }
              try {
                await provider.matbuYazdir(invoice);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Yazdırma hatası: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
          FilledButton.icon(
            key: ValueKey('fatura_kaydet_onayla_$index'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade700,
            ),
            icon: const Icon(Icons.check),
            label: const Text('Kaydet ve Onayla'),
            onPressed: () async {
              final eksik = provider.eksikAlanlarForInvoice(invoice);
              var validateRequired = true;
              if (eksik.isNotEmpty) {
                final devam = await _confirmEksikAlanDevam(
                  context,
                  baslik: 'Eksik alanlarla kaydedilsin mi?',
                  aciklama:
                      'Bu faturada bazı alanlar eksik. Yine de geçici arşive kaydetmek istiyor musunuz?',
                  eksikAlanlar: eksik,
                  devamEtMetni: 'Yine de Kaydet',
                );
                if (devam != true) return;
                validateRequired = false;
              }
              try {
                await provider.approveInvoice(
                  index,
                  validateRequired: validateRequired,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fatura geçici arşive kaydedildi.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmEksikAlanDevam(
    BuildContext context, {
    required String baslik,
    required String aciklama,
    required List<String> eksikAlanlar,
    required String devamEtMetni,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(baslik),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(aciklama),
              const SizedBox(height: 12),
              const Text(
                'Eksik alanlar:',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              ...eksikAlanlar.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('• $e'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Geri Dön'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(devamEtMetni),
          ),
        ],
      ),
    );
  }

  Future<void> _approveAll(
    BuildContext context,
    BatchFaturaProvider provider,
  ) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tümünü onayla'),
        content: const Text(
          'Eksik alanı olan faturalar atlanır. IBAN, hesap adı, MELBES, numune ve tarih zorunludur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    if (onay != true || !context.mounted) return;

    final sonuc = await provider.approveAll();
    if (!context.mounted) return;

    final mesaj = sonuc.kaydedilen > 0
        ? '${sonuc.kaydedilen} fatura kaydedildi.'
        : 'Kaydedilen fatura yok.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sonuc.hatalar.isEmpty
              ? mesaj
              : '$mesaj ${sonuc.hatalar.length} hata.',
        ),
        backgroundColor: sonuc.hatalar.isEmpty ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 4),
      ),
    );
    if (sonuc.hatalar.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Atlanan faturalar'),
          content: SingleChildScrollView(child: Text(sonuc.hatalar.join('\n'))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    }
  }

  void _showPreview(
    BuildContext context,
    BatchFaturaProvider provider,
    FaturaModel invoice,
  ) {
    var arkaPlan = !provider.matbuBaskiModu;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: SizedBox(
              width: MediaQuery.of(ctx).size.width * 0.85,
              height: MediaQuery.of(ctx).size.height * 0.9,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Text(
                          'PDF Önizleme',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        FilterChip(
                          label: const Text('Şablon arka planı'),
                          selected: arkaPlan,
                          onSelected: (v) => setLocal(() => arkaPlan = v),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PdfPreview(
                      build: (format) => provider.generatePdf(
                        invoice,
                        includeBackground: arkaPlan,
                      ),
                      allowSharing: true,
                      allowPrinting: true,
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showRawTextDialog(BuildContext context, BatchFaturaProvider provider) {
    final controller = TextEditingController();
    var loading = false;

    Future<void> calistir(
      StateSetter setLocal,
      BuildContext ctx,
      bool cevrimdisi,
    ) async {
      if (controller.text.trim().isEmpty) return;
      setLocal(() => loading = true);
      try {
        await provider.loadBatch(controller.text, cevrimdisi: cevrimdisi);
        if (ctx.mounted) Navigator.pop(ctx);
        setState(() => _expandedCards.add(0));
        if (context.mounted && provider.sonAyristirmaBilgisi != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.sonAyristirmaBilgisi!),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (ctx.mounted) setLocal(() => loading = false);
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Metin yapıştır (isteğe bağlı)'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Dosya seç (PDF, Excel, CSV, TXT)'),
                  onPressed: loading
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          _uploadFaturaDocument(context, provider);
                        },
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'veya metni aşağıya yapıştırın',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText:
                        'PDF, e-posta veya Excel metnini buraya yapıştırın…',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'İnternet/AI yoksa "Çevrimdışı" kural tabanlı okur.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
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
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.wifi_off, size: 18),
              label: const Text('Çevrimdışı'),
              onPressed: loading ? null : () => calistir(setLocal, ctx, true),
            ),
            FilledButton.icon(
              icon: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Yapay Zeka'),
              onPressed: loading ? null : () => calistir(setLocal, ctx, false),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFirmaSecici(
    BuildContext context,
    BatchFaturaProvider provider,
    int index,
  ) async {
    final firma = await showDialog<FirmaModel>(
      context: context,
      builder: (_) => const FirmaSeciciDialog(),
    );
    if (firma == null) return;
    provider.updateField(index, 'firmaAdi', firma.firmaAdi);
    provider.updateField(index, 'adres', firma.adres);
    provider.updateField(index, 'vergiDairesi', firma.vergiDairesi);
    provider.updateField(index, 'vergiNo', firma.vergiNo);
    provider.notifyDialogReturn();
  }

  Future<void> _showHizmetSecici(
    BuildContext context,
    BatchFaturaProvider provider,
    int index,
  ) async {
    final hizmet = await showDialog<HizmetModel>(
      context: context,
      builder: (_) => const HizmetSeciciDialog(),
    );
    if (hizmet == null) return;
    final invoice = provider.pendingInvoices[index];
    final emptyIdx = invoice.kalemler.indexWhere(
      (k) => (k['cinsi']?.toString() ?? '').isEmpty,
    );
    if (emptyIdx >= 0) {
      provider.updateKalem(index, emptyIdx, 'cinsi', hizmet.hizmetAdi);
      provider.updateKalem(index, emptyIdx, 'miktar', 1);
      provider.updateKalem(index, emptyIdx, 'fiyat', hizmet.fiyat);
    } else {
      provider.addKalem(index);
      final ni = provider.pendingInvoices[index].kalemler.length - 1;
      provider.updateKalem(index, ni, 'cinsi', hizmet.hizmetAdi);
      provider.updateKalem(index, ni, 'miktar', 1);
      provider.updateKalem(index, ni, 'fiyat', hizmet.fiyat);
    }
    provider.notifyDialogReturn();
  }

  Future<void> _uploadExcel(
    BuildContext context,
    BatchFaturaProvider provider,
  ) async {
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Excel seçiliyor…')),
          ],
        ),
      ),
    );

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xls', 'xlsx', 'csv'],
        withData: true,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // yükleme dialogunu kapat

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;

      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('Excel analiz ediliyor…')),
            ],
          ),
        ),
      );

      await provider.loadExcelFile(file.bytes!, file.name);

      if (!context.mounted) return;
      Navigator.pop(context);
      setState(() => _expandedCards.add(0));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${provider.pendingInvoices.length} fatura oluşturuldu.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _uploadFaturaDocument(
    BuildContext context,
    BatchFaturaProvider provider,
  ) async {
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Dosya seçiliyor…')),
          ],
        ),
      ),
    );

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'csv', 'xls', 'xlsx'],
        withData: true,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // seçim dialogunu kapat

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) return;

      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(child: Text('${file.name} okunuyor…')),
            ],
          ),
        ),
      );

      final extension = (file.extension ?? '').toLowerCase();
      if (extension == 'xls' || extension == 'xlsx') {
        await provider.loadExcelFile(bytes, file.name);
      } else {
        final text = await _extractTextFromFile(bytes, extension);
        await provider.loadBatch(text);
      }

      if (!context.mounted) return;
      Navigator.pop(context);
      setState(() => _expandedCards.add(0));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${provider.pendingInvoices.length} fatura oluşturuldu.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Evrak okunamadı: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDinamikAlanlar(
    BuildContext context,
    BatchFaturaProvider provider,
    FaturaModel invoice,
    int index,
    String kategori,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hizmet Tipi Her Zaman Gösterilsin
        DropdownButtonFormField<String>(
          key: ValueKey('hizmetTipi_$index'),
          decoration: const InputDecoration(
            labelText: 'Hizmet Tipi',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          value: invoice.hizmetTipi,
          items: fHizmetTipleri.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => provider.updateField(index, 'hizmetTipi', v),
        ),
        const SizedBox(height: 8),
        
        if (kategori == 'kurs') ...[
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _field(
                  'Kurs / Program Adı',
                  invoice.kursAdi ?? '',
                  (v) => provider.updateField(index, 'kursAdi', v),
                  cardIndex: index,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: _field(
                  'Kur No',
                  invoice.kurNo?.toString() ?? '',
                  (v) => provider.updateField(index, 'kurNo', v),
                  cardIndex: index,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('odemeTipi_$index'),
                  decoration: const InputDecoration(
                    labelText: 'Ödeme Tipi',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  value: invoice.odemeTipi,
                  items: fOdemeTipleri.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => provider.updateField(index, 'odemeTipi', v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CheckboxListTile(
                  title: const Text('YTB Öğrencisi', style: TextStyle(fontSize: 13)),
                  value: invoice.ytbOgrencisi,
                  onChanged: (v) => provider.updateField(index, 'ytbOgrencisi', v),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ],

        if (kategori == 'tarimsal') ...[
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('urunTuru_$index'),
                  decoration: const InputDecoration(
                    labelText: 'Ürün Türü',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  value: invoice.urunTuru,
                  items: fUrunTurleri.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => provider.updateField(index, 'urunTuru', v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _field(
                  'Dönem (Ör: Ocak 2025)',
                  invoice.donem ?? '',
                  (v) => provider.updateField(index, 'donem', v),
                  cardIndex: index,
                ),
              ),
            ],
          ),
        ],

        if (kategori == 'satin_alma') ...[
          DropdownButtonFormField<String>(
            key: ValueKey('tedarikYontemi_$index'),
            decoration: const InputDecoration(
              labelText: 'Tedarik Yöntemi',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            value: invoice.tedarikYontemi,
            items: fTedarikYontemleri.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => provider.updateField(index, 'tedarikYontemi', v),
          ),
          const SizedBox(height: 8),
        ],

        if (kategori == 'analiz') ...[
          CheckboxListTile(
            title: const Text('KDV\'den Muaftır (İstisna)', style: TextStyle(fontSize: 13)),
            value: invoice.isVergiIstisnasi,
            onChanged: (v) => provider.updateField(index, 'isVergiIstisnasi', v),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ],

        if (kategori == 'hizmet') ...[
          _field(
            'Dönem (Ör: Ocak 2025)',
            invoice.donem ?? '',
            (v) => provider.updateField(index, 'donem', v),
            cardIndex: index,
          ),
        ],
      ],
    );
  }

  Future<String> _extractTextFromFile(List<int> bytes, String extension) async {
    if (extension == 'pdf') {
      final document = PdfDocument(inputBytes: bytes);
      try {
        final text = PdfTextExtractor(document).extractText().trim();
        if (text.isEmpty) {
          throw Exception(
            'PDF metin içermiyor olabilir. Taranmış görsel PDF ise metni kopyalayıp yapıştırın.',
          );
        }
        return text;
      } finally {
        document.dispose();
      }
    }

    if (extension == 'txt' || extension == 'csv') {
      final text = utf8.decode(bytes, allowMalformed: true).trim();
      if (text.isEmpty) throw Exception('Dosya boş veya metin okunamadı.');
      return text;
    }

    throw Exception('Desteklenmeyen dosya türü: .$extension');
  }
}
