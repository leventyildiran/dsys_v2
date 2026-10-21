import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/turkce_format.dart';
import '../../models/beyanname_belge_model.dart';
import '../../providers/beyanname_provider.dart';
import '../../services/beyanname_denetim_servisi.dart';

/// Tek bir faturayı AI ile okuyup kullanıcıya onay ve düzenleme imkanı sunan modern pencere.
class TekilFaturaAiDialog extends StatefulWidget {
  final String birimAdi;
  final BirimYuklenenBelge belge;
  final BeyannameProvider provider;

  const TekilFaturaAiDialog({
    super.key,
    required this.birimAdi,
    required this.belge,
    required this.provider,
  });

  static Future<void> goster(
    BuildContext context, {
    required String birimAdi,
    required BirimYuklenenBelge belge,
    required BeyannameProvider provider,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 580,
            child: TekilFaturaAiDialog(
              birimAdi: birimAdi,
              belge: belge,
              provider: provider,
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<TekilFaturaAiDialog> createState() => _TekilFaturaAiDialogState();
}

class _TekilFaturaAiDialogState extends State<TekilFaturaAiDialog> {
  bool _isLoading = true;
  String? _errorMessage;

  late TextEditingController _firmaCtrl;
  late TextEditingController _vknCtrl;
  late TextEditingController _faturaNoCtrl;
  late TextEditingController _tarihCtrl;
  late TextEditingController _matrahCtrl;
  late TextEditingController _kdvCtrl;
  late TextEditingController _tevkifatTutarCtrl;
  late TextEditingController _tevkifatTuruCtrl;

  int _seciliKdvOrani = 20;
  String _seciliTevkifatOrani = '9/10';

  @override
  void initState() {
    super.initState();
    _firmaCtrl = TextEditingController();
    _vknCtrl = TextEditingController();
    _faturaNoCtrl = TextEditingController();
    _tarihCtrl = TextEditingController();
    _matrahCtrl = TextEditingController();
    _kdvCtrl = TextEditingController();
    _tevkifatTutarCtrl = TextEditingController();
    _tevkifatTuruCtrl = TextEditingController();

    _analiziBaslat();
  }

  @override
  void dispose() {
    _firmaCtrl.dispose();
    _vknCtrl.dispose();
    _faturaNoCtrl.dispose();
    _tarihCtrl.dispose();
    _matrahCtrl.dispose();
    _kdvCtrl.dispose();
    _tevkifatTutarCtrl.dispose();
    _tevkifatTuruCtrl.dispose();
    super.dispose();
  }

  Future<void> _analiziBaslat() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await widget.provider.tekilFaturaAiCozumle(widget.belge);
      if (!mounted) return;

      if (res != null) {
        _firmaCtrl.text = res['firmaAdi']?.toString() ?? '';
        _vknCtrl.text = res['vergiTcNo']?.toString() ?? '';
        _faturaNoCtrl.text = res['faturaNo']?.toString() ?? '';
        _tarihCtrl.text = res['faturaTarihi']?.toString() ?? '';
        _matrahCtrl.text = TurkceFormat.paraKalem(TurkceFormat.parseSayi(res['matrahTutari']));
        _kdvCtrl.text = TurkceFormat.paraKalem(TurkceFormat.parseSayi(res['kdvTutari']));
        _tevkifatTutarCtrl.text = TurkceFormat.paraKalem(TurkceFormat.parseSayi(res['tevkifatTutari']));
        _tevkifatTuruCtrl.text = res['tevkifatTuru']?.toString() ?? '';

        final kOran = (res['kdvOrani'] as num?)?.toInt() ?? 20;
        if ([1, 8, 10, 18, 20].contains(kOran)) {
          _seciliKdvOrani = kOran;
        }

        final tOran = res['tevkifatOrani']?.toString().trim() ?? '9/10';
        if (['9/10', '7/10', '5/10', '2/10', '3/10', '4/10'].contains(tOran)) {
          _seciliTevkifatOrani = tOran;
        }
      } else {
        _errorMessage = 'Belgeden fatura ve tevkifat bilgisi çıkarılamadı. Bilgileri elle tamamlayabilirsiniz.';
      }
    } catch (e) {
      if (mounted) {
        _errorMessage = 'Analiz sırasında hata oluştu: $e';
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _otomatikHesapla() {
    final matrah = TurkceFormat.parseSayi(_matrahCtrl.text);
    if (matrah > 0) {
      final kdv = matrah * (_seciliKdvOrani / 100.0);
      double katsayi = 0.9;
      final parts = _seciliTevkifatOrani.split('/');
      if (parts.length == 2) {
        final pay = double.tryParse(parts[0]) ?? 9;
        final payda = double.tryParse(parts[1]) ?? 10;
        if (payda > 0) katsayi = pay / payda;
      }
      final tevkifat = kdv * katsayi;
      _kdvCtrl.text = TurkceFormat.paraKalem(kdv);
      _tevkifatTutarCtrl.text = TurkceFormat.paraKalem(tevkifat);
    }
  }

  bool get _isVknValid {
    final clean = _vknCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.length == 10) return BeyannameDenetimServisi.dogrulaVkn(clean);
    if (clean.length == 11) return BeyannameDenetimServisi.dogrulaTckn(clean);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Akıllı Fatura & Tevkifat Çözümleyici',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dosya Başlık Kartı
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withAlpha(80),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.belge.isPdf ? Icons.picture_as_pdf_rounded : Icons.table_chart_rounded,
                          size: 18,
                          color: widget.belge.isPdf ? AppColors.danger : AppColors.success,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.belge.dosyaAdi,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Birim: ${widget.birimAdi} · Boyut: ${widget.belge.okunabilirBoyut}',
                                style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _analiziBaslat,
                          icon: const Icon(Icons.refresh_rounded, size: 13),
                          label: const Text('Tekrar Tara', style: TextStyle(fontSize: 10.5)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warningSubtle,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.warning.withAlpha(120)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Form Alanları
                  _buildForm(),

                  const SizedBox(height: 18),

                  // Kaydet & Aktar Butonu
                  FilledButton.icon(
                    onPressed: _kaydetVeAktar,
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text(
                      'KDV 2 Masasına Ekle / Güncelle',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'Yapay zeka faturayı inceliyor...',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Satıcı firma unvanı, VKN/TCKN, matrah ve tevkifat oranları kuruşu kuruşuna çıkarılıyor.',
            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Satıcı Firma ve VKN
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _buildInput(
                label: 'Faturayı Düzenleyen / Satan Firma',
                controller: _firmaCtrl,
                hint: 'Örn: ABC Temizlik Hizmetleri San. Tic. Ltd. Şti.',
                icon: Icons.business_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInput(
                    label: 'VKN / TCKN',
                    controller: _vknCtrl,
                    hint: '10 veya 11 Hane',
                    icon: Icons.badge_outlined,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_vknCtrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          _isVknValid ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                          size: 11,
                          color: _isVknValid ? AppColors.success : AppColors.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isVknValid
                              ? (_vknCtrl.text.trim().length == 10 ? '✓ GİB VKN Algoritma Doğrulandı' : '✓ TCKN Doğrulandı')
                              : 'GİB Algoritma Uyarısı (Kontrol ediniz)',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: _isVknValid ? AppColors.success : AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // 2. Fatura No ve Tarih
        Row(
          children: [
            Expanded(
              child: _buildInput(
                label: 'Fatura Seri / No',
                controller: _faturaNoCtrl,
                hint: 'Örn: GIB2024000000123',
                icon: Icons.receipt_long_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildInput(
                label: 'Fatura Tarihi',
                controller: _tarihCtrl,
                hint: 'GG.AA.YYYY',
                icon: Icons.calendar_today_rounded,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // 3. Matrah ve KDV Oranı
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildInput(
                label: 'KDV Hariç Matrah (₺)',
                controller: _matrahCtrl,
                hint: '0,00',
                icon: Icons.attach_money_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _otomatikHesapla(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('KDV Oranı', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _seciliKdvOrani,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 20, child: Text('%20 Genel Oran', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 10, child: Text('%10 İndirimli Oran', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 1, child: Text('%1 Oran', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 8, child: Text('%8 Oran', style: TextStyle(fontSize: 12))),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _seciliKdvOrani = val);
                            _otomatikHesapla();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // 4. Tevkifat Oranı ve Tevkifat Tutarı
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tevkifat Oranı', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _seciliTevkifatOrani,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: '9/10', child: Text('9/10 (Temizlik, Güvenlik vb.)', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: '7/10', child: Text('7/10 (Yemek vb.)', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: '5/10', child: Text('5/10 (Yapım, Servis vb.)', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: '4/10', child: Text('4/10 Oran', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: '3/10', child: Text('3/10 Oran', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: '2/10', child: Text('2/10 Oran', style: TextStyle(fontSize: 12))),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _seciliTevkifatOrani = val);
                            _otomatikHesapla();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: _buildInput(
                label: 'Tevkif Edilen KDV (₺)',
                controller: _tevkifatTutarCtrl,
                hint: '0,00',
                icon: Icons.account_balance_wallet_outlined,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // 5. Tevkifat Türü Açıklaması
        _buildInput(
          label: 'Tevkifat Türü / Hizmet Niteliği',
          controller: _tevkifatTuruCtrl,
          hint: 'Örn: 604 Temizlik Hizmeti veya Özel Güvenlik',
          icon: Icons.category_rounded,
        ),
      ],
    );
  }

  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 38,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              prefixIcon: Icon(icon, size: 16, color: AppColors.textSecondary),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _kaydetVeAktar() {
    final firma = _firmaCtrl.text.trim();
    final vkn = _vknCtrl.text.trim();
    final matrah = TurkceFormat.parseSayi(_matrahCtrl.text);
    final kdv = TurkceFormat.parseSayi(_kdvCtrl.text);
    final tevkifat = TurkceFormat.parseSayi(_tevkifatTutarCtrl.text);

    if (firma.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen firma unvanını giriniz.'), backgroundColor: AppColors.danger),
      );
      return;
    }

    if (matrah <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen geçerli bir matrah tutarı giriniz.'), backgroundColor: AppColors.danger),
      );
      return;
    }

    final faturaMap = {
      'firmaAdi': firma,
      'vergiTcNo': vkn,
      'faturaNo': _faturaNoCtrl.text.trim(),
      'faturaTarihi': _tarihCtrl.text.trim(),
      'matrahTutari': matrah,
      'kdvOrani': _seciliKdvOrani,
      'kdvTutari': kdv > 0 ? kdv : matrah * (_seciliKdvOrani / 100.0),
      'tevkifatOrani': _seciliTevkifatOrani,
      'tevkifatTutari': tevkifat > 0 ? tevkifat : kdv * 0.9,
      'tevkifatTuru': _tevkifatTuruCtrl.text.trim(),
    };

    widget.provider.tekilFaturaKaydet(
      birimAdi: widget.birimAdi,
      faturaMap: faturaMap,
      masayaAktar: true,
    );

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ $firma faturası KDV 2 tevkifat masasına aktarıldı ve birim özetine eklendi.'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
