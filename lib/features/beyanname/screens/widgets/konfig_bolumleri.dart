import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/beyanname_konfigurasyonu.dart';

/// Yapılandırma ekranındaki her bölümü saran başlıklı kart.
///
/// Tüm bölümler aynı görsel dili paylaşsın diye tek yerde tanımlanır;
/// renkler yalnızca [AppColors] tokenlarından alınır.
class KonfigBolumKarti extends StatelessWidget {
  const KonfigBolumKarti({
    super.key,
    required this.ikon,
    required this.baslik,
    required this.aciklama,
    required this.child,
    this.sagUstEylem,
  });

  final IconData ikon;
  final String baslik;
  final String aciklama;
  final Widget child;

  /// Başlık satırının sağında gösterilecek eylem (örn. "Ekle").
  final Widget? sagUstEylem;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(ikon, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        baslik,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        aciklama,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (sagUstEylem != null) ...[
                  const SizedBox(width: 12),
                  sagUstEylem!,
                ],
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

/// Boş liste durumunda gösterilen nötr bilgi satırı.
class KonfigBosDurum extends StatelessWidget {
  const KonfigBosDurum({super.key, required this.mesaj});

  final String mesaj;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.neutralSubtle,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        mesaj,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// KDV oranları
// ---------------------------------------------------------------------------

/// KDV oranı listesi düzenleyicisi (ekle / düzenle / sil).
class KdvOranlariEditor extends StatelessWidget {
  const KdvOranlariEditor({
    super.key,
    required this.oranlar,
    required this.onDegisti,
    required this.onSil,
  });

  final List<KdvOranTanimi> oranlar;
  final void Function(int index, KdvOranTanimi yeni) onDegisti;
  final void Function(int index) onSil;

  @override
  Widget build(BuildContext context) {
    if (oranlar.isEmpty) {
      return const KonfigBosDurum(
        mesaj: 'Tanımlı KDV oranı yok. "Oran Ekle" ile en az bir oran girin.',
      );
    }
    return Column(
      children: [
        for (var i = 0; i < oranlar.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == oranlar.length - 1 ? 0 : 12),
            child: _KdvOranSatiri(
              key: ValueKey('kdv_oran_$i'),
              tanim: oranlar[i],
              onChanged: (yeni) => onDegisti(i, yeni),
              onSil: () => onSil(i),
            ),
          ),
      ],
    );
  }
}

class _KdvOranSatiri extends StatefulWidget {
  const _KdvOranSatiri({
    super.key,
    required this.tanim,
    required this.onChanged,
    required this.onSil,
  });

  final KdvOranTanimi tanim;
  final ValueChanged<KdvOranTanimi> onChanged;
  final VoidCallback onSil;

  @override
  State<_KdvOranSatiri> createState() => _KdvOranSatiriState();
}

class _KdvOranSatiriState extends State<_KdvOranSatiri> {
  late final TextEditingController _oranController;
  late final TextEditingController _etiketController;

  @override
  void initState() {
    super.initState();
    _oranController = TextEditingController(text: widget.tanim.oran.toString());
    _etiketController = TextEditingController(text: widget.tanim.etiket ?? '');
  }

  @override
  void didUpdateWidget(covariant _KdvOranSatiri oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oranMetni = widget.tanim.oran.toString();
    if (_oranController.text != oranMetni) {
      _oranController.text = oranMetni;
    }
    final etiketMetni = widget.tanim.etiket ?? '';
    if (_etiketController.text != etiketMetni) {
      _etiketController.text = etiketMetni;
    }
  }

  void _bildir() {
    final etiket = _etiketController.text.trim();
    widget.onChanged(
      KdvOranTanimi(
        oran: int.tryParse(_oranController.text.trim()) ?? 0,
        etiket: etiket.isEmpty ? null : etiket,
      ),
    );
  }

  @override
  void dispose() {
    _oranController.dispose();
    _etiketController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: TextField(
            controller: _oranController,
            keyboardType: TextInputType.number,
            onChanged: (_) => _bildir(),
            decoration: const InputDecoration(
              labelText: 'Oran',
              suffixText: '%',
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _etiketController,
            onChanged: (_) => _bildir(),
            decoration: InputDecoration(
              labelText: 'Etiket (opsiyonel)',
              hintText: widget.tanim.gorunenEtiket,
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Oranı sil',
          onPressed: widget.onSil,
          icon: const Icon(Icons.delete_outline),
          color: AppColors.actionDestructive,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tevkifat türleri
// ---------------------------------------------------------------------------

/// Tevkifat türü listesi düzenleyicisi (serbest pay/payda).
class TevkifatEditor extends StatelessWidget {
  const TevkifatEditor({
    super.key,
    required this.tevkifatlar,
    required this.onDegisti,
    required this.onSil,
  });

  final List<TevkifatTanimi> tevkifatlar;
  final void Function(int index, TevkifatTanimi yeni) onDegisti;
  final void Function(int index) onSil;

  @override
  Widget build(BuildContext context) {
    if (tevkifatlar.isEmpty) {
      return const KonfigBosDurum(
        mesaj: 'Tanımlı tevkifat türü yok. "Tür Ekle" ile pay/payda girin.',
      );
    }
    return Column(
      children: [
        for (var i = 0; i < tevkifatlar.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == tevkifatlar.length - 1 ? 0 : 12,
            ),
            child: _TevkifatSatiri(
              key: ValueKey('tevkifat_$i'),
              tanim: tevkifatlar[i],
              onChanged: (yeni) => onDegisti(i, yeni),
              onSil: () => onSil(i),
            ),
          ),
      ],
    );
  }
}

class _TevkifatSatiri extends StatefulWidget {
  const _TevkifatSatiri({
    super.key,
    required this.tanim,
    required this.onChanged,
    required this.onSil,
  });

  final TevkifatTanimi tanim;
  final ValueChanged<TevkifatTanimi> onChanged;
  final VoidCallback onSil;

  @override
  State<_TevkifatSatiri> createState() => _TevkifatSatiriState();
}

class _TevkifatSatiriState extends State<_TevkifatSatiri> {
  late final TextEditingController _etiketController;
  late final TextEditingController _payController;
  late final TextEditingController _paydaController;

  @override
  void initState() {
    super.initState();
    _etiketController = TextEditingController(text: widget.tanim.etiket);
    _payController = TextEditingController(text: widget.tanim.pay.toString());
    _paydaController = TextEditingController(
      text: widget.tanim.payda.toString(),
    );
  }

  @override
  void didUpdateWidget(covariant _TevkifatSatiri oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_etiketController.text != widget.tanim.etiket) {
      _etiketController.text = widget.tanim.etiket;
    }
    final pay = widget.tanim.pay.toString();
    if (_payController.text != pay) _payController.text = pay;
    final payda = widget.tanim.payda.toString();
    if (_paydaController.text != payda) _paydaController.text = payda;
  }

  void _bildir() {
    widget.onChanged(
      TevkifatTanimi(
        etiket: _etiketController.text.trim(),
        pay: int.tryParse(_payController.text.trim()) ?? 0,
        payda: int.tryParse(_paydaController.text.trim()) ?? 0,
      ),
    );
  }

  @override
  void dispose() {
    _etiketController.dispose();
    _payController.dispose();
    _paydaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final oran = widget.tanim.oran;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _etiketController,
            onChanged: (_) => _bildir(),
            decoration: const InputDecoration(
              labelText: 'Etiket',
              hintText: 'örn: 9/10',
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: TextField(
            controller: _payController,
            keyboardType: TextInputType.number,
            onChanged: (_) => _bildir(),
            decoration: const InputDecoration(
              labelText: 'Pay',
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: TextField(
            controller: _paydaController,
            keyboardType: TextInputType.number,
            onChanged: (_) => _bildir(),
            decoration: const InputDecoration(
              labelText: 'Payda',
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 64,
          child: Text(
            '%${(oran * 100).toStringAsFixed(1)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Türü sil',
          onPressed: widget.onSil,
          icon: const Icon(Icons.delete_outline),
          color: AppColors.actionDestructive,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Beyanname blokları
// ---------------------------------------------------------------------------

/// Hangi beyanname bölümlerinin görüneceğini yönetir (7 anahtar).
class BeyannameBloklariEditor extends StatelessWidget {
  const BeyannameBloklariEditor({
    super.key,
    required this.bloklar,
    required this.onChanged,
  });

  final BeyannameBloklari bloklar;
  final ValueChanged<BeyannameBloklari> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BlokSatiri(
          etiket: 'KDV1 — Hesaplanan / İndirilecek KDV',
          deger: bloklar.kdv1,
          onChanged: (v) => onChanged(bloklar.copyWith(kdv1: v)),
        ),
        _BlokSatiri(
          etiket: 'KDV2 — Tevkifat',
          deger: bloklar.kdv2,
          onChanged: (v) => onChanged(bloklar.copyWith(kdv2: v)),
        ),
        _BlokSatiri(
          etiket: 'Muhtasar — Gelir / Damga Stopajı',
          deger: bloklar.muhtasar,
          onChanged: (v) => onChanged(bloklar.copyWith(muhtasar: v)),
        ),
        _BlokSatiri(
          etiket: 'Damga 301',
          deger: bloklar.damga301,
          onChanged: (v) => onChanged(bloklar.copyWith(damga301: v)),
        ),
        _BlokSatiri(
          etiket: 'Damga 302',
          deger: bloklar.damga302,
          onChanged: (v) => onChanged(bloklar.copyWith(damga302: v)),
        ),
        _BlokSatiri(
          etiket: 'Hasılat 600',
          deger: bloklar.hasiat600,
          onChanged: (v) => onChanged(bloklar.copyWith(hasiat600: v)),
        ),
        _BlokSatiri(
          etiket: 'Kredi Kartı 123',
          deger: bloklar.krediKarti123,
          onChanged: (v) => onChanged(bloklar.copyWith(krediKarti123: v)),
        ),
      ],
    );
  }
}

class _BlokSatiri extends StatelessWidget {
  const _BlokSatiri({
    required this.etiket,
    required this.deger,
    required this.onChanged,
  });

  final String etiket;
  final bool deger;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        etiket,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      ),
      value: deger,
      onChanged: onChanged,
    );
  }
}

// ---------------------------------------------------------------------------
// Asgari ücret istisna tabloları (yıllık)
// ---------------------------------------------------------------------------

/// Ay adları (1-12 sırasıyla).
const List<String> _ayAdlari = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

/// Yıllık asgari ücret vergi istisnası tabloları düzenleyicisi.
///
/// Her yıl için 12 ayın gelir vergisi ve damga vergisi istisna tutarları
/// girilir. Kurum yeni bir yıl (örn. 2026) eklemek istediğinde kod değiştirmez;
/// yalnızca buraya kayıt ekler. Liste boşken hesaplama motoru yerleşik (2025)
/// tablosunu kullanmaya devam eder, böylece mevcut davranış korunur.
class AsgariUcretTablolariEditor extends StatelessWidget {
  const AsgariUcretTablolariEditor({
    super.key,
    required this.tablolar,
    required this.onDegisti,
    required this.onSil,
  });

  final List<AsgariUcretYilTablosu> tablolar;
  final void Function(int index, AsgariUcretYilTablosu yeni) onDegisti;
  final void Function(int index) onSil;

  @override
  Widget build(BuildContext context) {
    if (tablolar.isEmpty) {
      return const KonfigBosDurum(
        mesaj:
            'Tanımlı yıl tablosu yok. Boşken sistem yerleşik 2025 istisna '
            'tablosunu kullanır. Yeni yıl eklemek için "Yıl Ekle"ye dokunun.',
      );
    }
    return Column(
      children: [
        for (var i = 0; i < tablolar.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == tablolar.length - 1 ? 0 : 16),
            child: _AsgariUcretYilSatiri(
              key: ValueKey('asgari_yil_$i'),
              tablo: tablolar[i],
              onChanged: (yeni) => onDegisti(i, yeni),
              onSil: () => onSil(i),
            ),
          ),
      ],
    );
  }
}

class _AsgariUcretYilSatiri extends StatefulWidget {
  const _AsgariUcretYilSatiri({
    super.key,
    required this.tablo,
    required this.onChanged,
    required this.onSil,
  });

  final AsgariUcretYilTablosu tablo;
  final ValueChanged<AsgariUcretYilTablosu> onChanged;
  final VoidCallback onSil;

  @override
  State<_AsgariUcretYilSatiri> createState() => _AsgariUcretYilSatiriState();
}

class _AsgariUcretYilSatiriState extends State<_AsgariUcretYilSatiri> {
  late final TextEditingController _yilController;
  final Map<int, TextEditingController> _gelirControllers = {};
  final Map<int, TextEditingController> _damgaControllers = {};

  @override
  void initState() {
    super.initState();
    _yilController = TextEditingController(text: widget.tablo.yil.toString());
    for (var ay = 1; ay <= 12; ay++) {
      _gelirControllers[ay] =
          TextEditingController(text: _metin(widget.tablo.aylikGelirVergisi[ay]));
      _damgaControllers[ay] =
          TextEditingController(text: _metin(widget.tablo.aylikDamgaVergisi[ay]));
    }
  }

  static String _metin(double? deger) {
    if (deger == null || deger == 0) return '';
    return deger.toString();
  }

  static double _oku(String metin) {
    final normalize = metin.trim().replaceAll(',', '.');
    return double.tryParse(normalize) ?? 0.0;
  }

  @override
  void didUpdateWidget(covariant _AsgariUcretYilSatiri oldWidget) {
    super.didUpdateWidget(oldWidget);
    final yilMetni = widget.tablo.yil.toString();
    if (_yilController.text != yilMetni) {
      _yilController.text = yilMetni;
    }
  }

  void _bildir() {
    final gelir = <int, double>{};
    final damga = <int, double>{};
    for (var ay = 1; ay <= 12; ay++) {
      final g = _oku(_gelirControllers[ay]!.text);
      final d = _oku(_damgaControllers[ay]!.text);
      if (g != 0) gelir[ay] = g;
      if (d != 0) damga[ay] = d;
    }
    widget.onChanged(
      AsgariUcretYilTablosu(
        yil: int.tryParse(_yilController.text.trim()) ?? 0,
        aylikGelirVergisi: gelir,
        aylikDamgaVergisi: damga,
      ),
    );
  }

  @override
  void dispose() {
    _yilController.dispose();
    for (final c in _gelirControllers.values) {
      c.dispose();
    }
    for (final c in _damgaControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _yilController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _bildir(),
                  decoration: const InputDecoration(
                    labelText: 'Yıl',
                    hintText: 'örn: 2026',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Aylık gelir ve damga vergisi istisna tutarları (TL).',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
              IconButton(
                tooltip: 'Yılı sil',
                onPressed: widget.onSil,
                icon: const Icon(Icons.delete_outline),
                color: AppColors.actionDestructive,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var ay = 1; ay <= 12; ay++) ...[
                  SizedBox(
                    width: 120,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _ayAdlari[ay - 1],
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _gelirControllers[ay],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => _bildir(),
                          decoration: const InputDecoration(
                            labelText: 'Gelir',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _damgaControllers[ay],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => _bildir(),
                          decoration: const InputDecoration(
                            labelText: 'Damga',
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (ay < 12) const SizedBox(width: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
