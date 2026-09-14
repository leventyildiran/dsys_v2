import 'package:flutter/material.dart';
import 'package:dsys_v2/features/personel/models/personel_model.dart';
import 'package:dsys_v2/features/personel/services/personel_service.dart';
import 'package:dsys_v2/features/danismanlik/services/danismanlik_excel_hesaplama.dart';

/// Coklu personel ekleme diyalogu.
/// 3 mod sunar:
/// 1. Sistemdeki personellerden toplu secim (Checkbox ile)
/// 2. Toplu isim/metin yapistirma (alt alta isimler)
/// 3. Hazir heyet/kurul sablonlari (Orn: DTS 5 Kisilik Bilirkisi Heyeti)
class CokluPersonelEkleDialog extends StatefulWidget {
  const CokluPersonelEkleDialog({
    super.key,
    this.mevcutPersonelSayisi = 0,
  });

  final int mevcutPersonelSayisi;

  static Future<List<ExcelPersonelGirdi>?> goster(
    BuildContext context, {
    int mevcutPersonelSayisi = 0,
  }) {
    return showDialog<List<ExcelPersonelGirdi>>(
      context: context,
      builder: (ctx) => CokluPersonelEkleDialog(
        mevcutPersonelSayisi: mevcutPersonelSayisi,
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

  final TextEditingController _varsayilanPuanController =
      TextEditingController(text: '40');
  final TextEditingController _varsayilanSaatController =
      TextEditingController(text: '5');
  bool _varsayilanMesaiIci = false;

  final TextEditingController _metinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _personelleriYukle();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _varsayilanPuanController.dispose();
    _varsayilanSaatController.dispose();
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
      double.tryParse(_varsayilanPuanController.text.trim()) ?? 40.0;
  double get _varsayilanSaat =>
      double.tryParse(_varsayilanSaatController.text.trim()) ?? 5.0;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 750,
        height: 620,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF107C41).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.group_add, color: Color(0xFF107C41), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Coklu Kisi / Personel Ekle',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      Text(
                        'Ayni anda birden fazla ogretim elemani ekleyin ve katki payi dagitimina dahil edin.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                tabs: const [
                  Tab(icon: Icon(Icons.list_alt, size: 16), text: 'Sistemdeki Hocalardan Sec'),
                  Tab(icon: Icon(Icons.text_snippet_outlined, size: 16), text: 'Toplu Isim Yapistir'),
                  Tab(icon: Icon(Icons.flash_on_outlined, size: 16), text: 'Hazir Kurullar & Hizli Ekle'),
                ],
              ),
            ),
            const SizedBox(height: 12),
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
                    'Varsayilan Degerler:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                  ),
                  const Spacer(),
                  const Text('Puan:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
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
                        _varsayilanMesaiIci ? 'Mesai Ici' : 'Mesai Disi',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _varsayilanMesaiIci ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSistemPersonelleriSekmesi(),
                  _buildMetinYapistirSekmesi(),
                  _buildHazirHeyetlerSekmesi(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSistemPersonelleriSekmesi() {
    if (_yukleniyor) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtreli = _sistemPersonelleri.where((p) {
      if (_aramaMetni.isEmpty) return true;
      final q = _aramaMetni.toLowerCase();
      return p.adSoyad.toLowerCase().contains(q) ||
          p.unvan.toLowerCase().contains(q) ||
          p.birimId.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 36,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Hoca adi, unvan veya birim ile ara...',
                    prefixIcon: Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 12),
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
                    ? 'Secimi Kaldir'
                    : 'Tumunu Sec ()',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtreli.isEmpty
              ? Center(
                  child: Text(
                    _sistemPersonelleri.isEmpty
                        ? 'Sistemde henuz kayitli akademik personel bulunmuyor.\n"Toplu Isim Yapistir" veya "Hazir Kurullar" sekmesini kullanabilirsiniz.'
                        : 'Aramaya uygun personel bulunamadi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                )
              : ListView.separated(
                  itemCount: filtreli.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = filtreli[index];
                    final secili = _secilenPersonelIdleri.contains(p.id);

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
                        ' ',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      subtitle: Text(
                        'Birim:   •  Unvan Katsayisi: ',
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              ' kisi secildi',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF107C41)),
            ),
            ElevatedButton.icon(
              onPressed: _secilenPersonelIdleri.isEmpty ? null : _sistemSecilenleriEkle,
              icon: const Icon(Icons.add, size: 16),
              label: Text('Secilenleri Listeye Ekle ()'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF107C41),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
      final unvanK = DanismanlikExcelHesaplama.unvanKatsayisi(p.unvan, p.unvanKatsayisi);
      final ekGosterge = DanismanlikExcelHesaplama.ekGosterge(p.unvan);

      sonuclar.add(
        ExcelPersonelGirdi(
          personelId: '${baslangicSn++}',
          adSoyad: p.adSoyad,
          unvan: p.unvan,
          puan: _varsayilanPuan,
          unvanKatsayisi: unvanK,
          ekGosterge: ekGosterge,
          dersSaati: _varsayilanSaat,
          mesaiIci: _varsayilanMesaiIci,
          faaliyetTuru: 'Danismanlik',
        ),
      );
    }

    Navigator.pop(context, sonuclar);
  }

  Widget _buildMetinYapistirSekmesi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Asagidaki alana isimleri alt alta yapistirin. Unvan varsa otomatik tespit edilir (orn: Doc. Dr. Eren ONER).',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TextField(
            controller: _metinController,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText:
                  "Ornek format (alt alta):\nDoc. Dr. Eren ONER\nDr. Ogr. Uyesi Sena DEMIRBAG\nDr. Neslihan OPOZ VURAL\nNilufer UNAY CUBUKCU\nEsra SUNERLI TOPAN",
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.all(12),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                _metinController.text =
                    "Doc. Dr. Eren ONER\nDr. Sena DEMIRBAG\nDr. Neslihan OPOZ VURAL\nNilufer UNAY CUBUKCU\nEsra SUNERLI TOPAN";
              },
              child: const Text('Ornek DTS Bilirkisi Metnini Doldur', style: TextStyle(fontSize: 11)),
            ),
            ElevatedButton.icon(
              onPressed: _metindenPersonelleriEkle,
              icon: const Icon(Icons.playlist_add, size: 16),
              label: const Text('Metni Cozumle ve Ekle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF107C41),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _metindenPersonelleriEkle() {
    final text = _metinController.text.trim();
    if (text.isEmpty) return;

    final satirlar = text.split('\n');
    int baslangicSn = widget.mevcutPersonelSayisi + 1;
    final List<ExcelPersonelGirdi> sonuclar = [];

    for (var satir in satirlar) {
      var s = satir.trim();
      if (s.isEmpty) continue;

      s = s.replaceFirst(RegExp(r'^\d+[\.\-\)]\s*'), '');

      String unvan = 'Ogr. Gor.';
      String adSoyad = s;

      if (s.contains('Prof. Dr.') || s.startsWith('Prof.')) {
        unvan = 'Prof. Dr.';
        adSoyad = s.replaceAll('Prof. Dr.', '').replaceAll('Prof.', '').trim();
      } else if (s.contains('Doc. Dr.') || s.contains('Doç. Dr.') || s.startsWith('Doc.') || s.startsWith('Doç.')) {
        unvan = 'Doç. Dr.';
        adSoyad = s.replaceAll('Doc. Dr.', '').replaceAll('Doç. Dr.', '').replaceAll('Doc.', '').replaceAll('Doç.', '').trim();
      } else if (s.contains('Dr. Ogr. Uyesi') || s.contains('Dr. Öğr. Üyesi') || s.contains('Dr.Ogr.Uyesi')) {
        unvan = 'Dr. Öğr. Üyesi';
        adSoyad = s.replaceAll('Dr. Ogr. Uyesi', '').replaceAll('Dr. Öğr. Üyesi', '').replaceAll('Dr.Ogr.Uyesi', '').trim();
      } else if (s.contains('Dr.') || s.contains('Ogr. Gor. Dr.') || s.contains('Öğr. Gör. Dr.')) {
        unvan = 'Öğr. Gör. Dr.';
        adSoyad = s.replaceAll('Ogr. Gor. Dr.', '').replaceAll('Öğr. Gör. Dr.', '').replaceAll('Dr.', '').trim();
      } else if (s.contains('Ars. Gor.') || s.contains('Arş. Gör.')) {
        unvan = 'Arş. Gör.';
        adSoyad = s.replaceAll('Ars. Gor.', '').replaceAll('Arş. Gör.', '').trim();
      } else if (s.contains('Ogr. Gor.') || s.contains('Öğr. Gör.')) {
        unvan = 'Öğr. Gör.';
        adSoyad = s.replaceAll('Ogr. Gor.', '').replaceAll('Öğr. Gör.', '').trim();
      }

      final unvanK = DanismanlikExcelHesaplama.unvanKatsayisi(unvan);
      final ekGosterge = DanismanlikExcelHesaplama.ekGosterge(unvan);

      sonuclar.add(
        ExcelPersonelGirdi(
          personelId: '${baslangicSn++}',
          adSoyad: adSoyad,
          unvan: unvan,
          puan: _varsayilanPuan,
          unvanKatsayisi: unvanK,
          ekGosterge: ekGosterge,
          dersSaati: _varsayilanSaat,
          mesaiIci: _varsayilanMesaiIci,
          faaliyetTuru: 'Danismanlik',
        ),
      );
    }

    if (sonuclar.isNotEmpty) {
      Navigator.pop(context, sonuclar);
    }
  }

  Widget _buildHazirHeyetlerSekmesi() {
    return ListView(
      children: [
        _hazirKart(
          baslik: 'DTS Bilirkisi Heyeti (5 Kisilik Standart Kurul)',
          aciklama:
              'Excel sablonundaki gercek kurul:\n1. Doc. Dr. Eren ONER (50 Puan)\n2. Dr. Sena DEMIRBAG (40 Puan)\n3. Dr. Neslihan OPOZ VURAL (40 Puan)\n4. Nilufer UNAY CUBUKCU (40 Puan)\n5. Esra SUNERLI TOPAN (40 Puan)',
          ikon: Icons.verified_user_outlined,
          renk: const Color(0xFF107C41),
          onTap: () {
            int baslangicSn = widget.mevcutPersonelSayisi + 1;
            final sonuclar = [
              ExcelPersonelGirdi(
                personelId: '${baslangicSn++}',
                adSoyad: 'Eren ÖNER',
                unvan: 'Doç. Dr.',
                puan: 50.0,
                unvanKatsayisi: 2.5,
                ekGosterge: 250,
                dersSaati: 5.0,
                mesaiIci: false,
                faaliyetTuru: 'Bilirkişilik',
              ),
              ExcelPersonelGirdi(
                personelId: '${baslangicSn++}',
                adSoyad: 'Sena DEMİRBAĞ',
                unvan: 'Dr. Öğr. Üyesi',
                puan: 40.0,
                unvanKatsayisi: 2.2,
                ekGosterge: 200,
                dersSaati: 5.0,
                mesaiIci: false,
                faaliyetTuru: 'Bilirkişilik',
              ),
              ExcelPersonelGirdi(
                personelId: '${baslangicSn++}',
                adSoyad: 'Neslihan ÖPÖZ VURAL',
                unvan: 'Öğr. Gör. Dr.',
                puan: 40.0,
                unvanKatsayisi: 2.0,
                ekGosterge: 160,
                dersSaati: 5.0,
                mesaiIci: false,
                faaliyetTuru: 'Bilirkişilik',
              ),
              ExcelPersonelGirdi(
                personelId: '${baslangicSn++}',
                adSoyad: 'Nilüfer ÜNAY ÇUBUKCU',
                unvan: 'Öğr. Gör.',
                puan: 40.0,
                unvanKatsayisi: 2.0,
                ekGosterge: 160,
                dersSaati: 5.0,
                mesaiIci: false,
                faaliyetTuru: 'Bilirkişilik',
              ),
              ExcelPersonelGirdi(
                personelId: '${baslangicSn++}',
                adSoyad: 'Esra SUNERLİ TOPAN',
                unvan: 'Öğr. Gör.',
                puan: 40.0,
                unvanKatsayisi: 2.0,
                ekGosterge: 160,
                dersSaati: 5.0,
                mesaiIci: false,
                faaliyetTuru: 'Bilirkişilik',
              ),
            ];
            Navigator.pop(context, sonuclar);
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _hizliBosEkleKart(
                adet: 3,
                onTap: () => _bosSatirlarEkle(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _hizliBosEkleKart(
                adet: 5,
                onTap: () => _bosSatirlarEkle(5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _hizliBosEkleKart(
                adet: 10,
                onTap: () => _bosSatirlarEkle(10),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _bosSatirlarEkle(int adet) {
    int baslangicSn = widget.mevcutPersonelSayisi + 1;
    final List<ExcelPersonelGirdi> sonuclar = [];

    for (int i = 0; i < adet; i++) {
      sonuclar.add(
        ExcelPersonelGirdi(
          personelId: '${baslangicSn++}',
          adSoyad: '',
          unvan: 'Öğr. Gör. Dr.',
          puan: _varsayilanPuan,
          unvanKatsayisi: 2.0,
          ekGosterge: 160,
          dersSaati: _varsayilanSaat,
          mesaiIci: _varsayilanMesaiIci,
          faaliyetTuru: 'Danışmanlık',
        ),
      );
    }

    Navigator.pop(context, sonuclar);
  }

  Widget _hazirKart({
    required String baslik,
    required String aciklama,
    required IconData ikon,
    required Color renk,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: renk.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: renk.withValues(alpha: 0.1),
          child: Icon(ikon, color: renk, size: 20),
        ),
        title: Text(baslik, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        subtitle: Text(aciklama, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        trailing: ElevatedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.add, size: 14),
          label: const Text('Heyeti Yukle'),
          style: ElevatedButton.styleFrom(
            backgroundColor: renk,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ),
    );
  }

  Widget _hizliBosEkleKart({
    required int adet,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Column(
          children: [
            Icon(Icons.person_add_alt, color: Colors.indigo.shade600, size: 26),
            const SizedBox(height: 8),
            Text(
              '+ Kisi Ekle',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              'Bos satirlar acar',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
