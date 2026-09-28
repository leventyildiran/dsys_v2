import 'package:flutter/material.dart';
import 'package:dsys_v2/features/personel/models/personel_model.dart';
import 'package:dsys_v2/features/personel/services/personel_service.dart';
import 'package:dsys_v2/features/danismanlik/services/danismanlik_excel_hesaplama.dart';
import 'tab_katki_payi.dart';

/// Birleşik Kişi / Hoca Ekleme Diyaloğu.
/// 2 mod sunar:
/// 1. Sistemdeki personellerden toplu arama ve seçim
/// 2. Elle yeni hoca ekleme (sisteme kalıcı kaydetme imkânıyla) veya toplu isim yapıştırma
class CokluPersonelEkleDialog extends StatefulWidget {
  const CokluPersonelEkleDialog({
    super.key,
    this.mevcutPersonelSayisi = 0,
    this.is58kOrE = false,
  });

  final int mevcutPersonelSayisi;
  final bool is58kOrE;

  static Future<List<ExcelPersonelGirdi>?> goster(
    BuildContext context, {
    int mevcutPersonelSayisi = 0,
    bool is58kOrE = false,
  }) {
    return showDialog<List<ExcelPersonelGirdi>>(
      context: context,
      builder: (ctx) => CokluPersonelEkleDialog(
        mevcutPersonelSayisi: mevcutPersonelSayisi,
        is58kOrE: is58kOrE,
      ),
    );
  }

  @override
  State<CokluPersonelEkleDialog> createState() => _CokluPersonelEkleDialogState();
}

class _CokluPersonelEkleDialogState extends State<CokluPersonelEkleDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final PersonelService _personelService = PersonelService();

  List<PersonelModel> _sistemPersonelleri = [];
  final Set<String> _secilenPersonelIdleri = {};
  String _aramaMetni = '';
  bool _yukleniyor = true;

  late final TextEditingController _varsayilanPuanController;
  late final TextEditingController _varsayilanSaatController;
  bool _varsayilanMesaiIci = false;

  // Elle Yeni Hoca Ekleme Alanları
  final TextEditingController _yeniAdSoyadController = TextEditingController();
  final TextEditingController _yeniBirimController = TextEditingController();
  late final TextEditingController _yeniPuanController;
  late final TextEditingController _yeniSaatController;
  String _yeniUnvan = 'Dr. Öğr. Üyesi';
  bool _yeniMesaiIci = false;
  bool _sistemeKaydet = true; // Yeni hoca sisteme kalıcı kaydedilsin mi?

  // Toplu Yapıştırma Alanları
  final TextEditingController _metinController = TextEditingController();
  bool _yapistirilanlariKaydet = false;

  @override
  void initState() {
    super.initState();
    _varsayilanPuanController =
        TextEditingController(text: widget.is58kOrE ? '100' : '20');
    _varsayilanSaatController =
        TextEditingController(text: widget.is58kOrE ? '1' : '5');

    _yeniPuanController =
        TextEditingController(text: widget.is58kOrE ? '100' : '20');
    _yeniSaatController =
        TextEditingController(text: widget.is58kOrE ? '1' : '5');
    _yeniUnvan = widget.is58kOrE ? 'Dr. Öğr. Üyesi' : 'Öğr. Gör. Dr.';

    _tabController = TabController(length: 2, vsync: this);
    _personelleriYukle();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _varsayilanPuanController.dispose();
    _varsayilanSaatController.dispose();
    _yeniAdSoyadController.dispose();
    _yeniBirimController.dispose();
    _yeniPuanController.dispose();
    _yeniSaatController.dispose();
    _metinController.dispose();
    super.dispose();
  }

  Future<void> _personelleriYukle() async {
    try {
      final list = await _personelService.getAll(sadeceAktif: true);
      if (mounted) {
        setState(() {
          _sistemPersonelleri = list;
          _yukleniyor = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _yukleniyor = false);
      }
    }
  }

  double get _varsayilanPuan =>
      double.tryParse(_varsayilanPuanController.text.trim()) ?? 20.0;
  double get _varsayilanSaat =>
      double.tryParse(_varsayilanSaatController.text.trim()) ?? 5.0;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 760,
        height: 640,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Üst Başlık & Kapat
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF107C41).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person_add_alt_1, color: Color(0xFF107C41), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kişi / Hoca Ekle',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      Text(
                        'Sistemdeki hocalardan seçin veya yeni hoca ismi girip doğrudan kaydedin.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: 'Kapat',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2'li Sekme Çubuğu (Hazır Kurullar kaldırıldı)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                    ),
                  ],
                ),
                labelColor: const Color(0xFF107C41),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                tabs: const [
                  Tab(icon: Icon(Icons.school_outlined, size: 17), text: 'Sistemdeki Hocalardan Seç'),
                  Tab(icon: Icon(Icons.edit_note_outlined, size: 17), text: 'Elle Yeni Hoca Ekle / Yapıştır'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Sekme İçerikleri
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSistemPersonelleriSekmesi(),
                  _buildManuelVeYapistirSekmesi(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SEKME 1: SİSTEMDEKİ HOCALARDAN SEÇ
  // ─────────────────────────────────────────────────────────────
  Widget _buildSistemPersonelleriSekmesi() {
    if (_yukleniyor) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Üniversite akademik personelleri yükleniyor...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    final filtreli = _sistemPersonelleri.where((p) {
      if (_aramaMetni.isEmpty) return true;
      final q = _aramaMetni.toLowerCase();
      final ad = p.adSoyad.toLowerCase();
      final unvan = p.unvan.toLowerCase();
      final birim = (p.birimAdi ?? p.birimId).toLowerCase();
      return ad.contains(q) || unvan.contains(q) || birim.contains(q);
    }).toList();

    return Column(
      children: [
        // Varsayılan Puan & Saat Barı
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.tune, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              const Text(
                'Varsayılan Değerler:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
              ),
              const Spacer(),
              Text(widget.is58kOrE ? 'Sözleşme Payı (%):' : 'Puan:', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              SizedBox(
                width: 55,
                height: 28,
                child: TextField(
                  controller: _varsayilanPuanController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              if (!widget.is58kOrE) ...[
                const SizedBox(width: 12),
                const Text('Saat:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                SizedBox(
                  width: 45,
                  height: 28,
                  child: TextField(
                    controller: _varsayilanSaatController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => setState(() => _varsayilanMesaiIci = !_varsayilanMesaiIci),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _varsayilanMesaiIci ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _varsayilanMesaiIci ? const Color(0xFFBFDBFE) : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Text(
                      _varsayilanMesaiIci ? 'Mesai İçi (2.0x)' : 'Mesai Dışı (3.2x)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _varsayilanMesaiIci ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Arama ve Tümünü Seç
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Hoca adı, unvan veya birim ile ara...',
                    prefixIcon: Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 12.5),
                  onChanged: (val) => setState(() => _aramaMetni = val.trim()),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  if (_secilenPersonelIdleri.length == filtreli.length) {
                    _secilenPersonelIdleri.clear();
                  } else {
                    _secilenPersonelIdleri.addAll(filtreli.map((e) => e.id));
                  }
                });
              },
              child: Text(
                _secilenPersonelIdleri.length == filtreli.length
                    ? 'Seçimi Kaldır'
                    : 'Tümünü Seç (${filtreli.length})',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Personel Listesi
        Expanded(
          child: filtreli.isEmpty
              ? Center(
                  child: Text(
                    _sistemPersonelleri.isEmpty
                        ? 'Sistemde henüz kayıtlı akademik personel bulunmuyor.\n"Elle Yeni Hoca Ekle" sekmesini kullanarak ekleyebilirsiniz.'
                        : 'Aramaya uygun personel bulunamadı.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
                  ),
                )
              : ListView.separated(
                  itemCount: filtreli.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = filtreli[index];
                    final secili = _secilenPersonelIdleri.contains(p.id);
                    final unvanNorm = TabKatkiPayi.unvanNormalize(p.unvan);
                    final ekGosterge = DanismanlikExcelHesaplama.ekGosterge(unvanNorm);
                    final birimMetni = p.birimAdi?.isNotEmpty == true
                        ? p.birimAdi!
                        : (p.birimId.isNotEmpty ? p.birimId : 'Birim Belirtilmemiş');

                    return CheckboxListTile(
                      value: secili,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _secilenPersonelIdleri.add(p.id);
                          } else {
                            _secilenPersonelIdleri.remove(p.id);
                          }
                        });
                      },
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      title: Text(
                        '${unvanNorm.isNotEmpty ? "$unvanNorm " : ""}${p.adSoyad}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B)),
                      ),
                      subtitle: Text(
                        'Birim: $birimMetni  •  Unvan Katsayısı: ${p.unvanKatsayisi.toStringAsFixed(1)}  •  Ek Gösterge: $ekGosterge',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      secondary: CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF107C41).withValues(alpha: 0.1),
                        child: Text(
                          p.adSoyad.isNotEmpty ? p.adSoyad[0].toUpperCase() : '?',
                          style: const TextStyle(color: Color(0xFF107C41), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 10),

        // Alt Ekleme Barı
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_secilenPersonelIdleri.length} hoca seçildi',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF107C41)),
            ),
            ElevatedButton.icon(
              onPressed: _secilenPersonelIdleri.isEmpty ? null : _sistemSecilenleriEkle,
              icon: const Icon(Icons.add, size: 16),
              label: Text('Seçilenleri Listeye Ekle (${_secilenPersonelIdleri.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF107C41),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _sistemSecilenleriEkle() {
    final secilenler = _sistemPersonelleri
        .where((p) => _secilenPersonelIdleri.contains(p.id))
        .toList();

    int baslangicSn = widget.mevcutPersonelSayisi + 1;
    final List<ExcelPersonelGirdi> sonuclar = [];

    for (final p in secilenler) {
      final unvanNorm = TabKatkiPayi.unvanNormalize(p.unvan);
      final unvanK = DanismanlikExcelHesaplama.unvanKatsayisi(unvanNorm, p.unvanKatsayisi);
      final ekGosterge = DanismanlikExcelHesaplama.ekGosterge(unvanNorm);

      sonuclar.add(
        ExcelPersonelGirdi(
          personelId: '${baslangicSn++}',
          adSoyad: p.adSoyad,
          unvan: unvanNorm,
          puan: _varsayilanPuan,
          unvanKatsayisi: unvanK,
          ekGosterge: ekGosterge,
          dersSaati: _varsayilanSaat,
          mesaiIci: _varsayilanMesaiIci,
          faaliyetTuru: 'Danışmanlık',
        ),
      );
    }

    Navigator.pop(context, sonuclar);
  }

  // ─────────────────────────────────────────────────────────────
  // SEKME 2: ELLE YENİ HOCA EKLE / YAPIŞTIR (VE SİSTEME KAYDET)
  // ─────────────────────────────────────────────────────────────
  Widget _buildManuelVeYapistirSekmesi() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // KART 1: TEK KİŞİ ELLE GİRİŞ FORMU
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 20, color: Color(0xFF107C41)),
                    const SizedBox(width: 8),
                    const Text(
                      'Tek Hoca Girişi',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1E293B)),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _tekBosSatirEkle,
                      icon: const Icon(Icons.add, size: 15),
                      label: const Text('Tabloya Boş Satır Aç', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Unvan & Ad Soyad Satırı
                Row(
                  children: [
                    // Unvan Dropdown
                    SizedBox(
                      width: 170,
                      child: DropdownButtonFormField<String>(
                        initialValue: _yeniUnvan,
                        isDense: true,
                        decoration: const InputDecoration(
                          labelText: 'Unvan',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: TabKatkiPayi.unvanListesi.map((u) {
                          return DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12)));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _yeniUnvan = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Adı Soyadı
                    Expanded(
                      child: TextField(
                        controller: _yeniAdSoyadController,
                        decoration: const InputDecoration(
                          labelText: 'Adı Soyadı',
                          hintText: 'Örn: Ahmet YILMAZ',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Birim, Puan, Saat ve Mesai
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _yeniBirimController,
                        decoration: const InputDecoration(
                          labelText: 'Birim / Fakülte / Merkez (İsteğe Bağlı)',
                          hintText: 'Örn: DTS Merkezi, Mühendislik',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 70,
                      child: TextField(
                        controller: _yeniPuanController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: widget.is58kOrE ? 'Pay %' : 'Puan',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (!widget.is58kOrE) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: _yeniSaatController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            labelText: 'Saat',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                          ),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => setState(() => _yeniMesaiIci = !_yeniMesaiIci),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: _yeniMesaiIci ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _yeniMesaiIci ? const Color(0xFFBFDBFE) : const Color(0xFFFDE68A),
                            ),
                          ),
                          child: Text(
                            _yeniMesaiIci ? 'Mesai İçi' : 'Mesai Dışı',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _yeniMesaiIci ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Sisteme Kalıcı Kaydetme Checkbox'ı & Buton
                Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _sistemeKaydet = !_sistemeKaydet),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: _sistemeKaydet,
                            activeColor: const Color(0xFF107C41),
                            onChanged: (val) => setState(() => _sistemeKaydet = val ?? true),
                          ),
                          const Text(
                            '💾 Bu hocayı sistem personel rehberine de kaydet',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _manuelTekPersonelEkle,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Bu Hocayı Listeye Ekle'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF107C41),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // KART 2: TOPLU İSİM YAPIŞTIRMA
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.content_paste_outlined, size: 20, color: Color(0xFF4F46E5)),
                    SizedBox(width: 8),
                    Text(
                      'Toplu İsim Yapıştır',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Alt alta birden fazla hoca adı yapıştırın. Unvan otomatik tespit edilir (Örn: Prof. Dr. Ahmet Yılmaz, Doç. Dr. Ali Vural).',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 110,
                  child: TextField(
                    controller: _metinController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      hintText: "Örnek (alt alta):\nProf. Dr. Ahmet YILMAZ\nDoç. Dr. Eren ÖNER\nÖğr. Gör. Dr. Neslihan ÖPÖZ VURAL\nNilüfer ÜNAY ÇUBUKÇU",
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.all(10),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _yapistirilanlariKaydet = !_yapistirilanlariKaydet),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: _yapistirilanlariKaydet,
                            activeColor: const Color(0xFF4F46E5),
                            onChanged: (val) => setState(() => _yapistirilanlariKaydet = val ?? false),
                          ),
                          const Text(
                            '💾 Yapıştırılan yeni hocaları sisteme de kaydet',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _metindenPersonelleriAyristirVeEkle,
                      icon: const Icon(Icons.group_add, size: 16),
                      label: const Text('İsimleri Çözümle ve Ekle'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _tekBosSatirEkle() {
    int baslangicSn = widget.mevcutPersonelSayisi + 1;
    final unvanNorm = TabKatkiPayi.unvanNormalize(_yeniUnvan);
    final unvanK = DanismanlikExcelHesaplama.unvanKatsayisi(unvanNorm);
    final ekGosterge = DanismanlikExcelHesaplama.ekGosterge(unvanNorm);

    final girdi = ExcelPersonelGirdi(
      personelId: '$baslangicSn',
      adSoyad: '',
      unvan: unvanNorm,
      puan: _varsayilanPuan,
      unvanKatsayisi: unvanK,
      ekGosterge: ekGosterge,
      dersSaati: _varsayilanSaat,
      mesaiIci: _varsayilanMesaiIci,
      faaliyetTuru: 'Danışmanlık',
    );

    Navigator.pop(context, [girdi]);
  }

  Future<void> _manuelTekPersonelEkle() async {
    final adSoyad = _yeniAdSoyadController.text.trim();
    if (adSoyad.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen hoca adı ve soyadını giriniz.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final unvanNorm = TabKatkiPayi.unvanNormalize(_yeniUnvan);
    final unvanK = DanismanlikExcelHesaplama.unvanKatsayisi(unvanNorm);
    final ekGosterge = DanismanlikExcelHesaplama.ekGosterge(unvanNorm);
    final birim = _yeniBirimController.text.trim();

    if (_sistemeKaydet) {
      try {
        final p = PersonelModel(
          id: '',
          adSoyad: adSoyad,
          unvan: unvanNorm,
          unvanKatsayisi: unvanK,
          birimId: birim,
          birimAdi: birim.isNotEmpty ? birim : null,
          personelTuru: 'Akademik',
          kaynak: 'manuel',
          aktif: true,
        );
        await _personelService.add(p);
      } catch (e) {
        debugPrint('[CokluPersonelEkleDialog] Sisteme kayıt hatası: $e');
      }
    }

    int baslangicSn = widget.mevcutPersonelSayisi + 1;
    final girdi = ExcelPersonelGirdi(
      personelId: '$baslangicSn',
      adSoyad: adSoyad,
      unvan: unvanNorm,
      puan: double.tryParse(_yeniPuanController.text.trim()) ?? _varsayilanPuan,
      unvanKatsayisi: unvanK,
      ekGosterge: ekGosterge,
      dersSaati: double.tryParse(_yeniSaatController.text.trim()) ?? _varsayilanSaat,
      mesaiIci: _yeniMesaiIci,
      faaliyetTuru: 'Danışmanlık',
    );

    if (mounted) {
      Navigator.pop(context, [girdi]);
    }
  }

  Future<void> _metindenPersonelleriAyristirVeEkle() async {
    final metin = _metinController.text.trim();
    if (metin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen yapıştırılacak isimleri giriniz.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final satirlar = metin
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    int baslangicSn = widget.mevcutPersonelSayisi + 1;
    final List<ExcelPersonelGirdi> sonuclar = [];

    for (var s in satirlar) {
      s = s.replaceAll(RegExp(r'^\d+[\.\-\)]\s*'), '').trim();

      String unvan = 'Öğr. Gör. Dr.';
      String adSoyad = s;

      final sLower = s.toLowerCase();
      if (sLower.contains('prof. dr.') || sLower.contains('prof.dr.') || sLower.contains('prof')) {
        unvan = 'Profesör';
        adSoyad = s.replaceAll(RegExp(r'prof\.?\s*dr\.?', caseSensitive: false), '').replaceAll(RegExp(r'prof\.?', caseSensitive: false), '').trim();
      } else if (sLower.contains('doç. dr.') || sLower.contains('doc. dr.') || sLower.contains('doç.') || sLower.contains('doc.')) {
        unvan = 'Doçent';
        adSoyad = s.replaceAll(RegExp(r'doç\.?\s*dr\.?', caseSensitive: false), '').replaceAll(RegExp(r'doc\.?\s*dr\.?', caseSensitive: false), '').replaceAll(RegExp(r'doç\.?', caseSensitive: false), '').replaceAll(RegExp(r'doc\.?', caseSensitive: false), '').trim();
      } else if (sLower.contains('dr. öğr. üyesi') || sLower.contains('dr. ogr. uyesi') || sLower.contains('dr.öğr.üyesi') || sLower.contains('yrd. doç.')) {
        unvan = 'Dr. Öğr. Üyesi';
        adSoyad = s.replaceAll(RegExp(r'dr\.?\s*öğr\.?\s*üyesi\.?', caseSensitive: false), '').replaceAll(RegExp(r'dr\.?\s*ogr\.?\s*uyesi\.?', caseSensitive: false), '').replaceAll(RegExp(r'yrd\.?\s*doç\.?\s*dr\.?', caseSensitive: false), '').trim();
      } else if (sLower.contains('öğr. gör. dr.') || sLower.contains('ogr. gor. dr.') || sLower.contains('öğretim görevlisi dr.')) {
        unvan = 'Öğr. Gör. Dr.';
        adSoyad = s.replaceAll(RegExp(r'öğr\.?\s*gör\.?\s*dr\.?', caseSensitive: false), '').replaceAll(RegExp(r'ogr\.?\s*gor\.?\s*dr\.?', caseSensitive: false), '').replaceAll(RegExp(r'öğretim\s*görevlisi\s*dr\.?', caseSensitive: false), '').trim();
      } else if (sLower.contains('öğr. gör.') || sLower.contains('ogr. gor.') || sLower.contains('öğretim görevlisi')) {
        unvan = 'Öğr. Gör.';
        adSoyad = s.replaceAll(RegExp(r'öğr\.?\s*gör\.?', caseSensitive: false), '').replaceAll(RegExp(r'ogr\.?\s*gor\.?', caseSensitive: false), '').replaceAll(RegExp(r'öğretim\s*görevlisi', caseSensitive: false), '').trim();
      } else if (sLower.contains('arş. gör.') || sLower.contains('ars. gor.') || sLower.contains('araştırma görevlisi')) {
        unvan = 'Arş. Gör.';
        adSoyad = s.replaceAll(RegExp(r'arş\.?\s*gör\.?', caseSensitive: false), '').replaceAll(RegExp(r'ars\.?\s*gor\.?', caseSensitive: false), '').replaceAll(RegExp(r'araştırma\s*görevlisi', caseSensitive: false), '').trim();
      } else if (sLower.contains('dr.')) {
        unvan = 'Öğr. Gör. Dr.';
        adSoyad = s.replaceAll(RegExp(r'dr\.?', caseSensitive: false), '').trim();
      }

      final unvanNorm = TabKatkiPayi.unvanNormalize(unvan);
      final unvanK = DanismanlikExcelHesaplama.unvanKatsayisi(unvanNorm);
      final ekGosterge = DanismanlikExcelHesaplama.ekGosterge(unvanNorm);

      if (_yapistirilanlariKaydet && adSoyad.isNotEmpty) {
        try {
          final p = PersonelModel(
            id: '',
            adSoyad: adSoyad,
            unvan: unvanNorm,
            unvanKatsayisi: unvanK,
            birimId: '',
            personelTuru: 'Akademik',
            kaynak: 'manuel',
            aktif: true,
          );
          await _personelService.add(p);
        } catch (_) {}
      }

      sonuclar.add(
        ExcelPersonelGirdi(
          personelId: '${baslangicSn++}',
          adSoyad: adSoyad,
          unvan: unvanNorm,
          puan: _varsayilanPuan,
          unvanKatsayisi: unvanK,
          ekGosterge: ekGosterge,
          dersSaati: _varsayilanSaat,
          mesaiIci: _varsayilanMesaiIci,
          faaliyetTuru: 'Danışmanlık',
        ),
      );
    }

    if (sonuclar.isNotEmpty && mounted) {
      Navigator.pop(context, sonuclar);
    }
  }
}
