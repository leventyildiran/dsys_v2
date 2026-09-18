import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/birim_service.dart';
import '../../../core/turkce_format.dart';
import '../models/danismanlik_model.dart';
import '../models/taksit_model.dart';
import '../services/danismanlik_excel_hesaplama.dart';
import '../services/danismanlik_manuel_kayit_servisi.dart';
import '../services/danismanlik_manuel_pdf_servisi.dart';
import '../widgets/danismanlik_layout.dart';
import 'manuel_hesapla/coklu_personel_ekle_dialog.dart';
import 'manuel_hesapla/tab_dag_maks_pay.dart';
import 'manuel_hesapla/tab_katki_payi.dart';
import 'manuel_hesapla/tab_liste.dart';
import 'manuel_hesapla/tab_ozet_icmal.dart';

// 2547 sayılı Kanun 58/k alan adları bilinçli olarak `_58k` ön ekiyle tutulur;
// bu, iş teriminin okunabilirliğini korur ve alt çizgi-dijit uyarısını giderir.
// ignore_for_file: non_constant_identifier_names

/// Danışmanlık ve Kurs Gelirleri için Excel benzeri sekmeli Manuel Hesaplama Ekranı.
class DanismanlikManuelHesaplaScreen extends StatefulWidget {
  const DanismanlikManuelHesaplaScreen({
    super.key,
    this.initialSablon,
    this.danismanlik,
    this.taksit,
  });

  final String? initialSablon;
  final DanismanlikModel? danismanlik;
  final TaksitModel? taksit;

  @override
  State<DanismanlikManuelHesaplaScreen> createState() => _DanismanlikManuelHesaplaScreenState();
}

class _DanismanlikManuelHesaplaScreenState extends State<DanismanlikManuelHesaplaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Aktif Şablon Türü ('dts', '58k', 'usem', 'tomer', 'dosim')
  String _aktifSablonTuru = 'dts';

  // Başlık Alanları
  final _kurumController = TextEditingController(text: 'T.C.\nUŞAK ÜNİVERSİTESİ REKTÖRLÜĞÜ');
  final _rektorlukController = TextEditingController(text: 'DÖNER SERMAYE İŞLETME MÜDÜRLÜĞÜ');
  final _mudurlukController = TextEditingController(text: 'DERİ, TEKSTİL UYGULAMA VE ARAŞTIRMA MERKEZİ MÜDÜRLÜĞÜ');
  final _hizmetBasligiController = TextEditingController(
    text: 'ÖĞR. GÖR. Dr. Neslihan ÖPÖZ VURAL DANIŞMANLIK HİZMET GELİRLERİ',
  );

  // Oranlar
  int _kdvOrani = 20;
  int _hazineOrani = 1;
  int _bapOrani = 5;
  double _aracGerecOrani = 0.45;

  // Dönem Katsayısı Manuel Müdahale
  bool _manuelKatsayiAktif = false;
  final _manuelKatsayiController = TextEditingController();

  // Liste Satırları
  List<ManuelListeSatiri> _satirlar = [];

  // Personeller
  List<ExcelPersonelGirdi> _personeller = [];

  // 2547 Madde 58/k Sözleşme / Taksit Yönetimi
  bool _58kOdemeTekSeferde = false;
  int _58kToplamTaksitSayisi = 3;
  int _58kAktifTaksitNo = 1;
  double? _58kOzelTaksitTutari;
  final _58kOzelTaksitController = TextEditingController();
  DateTime _58kSozlesmeBaslangic = DateTime(2026, 7, 24);
  String _58kDonemMetni = '24.07.2026 - 24.08.2026';
  int _gelirVergisiOrani = 15;

  // Memur Maaş Katsayısı
  double _memurMaasKatsayisi = 1.387871;
  final _memurMaasKatsayisiController = TextEditingController(text: '1.387871');

  // Birim Listesi
  List<String> _birimler = [];
  final BirimService _birimService = BirimService();

  // Kayıt Servisi
  final DanismanlikManuelKayitServisi _kayitServisi = DanismanlikManuelKayitServisi();
  String _aktifKayitId = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    if (widget.danismanlik != null) {
      _sozlesmedenYukle(widget.danismanlik!, widget.taksit);
    } else if (widget.initialSablon != null && widget.initialSablon!.isNotEmpty) {
      _sablonYukle(widget.initialSablon!);
    } else {
      _varsayilanOrnekYukle();
    }
    _birimleriYukle();
    _kayitliMemurKatsayisiYukle();
  }

  Future<void> _kayitliMemurKatsayisiYukle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final katsayi = prefs.getDouble('dsys_memur_maas_katsayisi');
      if (katsayi != null && katsayi > 0 && mounted) {
        setState(() {
          _memurMaasKatsayisi = katsayi;
          _memurMaasKatsayisiController.text = katsayi.toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _memurMaasKatsayisiKaydet() async {
    final text = _memurMaasKatsayisiController.text.replaceAll(',', '.').trim();
    final d = double.tryParse(text);
    if (d == null || d <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen geçerli bir memur maaş katsayısı giriniz.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('dsys_memur_maas_katsayisi', d);
      if (mounted) {
        setState(() {
          _memurMaasKatsayisi = d;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Memur maaş katsayısı ($d) sisteme varsayılan olarak kaydedildi.'),
              ],
            ),
            backgroundColor: const Color(0xFF0F766E),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kaydetme hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _kurumController.dispose();
    _rektorlukController.dispose();
    _mudurlukController.dispose();
    _hizmetBasligiController.dispose();
    _manuelKatsayiController.dispose();
    _memurMaasKatsayisiController.dispose();
    _58kOzelTaksitController.dispose();
    super.dispose();
  }

  Future<void> _birimleriYukle() async {
    try {
      final list = await _birimService.getAll();
      var isimler = list.map((b) => b.ad.trim()).where((s) => s.isNotEmpty).toSet().toList();
      if (isimler.isEmpty) {
        isimler = [
          'Deri, Tekstil ve Seramik Tasarım Uygulama ve Araştırma Merkezi',
          'Bilimsel Analiz ve Teknolojik Uygulama ve Araştırma Merkezi (UBATAM)',
          'Sürekli Eğitim Uygulama ve Araştırma Merkezi (USEM)',
          'Döner Sermaye İşletme Müdürlüğü',
        ];
      }
      isimler.sort();
      if (mounted) {
        setState(() {
          _birimler = isimler;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _birimler = [
            'Deri, Tekstil ve Seramik Tasarım Uygulama ve Araştırma Merkezi',
            'Bilimsel Analiz ve Teknolojik Uygulama ve Araştırma Merkezi (UBATAM)',
            'Sürekli Eğitim Uygulama ve Araştırma Merkezi (USEM)',
            'Döner Sermaye İşletme Müdürlüğü',
          ];
        });
      }
    }
  }

  Future<void> _kaydetDialogGoster() async {
    final baslikController = TextEditingController(
      text: _hizmetBasligiController.text.isNotEmpty
          ? _hizmetBasligiController.text
          : '${_mudurlukController.text} Hesaplama',
    );

    final sonuc = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.save_outlined, color: Color(0xFF107C41)),
            SizedBox(width: 8),
            Text('Hesaplamayı Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bu manuel hesaplama tablosunu daha sonra tekrar açmak veya raporlamak üzere kaydetmek için bir isim verin:',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: baslikController,
              decoration: const InputDecoration(
                labelText: 'Kayıt Başlığı / Açıklama',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Kaydet'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF107C41),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (sonuc == true && mounted) {
      final veri = _mevcutVeriOlustur();
      final kayit = ManuelHesaplamaKaydi(
        id: _aktifKayitId,
        kayitAdi: baslikController.text.trim(),
        kurumAdi: _kurumController.text.trim(),
        rektorlukAdi: _rektorlukController.text.trim(),
        mudurlukAdi: _mudurlukController.text.trim(),
        hizmetBasligi: _hizmetBasligiController.text.trim(),
        kdvOrani: _kdvOrani,
        hazineOrani: _hazineOrani,
        bapOrani: _bapOrani,
        aracGerecOrani: _aracGerecOrani,
        memurMaasKatsayisi: _memurMaasKatsayisi,
        manuelKatsayiAktif: _manuelKatsayiAktif,
        manuelKatsayi: _manuelKatsayiController.text,
        satirlar: _satirlar,
        personeller: _personeller,
        toplamTutar: veri.toplamTutar,
        kdvHaricGelir: veri.kdvHaricGelir,
        dagitilabilirPay: veri.kesintiSonuc.katkiPayi,
        sablonTuru: _aktifSablonTuru,
        odemeTekSeferde: _58kOdemeTekSeferde,
        toplamTaksitSayisi: _58kToplamTaksitSayisi,
        aktifTaksitNo: _58kAktifTaksitNo,
        danismanlikDonemi: _58kDonemMetni,
        sozlesmeBaslangicTarihi: _58kSozlesmeBaslangic,
      );

      try {
        final id = await _kayitServisi.kaydet(kayit);
        _aktifKayitId = id;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Manuel hesaplama başarıyla kaydedildi!'),
              backgroundColor: Color(0xFF107C41),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kayıt sırasında hata oluştu: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _kayitliHesaplamalarDialogGoster() async {
    final kayitlar = await _kayitServisi.listele();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.folder_open_outlined, color: Color(0xFF6366F1)),
              SizedBox(width: 8),
              Text('Kayıtlı Manuel Hesaplamalar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 650,
            height: 400,
            child: kayitlar.isEmpty
                ? const Center(
                    child: Text('Henüz kaydedilmiş bir hesaplama bulunmuyor.'),
                  )
                : ListView.separated(
                    itemCount: kayitlar.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final k = kayitlar[index];
                      final tarihStr = '${k.olusturmaTarihi.day}.${k.olusturmaTarihi.month}.${k.olusturmaTarihi.year} ${k.olusturmaTarihi.hour}:${k.olusturmaTarihi.minute.toString().padLeft(2, '0')}';
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF107C41).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.description_outlined, color: Color(0xFF107C41)),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                k.kayitAdi,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _sablonRengi(k.sablonTuru).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: _sablonRengi(k.sablonTuru).withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                _sablonBasligi(k.sablonTuru),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: _sablonRengi(k.sablonTuru),
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '${k.mudurlukAdi}\nToplam: ${TurkceFormat.para(k.toplamTutar)} · Dağ. Pay: ${TurkceFormat.para(k.dagitilabilirPay)} · $tarihStr',
                          style: const TextStyle(fontSize: 11, height: 1.3),
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                _kaydiYukle(k);
                                Navigator.pop(ctx);
                              },
                              icon: const Icon(Icons.file_download_outlined, size: 16),
                              label: const Text('Yükle'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF107C41),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                              tooltip: 'Kaydı Sil',
                              onPressed: () async {
                                await _kayitServisi.sil(k.id);
                                kayitlar.removeAt(index);
                                setModalState(() {});
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Kapat'),
            ),
          ],
        ),
      ),
    );
  }

  String _sablonBasligi(String tur) {
    switch (tur.toLowerCase()) {
      case '58k':
        return '2547 Madde 58/k';
      case '58e':
        return '2547 Madde 58/e';
      case 'usem':
        return 'USEM Kursu';
      case 'tomer':
        return 'TÖMER';
      case 'dosim':
        return 'DÖSİM';
      case 'dts':
      default:
        return 'DTS';
    }
  }

  Color _sablonRengi(String tur) {
    switch (tur.toLowerCase()) {
      case '58k':
        return const Color(0xFF2563EB); // Blue
      case '58e':
        return const Color(0xFF4F46E5); // Indigo
      case 'usem':
        return const Color(0xFF7C3AED); // Violet
      case 'tomer':
        return const Color(0xFFD97706); // Amber
      case 'dosim':
        return const Color(0xFF475569); // Slate
      case 'dts':
      default:
        return const Color(0xFF0F766E); // Teal
    }
  }

  void _kaydiYukle(ManuelHesaplamaKaydi k) {
    setState(() {
      _aktifKayitId = k.id;
      _aktifSablonTuru = k.sablonTuru;
      _kurumController.text = k.kurumAdi;
      _rektorlukController.text = k.rektorlukAdi;
      _mudurlukController.text = k.mudurlukAdi;
      _hizmetBasligiController.text = k.hizmetBasligi;
      _kdvOrani = k.kdvOrani;
      _hazineOrani = k.hazineOrani;
      _bapOrani = k.bapOrani;
      _aracGerecOrani = k.aracGerecOrani;
      _memurMaasKatsayisi = k.memurMaasKatsayisi;
      _memurMaasKatsayisiController.text = k.memurMaasKatsayisi.toString();
      _manuelKatsayiAktif = k.manuelKatsayiAktif;
      _manuelKatsayiController.text = k.manuelKatsayi;
      _satirlar = List.from(k.satirlar);
      _personeller = List.from(k.personeller);
      _58kOdemeTekSeferde = k.odemeTekSeferde;
      _58kToplamTaksitSayisi = k.toplamTaksitSayisi;
      _58kAktifTaksitNo = k.aktifTaksitNo;
      _58kDonemMetni = k.danismanlikDonemi;
      if (k.sozlesmeBaslangicTarihi != null) {
        _58kSozlesmeBaslangic = k.sozlesmeBaslangicTarihi!;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${k.kayitAdi}" başarıyla yüklendi!'),
        backgroundColor: const Color(0xFF107C41),
      ),
    );
  }

  void _sozlesmedenYukle(DanismanlikModel d, [TaksitModel? taksit]) {
    _aktifKayitId = d.id;

    // Şablon türü tespiti
    if (d.tur == DanismanlikTuru.sanayiIsbirligi58k) {
      _aktifSablonTuru = '58k';
      _hazineOrani = 0;
      _bapOrani = 0;
      _aracGerecOrani = 0.15; // 2547 Madde 58/k uyarınca yasal %15 Kurum Payı
    } else if (d.tur == DanismanlikTuru.egitimKuru) {
      final birimLower = (d.birimKisaAd ?? '').toLowerCase();
      _aktifSablonTuru = birimLower.contains('tömer') || birimLower.contains('tomer') ? 'tomer' : 'usem';
      _hazineOrani = d.hazinePayiOrani;
      _bapOrani = d.bapPayiOrani;
      _aracGerecOrani = d.aracGerecPayiOrani / 100.0;
    } else {
      _aktifSablonTuru = 'dts';
      _hazineOrani = d.hazinePayiOrani;
      _bapOrani = d.bapPayiOrani;
      _aracGerecOrani = d.aracGerecPayiOrani / 100.0;
    }

    _kdvOrani = d.kdvOrani;

    // Kurum ve Birim Başlıkları
    _kurumController.text = 'T.C.\nUŞAK ÜNİVERSİTESİ REKTÖRLÜĞÜ';
    _rektorlukController.text = 'DÖNER SERMAYE İŞLETME MÜDÜRLÜĞÜ';
    _mudurlukController.text = (d.birimKisaAd?.isNotEmpty == true ? d.birimKisaAd! : 'DÖNER SERMAYE İŞLETME MÜDÜRLÜĞÜ').toUpperCase();
    _hizmetBasligiController.text =
        '${d.firmaUnvan?.isNotEmpty == true ? "${d.firmaUnvan} - " : ""}${d.konusu}'.toUpperCase();

    // Sözleşme Matrahı ve KDV Dahil Toplam Tutar
    final double matrah = d.toplamTutar;
    final double kdvDahil = matrah * (1.0 + _kdvOrani / 100.0);

    _satirlar = [
      ManuelListeSatiri(
        sn: 1,
        tc: '',
        aciklama: '${d.firmaUnvan ?? ''} - ${d.konusu}',
        tutar: double.parse(kdvDahil.toStringAsFixed(2)),
      ),
      for (int i = 2; i <= 8; i++)
        ManuelListeSatiri(sn: i, tc: '', aciklama: '', tutar: 0.0),
    ];

    // Taksitlendirme & Süre
    _58kToplamTaksitSayisi = d.suresi > 0 ? d.suresi : 1;
    _58kOdemeTekSeferde = _58kToplamTaksitSayisi <= 1;
    _58kSozlesmeBaslangic = d.baslangicTarihi ?? DateTime.now();

    if (taksit != null) {
      _58kAktifTaksitNo = taksit.ayNo;
      if (taksit.brutTutar > 0 && taksit.brutTutar != matrah) {
        _58kOzelTaksitTutari = taksit.brutTutar;
        _58kOzelTaksitController.text = TurkceFormat.para(taksit.brutTutar).replaceAll('₺', '').trim();
      }
    } else {
      _58kAktifTaksitNo = 1;
      _58kOzelTaksitTutari = null;
      _58kOzelTaksitController.clear();
    }

    final dBaslangic = DateTime(
      _58kSozlesmeBaslangic.year,
      _58kSozlesmeBaslangic.month + (_58kAktifTaksitNo - 1),
      _58kSozlesmeBaslangic.day,
    );
    final dBitis = DateTime(
      dBaslangic.year,
      dBaslangic.month + 1,
      dBaslangic.day,
    );
    String f(DateTime dt) => '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    _58kDonemMetni = '${f(dBaslangic)} - ${f(dBitis)}';

    // Personeller
    if (d.personeller.isNotEmpty) {
      _personeller = d.personeller.map((p) {
        return ExcelPersonelGirdi(
          personelId: p.personel.id,
          adSoyad: p.personel.adSoyad,
          unvan: p.personel.unvan,
          puan: p.payOrani > 0 ? p.payOrani.toDouble() : (p.faaliyetPuani > 0 ? p.faaliyetPuani : 100.0),
          unvanKatsayisi: p.personel.unvanKatsayisi > 0 ? p.personel.unvanKatsayisi : 2.0,
          ekGosterge: DanismanlikExcelHesaplama.ekGosterge(p.personel.unvan),
          dersSaati: p.dersSaati > 0 ? p.dersSaati : 1.0,
          mesaiIci: p.mesaiIci,
          faaliyetTuru: p.faaliyetTuru ?? (_aktifSablonTuru == 'usem' || _aktifSablonTuru == 'tomer' ? 'Kurs/Eğitim' : 'Danışmanlık'),
        );
      }).toList();
    } else {
      _personeller = [];
    }

    _manuelKatsayiAktif = false;
    _manuelKatsayiController.clear();
    _memurMaasKatsayisiController.text = _memurMaasKatsayisi.toString();
  }

  void _varsayilanOrnekYukle() {
    // Neslihan Hoca DTS Örneği (Kullanıcının Excel ekran görüntüsündeki veriler)
    setState(() {
      _aktifKayitId = '';
      _satirlar = [
        ManuelListeSatiri(
          sn: 1,
          tc: '',
          aciklama: 'Fatura Kesilenlerin Listesi',
          tutar: 9600.0,
        ),
        for (int i = 2; i <= 13; i++)
          ManuelListeSatiri(sn: i, tc: '', aciklama: '', tutar: 0.0),
      ];

      _personeller = [
        const ExcelPersonelGirdi(
          personelId: '1',
          adSoyad: 'Neslihan ÖPÖZ VURAL',
          unvan: 'Öğr. Gör. Dr.',
          puan: 20.0,
          unvanKatsayisi: 2.0,
          ekGosterge: 160,
          dersSaati: 5.0,
          mesaiIci: false, // Mesai Dışı
          faaliyetTuru: 'Danışmanlık',
        ),
      ];

      _aktifSablonTuru = 'dts';
      _manuelKatsayiAktif = false;
      _manuelKatsayiController.clear();
      _memurMaasKatsayisiController.text = _memurMaasKatsayisi.toString();
    });
  }

  void _ornek58kSablonuYukle() {
    // 2547 Sayılı Kanun Madde 58/k - DONGSAN Deniz Gürler Örneği (Kullanıcının Gönderdiği Excel)
    setState(() {
      _aktifSablonTuru = '58k';
      _aktifKayitId = '';
      _kurumController.text = 'T.C.\nUŞAK ÜNİVERSİTESİ REKTÖRLÜĞÜ';
      _rektorlukController.text = 'DÖNER SERMAYE İŞLETME MÜDÜRLÜĞÜ';
      _mudurlukController.text = 'DÖNER SERMAYE İŞLETME MÜDÜRLÜĞÜ';
      _hizmetBasligiController.text = 'DONGSAN DANIŞMANLIK HİZMET GELİRİ HESAPLAMA TABLOSU';
      _kdvOrani = 20;
      _hazineOrani = 0;
      _bapOrani = 0;
      _aracGerecOrani = 0.15; // %15 A.G.P. -> Kalan %85 Katkı Payı!
      _satirlar = [
        ManuelListeSatiri(
          sn: 1,
          tc: '',
          aciklama: 'DONGSAN Danışmanlık Hizmet Geliri',
          tutar: 4205.62, // KDV Dahil Brüt Tutar -> Matrah 3.504,68 TL
        ),
        for (int i = 2; i <= 10; i++)
          ManuelListeSatiri(sn: i, tc: '', aciklama: '', tutar: 0.0),
      ];
      _personeller = [
        const ExcelPersonelGirdi(
          personelId: '1',
          adSoyad: 'Dr. Deniz GÜRLER',
          unvan: 'Dr. Öğr. Üyesi',
          puan: 20.0,
          unvanKatsayisi: 2.0,
          ekGosterge: 200,
          dersSaati: 1.0,
          mesaiIci: false,
          faaliyetTuru: 'Danışmanlık',
        ),
      ];
      _manuelKatsayiAktif = false;
      _manuelKatsayiController.clear();
      _memurMaasKatsayisiController.text = _memurMaasKatsayisi.toString();
      _58kOdemeTekSeferde = false;
      _58kToplamTaksitSayisi = 3;
      _58kAktifTaksitNo = 1;
      _58kSozlesmeBaslangic = DateTime(2026, 7, 24);
      _58kDonemMetni = '24.07.2026 - 24.08.2026';
      _58kOzelTaksitTutari = null;
      _58kOzelTaksitController.clear();
    });
  }

  void _ornek58eSablonuYukle() {
    // 2547 Sayılı Kanun Madde 58/e - Üniversite İmkânları Kullanılmaksızın Danışmanlık ve Hizmet Geliri
    setState(() {
      _aktifSablonTuru = '58e';
      _aktifKayitId = '';
      _kurumController.text = 'T.C.\nUŞAK ÜNİVERSİTESİ REKTÖRLÜĞÜ';
      _rektorlukController.text = 'DÖNER SERMAYE İŞLETME MÜDÜRLÜĞÜ';
      _mudurlukController.text = 'DÖNER SERMAYE İŞLETME MÜDÜRLÜĞÜ';
      _hizmetBasligiController.text = '2547 SAYILI KANUN MADDE 58/e DANIŞMANLIK VE HİZMET GELİRİ DAĞITIM CETVELİ';
      _kdvOrani = 20;
      _hazineOrani = 1;
      _bapOrani = 5;
      _aracGerecOrani = 0.15; // Kullanıcının istediği gibi düzenlenebilir (%15 varsayılan -> Kalan %79 Dağıtılabilir Pay)
      _gelirVergisiOrani = 15;
      _satirlar = [
        ManuelListeSatiri(
          sn: 1,
          tc: '',
          aciklama: '2547 Madde 58/e Danışmanlık Hizmet Geliri',
          tutar: 10000.0,
        ),
        for (int i = 2; i <= 10; i++)
          ManuelListeSatiri(sn: i, tc: '', aciklama: '', tutar: 0.0),
      ];
      _personeller = [
        const ExcelPersonelGirdi(
          personelId: '1',
          adSoyad: '',
          unvan: 'Prof. Dr.',
          puan: 20.0,
          unvanKatsayisi: 3.0,
          ekGosterge: 300,
          dersSaati: 10.0,
          mesaiIci: false,
          faaliyetTuru: '2547 Madde 58/e Danışmanlık',
        ),
      ];
      _manuelKatsayiAktif = false;
      _manuelKatsayiController.clear();
      _memurMaasKatsayisiController.text = _memurMaasKatsayisi.toString();
      _58kOdemeTekSeferde = true;
      _58kToplamTaksitSayisi = 3;
      _58kAktifTaksitNo = 1;
      _58kSozlesmeBaslangic = DateTime.now();
      _58kDonemMetni = '';
      _58kOzelTaksitTutari = null;
      _58kOzelTaksitController.clear();
    });
  }

  void _ornekUsemSablonuYukle() {
    setState(() {
      _aktifSablonTuru = 'usem';
      _aktifKayitId = '';
      _kurumController.text = 'T.C.\nUŞAK ÜNİVERSİTESİ REKTÖRLÜĞÜ';
      _rektorlukController.text = 'DÖNER SERMAYE İŞLETME MÜDÜRLÜĞÜ';
      _mudurlukController.text = 'SÜREKLİ EĞİTİM UYGULAMA VE ARAŞTIRMA MERKEZİ (USEM)';
      _hizmetBasligiController.text = 'GENEL İNGİLİZCE KURSU HİZMET GELİRLERİ HESAPLAMA CETVELİ';
      _kdvOrani = 10;
      _hazineOrani = 1;
      _bapOrani = 5;
      _aracGerecOrani = 0.45;
      _satirlar = [
        ManuelListeSatiri(sn: 1, tc: '22787673956', aciklama: 'Cemre ARMAĞAN - Kursiyer Ücreti', tutar: 5000.0),
        ManuelListeSatiri(sn: 2, tc: '49756749382', aciklama: 'Emrah TORUN - Kursiyer Ücreti', tutar: 5000.0),
        ManuelListeSatiri(sn: 3, tc: '31147719722', aciklama: 'Gülistan ERDOĞAN - Kursiyer Ücreti', tutar: 5000.0),
        ManuelListeSatiri(sn: 4, tc: '16355555904', aciklama: 'Hatice A. BULUT - Kursiyer Ücreti', tutar: 5000.0),
      ];
      _personeller = [
        const ExcelPersonelGirdi(
          personelId: '1',
          adSoyad: 'Öğr. Gör. Dilek DURUKAN',
          unvan: 'Öğr. Gör.',
          puan: 16.0,
          unvanKatsayisi: 2.0,
          ekGosterge: 160,
          dersSaati: 52.0,
          mesaiIci: false,
          faaliyetTuru: 'Kurs/Eğitim',
        ),
      ];
      _manuelKatsayiAktif = false;
      _manuelKatsayiController.clear();
      _memurMaasKatsayisiController.text = _memurMaasKatsayisi.toString();
    });
  }

  void _ornekTomerSablonuYukle() {
    setState(() {
      _aktifSablonTuru = 'tomer';
      _aktifKayitId = '';
      _kurumController.text = 'T.C.\nUŞAK ÜNİVERSİTESİ REKTÖRLÜĞÜ';
      _rektorlukController.text = 'DÖNER SERMAYE İŞLETME MÜDÜRLÜĞÜ';
      _mudurlukController.text = 'TÜRKÇE ÖĞRETİMİ UYGULAMA VE ARAŞTIRMA MERKEZİ (TÖMER)';
      _hizmetBasligiController.text = 'YABANCILARA TÜRKÇE ÖĞRETİMİ HİZMET GELİRLERİ HESAPLAMA CETVELİ';
      _kdvOrani = 10;
      _hazineOrani = 1;
      _bapOrani = 5;
      _aracGerecOrani = 0.45;
      _satirlar = [
        ManuelListeSatiri(sn: 1, tc: '', aciklama: 'Türkçe Eğitimi Kurs Geliri', tutar: 15000.0),
      ];
      _personeller = [
        const ExcelPersonelGirdi(
          personelId: '1',
          adSoyad: 'Doç. Dr. Ömer İNCE',
          unvan: 'Doçent',
          puan: 10.0,
          unvanKatsayisi: 2.5,
          ekGosterge: 250,
          dersSaati: 24.0,
          mesaiIci: false,
          faaliyetTuru: 'Türkçe Öğretimi',
        ),
      ];
      _manuelKatsayiAktif = false;
      _manuelKatsayiController.clear();
      _memurMaasKatsayisiController.text = _memurMaasKatsayisi.toString();
    });
  }

  void _ornekDosimSablonuYukle() {
    setState(() {
      _aktifSablonTuru = 'dosim';
      _aktifKayitId = '';
      _kurumController.text = 'T.C.\nUŞAK ÜNİVERSİTESİ REKTÖRLÜĞÜ';
      _rektorlukController.text = 'DÖNER SERMAYE İŞLETME MÜDÜRLÜĞÜ';
      _mudurlukController.text = 'DÖNER SERMAYE İŞLETME MÜDÜRLÜĞÜ';
      _hizmetBasligiController.text = 'UZER MAKİNA DANIŞMANLIK HİZMET GELİRİ HESAPLAMA TABLOSU';
      _kdvOrani = 20;
      _hazineOrani = 1;
      _bapOrani = 5;
      _aracGerecOrani = 0.45;
      _satirlar = [
        ManuelListeSatiri(sn: 1, tc: '', aciklama: 'Uzer Makina Sanayi Danışmanlığı', tutar: 36000.0),
      ];
      _personeller = [
        const ExcelPersonelGirdi(
          personelId: '1',
          adSoyad: 'Prof. Dr. Osman ASİLAN',
          unvan: 'Profesör',
          puan: 20.0,
          unvanKatsayisi: 3.0,
          ekGosterge: 300,
          dersSaati: 10.0,
          mesaiIci: false,
          faaliyetTuru: 'Danışmanlık',
        ),
      ];
      _manuelKatsayiAktif = false;
      _manuelKatsayiController.clear();
      _memurMaasKatsayisiController.text = _memurMaasKatsayisi.toString();
    });
  }

  void _sablonYukle(String tur) {
    switch (tur.toLowerCase()) {
      case '58k':
        _ornek58kSablonuYukle();
        break;
      case '58e':
        _ornek58eSablonuYukle();
        break;
      case 'usem':
        _ornekUsemSablonuYukle();
        break;
      case 'tomer':
        _ornekTomerSablonuYukle();
        break;
      case 'dosim':
        _ornekDosimSablonuYukle();
        break;
      case 'dts':
      default:
        _varsayilanOrnekYukle();
        break;
    }
  }

  void _bosSablonYukle() {
    setState(() {
      _aktifKayitId = '';
      _satirlar = [
        for (int i = 1; i <= 10; i++)
          ManuelListeSatiri(sn: i, tc: '', aciklama: '', tutar: 0.0),
      ];
      _personeller = [
        const ExcelPersonelGirdi(
          personelId: '1',
          adSoyad: '',
          unvan: 'Öğr. Gör. Dr.',
          puan: 20.0,
          unvanKatsayisi: 2.0,
          ekGosterge: 160,
          dersSaati: 1.0,
          mesaiIci: true,
          faaliyetTuru: 'Danışmanlık',
        ),
      ];
      _manuelKatsayiAktif = false;
      _manuelKatsayiController.clear();
    });
  }

  ManuelHesaplamaVerisi _mevcutVeriOlustur() {
    double? manuelKatsayi;
    if (_manuelKatsayiAktif) {
      manuelKatsayi = double.tryParse(_manuelKatsayiController.text.replaceAll(',', '.').trim());
    }

    return ManuelHesaplamaVerisi(
      kurumAdi: 'T.C.\nUŞAK ÜNİVERSİTESİ REKTÖRLÜĞÜ',
      rektorlukAdi: _rektorlukController.text.trim(),
      mudurlukAdi: _mudurlukController.text.trim(),
      hizmetBasligi: _hizmetBasligiController.text.trim(),
      satirlar: _satirlar.where((s) => s.tutar > 0 || s.aciklama.isNotEmpty).toList(),
      kdvOrani: _kdvOrani,
      hazineOrani: _hazineOrani,
      bapOrani: _bapOrani,
      aracGerecOrani: _aracGerecOrani,
      personeller: _personeller,
      manuelDonemKatsayisi: manuelKatsayi,
      memurMaasKatsayisi: _memurMaasKatsayisi,
      is58k: _aktifSablonTuru == '58k',
      is58e: _aktifSablonTuru == '58e',
      gelirVergisiOrani: _gelirVergisiOrani,
      odemeTekSeferde: _58kOdemeTekSeferde,
      toplamTaksitSayisi: _58kToplamTaksitSayisi,
      aktifTaksitNo: _58kAktifTaksitNo,
      ozelTaksitTutari: _58kOzelTaksitTutari,
      sozlesmeBaslangicTarihi: _58kSozlesmeBaslangic,
      danismanlikDonemi: _58kDonemMetni.isNotEmpty ? _58kDonemMetni : null,
    );
  }

  void _pdfYazdirVeyaIndir() async {
    final veri = _mevcutVeriOlustur();
    final bytes = await ManuelHesaplamaPdfServisi.pdfUret(veri);

    if (!mounted) return;
    await Printing.layoutPdf(
      onLayout: (_) => bytes,
      name: 'Manuel_Hesaplama_Ozet_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  Future<void> _cokluPersonelEkle() async {
    final yeniPersoneller = await CokluPersonelEkleDialog.goster(
      context,
      mevcutPersonelSayisi: _personeller.length,
    );

    if (yeniPersoneller != null && yeniPersoneller.isNotEmpty && mounted) {
      setState(() {
        // Eğer mevcut listede sadece tek bir boş kayıt varsa, onu doğrudan ezebiliriz
        if (_personeller.length == 1 && _personeller.first.adSoyad.trim().isEmpty) {
          _personeller = List.from(yeniPersoneller);
        } else {
          _personeller.addAll(yeniPersoneller);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${yeniPersoneller.length} personel başarıyla listeye eklendi!'),
          backgroundColor: const Color(0xFF107C41),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final veri = _mevcutVeriOlustur();
    final kesinti = veri.kesintiSonuc;
    final excel = veri.excelSonuc;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Üst Bar
          DanismanlikLayout.kompaktBaslik(
            baslik: 'Manuel Hesaplama',
            altBaslik: 'Excel formatında (Liste · Dağ. Maks. Pay · Katkı Payı · İcmal Özeti)',
            aksiyon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<String>(
                  tooltip: 'Şablon Değiştir',
                  onSelected: _sablonYukle,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'dts',
                      child: Row(
                        children: [
                          Icon(Icons.palette_outlined, size: 16, color: Color(0xFF0F766E)),
                          SizedBox(width: 8),
                          Text('DTS Danışmanlık (Neslihan Hoca)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: '58k',
                      child: Row(
                        children: [
                          Icon(Icons.gavel_outlined, size: 16, color: Color(0xFF2563EB)),
                          SizedBox(width: 8),
                          Text('2547 Madde 58/k (DONGSAN - %15 A.G.P. / %85 Pay)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: '58e',
                      child: Row(
                        children: [
                          Icon(Icons.gavel_rounded, size: 16, color: Color(0xFF4F46E5)),
                          SizedBox(width: 8),
                          Text('2547 Madde 58/e (%1 Hazine · %5 BAP · %15 Birim)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'usem',
                      child: Row(
                        children: [
                          Icon(Icons.school_outlined, size: 16, color: Color(0xFF7C3AED)),
                          SizedBox(width: 8),
                          Text('USEM Kurs & Sertifika (%10 KDV)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'tomer',
                      child: Row(
                        children: [
                          Icon(Icons.language_outlined, size: 16, color: Color(0xFFD97706)),
                          SizedBox(width: 8),
                          Text('TÖMER Dil Eğitimi (%10 KDV)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _sablonRengi(_aktifSablonTuru)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tune, size: 15, color: _sablonRengi(_aktifSablonTuru)),
                        const SizedBox(width: 6),
                        Text(
                          'Şablon: ${_sablonBasligi(_aktifSablonTuru)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _sablonRengi(_aktifSablonTuru),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, size: 18, color: _sablonRengi(_aktifSablonTuru)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _bosSablonYukle,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Temizle'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _kaydetDialogGoster,
                  icon: const Icon(Icons.save_outlined, size: 16),
                  label: const Text('Kaydet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB), // Blue
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _kayitliHesaplamalarDialogGoster,
                  icon: const Icon(Icons.folder_open_outlined, size: 16),
                  label: const Text('Kayıtlılar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4F46E5),
                    side: const BorderSide(color: Color(0xFF818CF8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _pdfYazdirVeyaIndir,
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text('Yazdır / PDF İndir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF107C41), // Excel Green
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => context.pop(),
                  tooltip: 'Kapat',
                ),
              ],
            ),
          ),

          // Başlık ve Bilgi Düzenleme Barı
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: _mudurlukController,
                    decoration: InputDecoration(
                      labelText: 'Birim / Merkez Müdürlüğü',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: const OutlineInputBorder(),
                      suffixIcon: _birimler.isEmpty
                          ? const Icon(Icons.business_outlined, size: 18, color: Colors.grey)
                          : PopupMenuButton<String>(
                              icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: Color(0xFF107C41), size: 20),
                              tooltip: 'Sistemdeki Birimlerden Seç',
                              onSelected: (secilen) {
                                setState(() {
                                  _mudurlukController.text = secilen;
                                });
                              },
                              itemBuilder: (context) {
                                return _birimler.map((birimAdi) {
                                  return PopupMenuItem<String>(
                                    value: birimAdi,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.apartment, size: 16, color: Color(0xFF107C41)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            birimAdi,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                    ),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: TextFormField(
                    controller: _hizmetBasligiController,
                    decoration: const InputDecoration(
                      labelText: 'Personel ve Hizmet Başlığı',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // Excel Tarzı Sekme Çubuğu
          Container(
            color: const Color(0xFFE2E8F0),
            padding: const EdgeInsets.only(left: 16, top: 4),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              labelColor: const Color(0xFF107C41), // Excel Green
              unselectedLabelColor: const Color(0xFF475569),
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(
                  icon: Icon(Icons.table_chart_outlined, size: 16),
                  text: '1. LİSTE (Gelirler)',
                ),
                Tab(
                  icon: Icon(Icons.pie_chart_outline, size: 16),
                  text: '2. DAĞ. MAKS. PAY',
                ),
                Tab(
                  icon: Icon(Icons.calculate_outlined, size: 16),
                  text: '3. KATKI PAYI HESAPLAMA',
                ),
                Tab(
                  icon: Icon(Icons.summarize_outlined, size: 16),
                  text: '4. YAZDIRILABİLİR İCMAL ÖZETİ',
                ),
              ],
            ),
          ),

          // Sekme İçerikleri
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Sekme 1: LİSTE
                TabListe(
                  satirlar: _satirlar,
                  toplamTutar: veri.toplamTutar,
                  kdvHaricGelir: veri.kdvHaricGelir,
                  kdvTutari: veri.kdvTutari,
                  kdvOrani: _kdvOrani,
                  onSatirEkle: () {
                    setState(() {
                      _satirlar.add(
                        ManuelListeSatiri(sn: _satirlar.length + 1, tc: '', aciklama: '', tutar: 0.0),
                      );
                    });
                  },
                  onSatirSil: (index) {
                    setState(() {
                      _satirlar.removeAt(index);
                      for (int i = 0; i < _satirlar.length; i++) {
                        _satirlar[i].sn = i + 1;
                      }
                    });
                  },
                  onSatirGuncelle: (index, tc, aciklama, tutar) {
                    setState(() {
                      _satirlar[index] = _satirlar[index].copyWith(tc: tc, aciklama: aciklama, tutar: tutar);
                    });
                  },
                  onKdvOraniDegisti: (val) => setState(() => _kdvOrani = val),
                ),

                // Sekme 2: DAĞ. MAKS. PAY
                TabDagMaksPay(
                  kesinti: kesinti,
                  toplamTutar: veri.toplamTutar,
                  kdvTutari: veri.kdvTutari,
                  kdvOrani: _kdvOrani,
                  hazineOrani: _hazineOrani,
                  bapOrani: _bapOrani,
                  aracGerecOrani: _aracGerecOrani,
                  onOranlariGuncelle: (h, b, a) {
                    setState(() {
                      _hazineOrani = h;
                      _bapOrani = b;
                      _aracGerecOrani = a;
                    });
                  },
                ),

                // Sekme 3: KATKI PAYI
                TabKatkiPayi(
                  excelSonuc: excel,
                  personeller: _personeller,
                  maksAkademikPay: kesinti.dagMaksAkademikPay,
                  manuelKatsayiController: _manuelKatsayiController,
                  manuelKatsayiAktif: _manuelKatsayiAktif,
                  onManuelKatsayiDegisti: (val) => setState(() => _manuelKatsayiAktif = val),
                  memurMaasKatsayisi: _memurMaasKatsayisi,
                  memurMaasKatsayisiController: _memurMaasKatsayisiController,
                  onMemurMaasKatsayisiDegisti: (val) {
                    setState(() {
                      _memurMaasKatsayisi = val;
                    });
                  },
                  onMemurMaasKatsayisiKaydet: _memurMaasKatsayisiKaydet,
                  onPersonelEkle: () {
                    setState(() {
                      _personeller.add(
                        ExcelPersonelGirdi(
                          personelId: '${_personeller.length + 1}',
                          adSoyad: '',
                          unvan: 'Öğr. Gör. Dr.',
                          puan: 20.0,
                          unvanKatsayisi: 2.0,
                          ekGosterge: 160,
                          dersSaati: 5.0,
                          mesaiIci: false,
                          faaliyetTuru: 'Danışmanlık',
                        ),
                      );
                    });
                  },
                  onCokluPersonelEkle: _cokluPersonelEkle,
                  onPersonelSil: (index) {
                    setState(() {
                      _personeller.removeAt(index);
                    });
                  },
                  onPersonelGuncelle: (int index, ExcelPersonelGirdi girdi) {
                    setState(() {
                      _personeller[index] = girdi;
                    });
                  },
                  is58k: _aktifSablonTuru == '58k',
                  is58e: _aktifSablonTuru == '58e',
                  gelirVergisiOrani: _gelirVergisiOrani,
                  onGelirVergisiOraniDegisti: (val) => setState(() => _gelirVergisiOrani = val),
                  odemeTekSeferde: _58kOdemeTekSeferde,
                  toplamTaksitSayisi: _58kToplamTaksitSayisi,
                  aktifTaksitNo: _58kAktifTaksitNo,
                  ozelTaksitTutari: _58kOzelTaksitTutari,
                  ozelTaksitController: _58kOzelTaksitController,
                  kesinti: kesinti,
                  onOdemeTekSeferdeDegisti: (val) => setState(() => _58kOdemeTekSeferde = val),
                  onToplamTaksitSayisiDegisti: (val) => setState(() => _58kToplamTaksitSayisi = val),
                  onAktifTaksitNoDegisti: (val) {
                    setState(() {
                      _58kAktifTaksitNo = val;
                      final s = ManuelHesaplamaVerisi.addMonths(_58kSozlesmeBaslangic, val - 1);
                      final e = ManuelHesaplamaVerisi.addMonths(_58kSozlesmeBaslangic, val);
                      _58kDonemMetni = '${TurkceFormat.tarih(s)} - ${TurkceFormat.tarih(e)}';
                    });
                  },
                  onOzelTaksitTutariDegisti: (val) => setState(() => _58kOzelTaksitTutari = val),
                  sozlesmeBaslangicTarihi: _58kSozlesmeBaslangic,
                  danismanlikDonemi: _58kDonemMetni,
                  onSozlesmeBaslangicDegisti: (val) {
                    setState(() {
                      _58kSozlesmeBaslangic = val;
                      final s = ManuelHesaplamaVerisi.addMonths(val, _58kAktifTaksitNo - 1);
                      final e = ManuelHesaplamaVerisi.addMonths(val, _58kAktifTaksitNo);
                      _58kDonemMetni = '${TurkceFormat.tarih(s)} - ${TurkceFormat.tarih(e)}';
                    });
                  },
                  onDanismanlikDonemiDegisti: (val) => setState(() => _58kDonemMetni = val),
                ),

                // Sekme 4: ÖZET İCMAL
                TabOzetIcmal(
                  veri: veri,
                  onYazdir: _pdfYazdirVeyaIndir,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
