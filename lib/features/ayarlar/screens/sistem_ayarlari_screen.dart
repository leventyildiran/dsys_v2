import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/sistem_ayarlari_model.dart';
import '../../../core/services/sistem_ayarlari_service.dart';
import '../../admin/screens/admin_dashboard_screen.dart';
import '../../birim/screens/birim_yonetim_screen.dart';
import 'sablon_yonetim_screen.dart';

class SistemAyarlariScreen extends StatefulWidget {
  const SistemAyarlariScreen({super.key});

  @override
  State<SistemAyarlariScreen> createState() => _SistemAyarlariScreenState();
}

class _SistemAyarlariScreenState extends State<SistemAyarlariScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = SistemAyarlariService();
  bool _isLoading = true;
  bool _isSaving = false;
  int _selectedIndex = 1;

  late TextEditingController _hesapAdiController;
  late TextEditingController _ibanController;
  late TextEditingController _geminiKeyController;
  late TextEditingController _visionKeyController;
  late TextEditingController _deepseekUrlController;
  late TextEditingController _deepseekKeyController;
  late TextEditingController _deepseekModelController;
  List<YkUyeModel> _kurulUyeleri = [];
  String _isletmeVkn = '';
  bool _geminiKeyGizli = true;
  bool _visionKeyGizli = true;
  bool _deepseekKeyGizli = true;

  @override
  void initState() {
    super.initState();
    _hesapAdiController = TextEditingController();
    _ibanController = TextEditingController();
    _geminiKeyController = TextEditingController();
    _visionKeyController = TextEditingController();
    _deepseekUrlController = TextEditingController();
    _deepseekKeyController = TextEditingController();
    _deepseekModelController = TextEditingController();
    _loadAyarlar();
  }

  Future<void> _loadAyarlar() async {
    final ayarlar = await _service.getAyarlar();
    setState(() {
      _hesapAdiController.text = ayarlar.hesapAdi;
      _ibanController.text = ayarlar.iban;
      _geminiKeyController.text = ayarlar.geminiApiKey;
      _visionKeyController.text = ayarlar.visionApiKey;
      _deepseekUrlController.text = ayarlar.deepseekApiUrl;
      _deepseekKeyController.text = ayarlar.deepseekApiKey;
      _deepseekModelController.text = ayarlar.deepseekModel;
      _isletmeVkn = ayarlar.isletmeVkn;
      _kurulUyeleri = List.from(ayarlar.kurulUyeleri);
      _isLoading = false;
    });
  }

  Future<void> _saveAyarlar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final ayarlar = SistemAyarlariModel(
        hesapAdi: _hesapAdiController.text,
        iban: _ibanController.text,
        isletmeVkn: _isletmeVkn,
        geminiApiKey: _geminiKeyController.text.trim(),
        visionApiKey: _visionKeyController.text.trim(),
        deepseekApiUrl: _deepseekUrlController.text.trim(),
        deepseekApiKey: _deepseekKeyController.text.trim(),
        deepseekModel: _deepseekModelController.text.trim(),
        kurulUyeleri: _kurulUyeleri,
      );
      await _service.saveAyarlar(ayarlar);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ayarlar başarıyla kaydedildi!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _hesapAdiController.dispose();
    _ibanController.dispose();
    _geminiKeyController.dispose();
    _visionKeyController.dispose();
    _deepseekUrlController.dispose();
    _deepseekKeyController.dispose();
    _deepseekModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: Colors.grey[100],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SOL MENÜ (KATEGORİLER)
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Sistem Ayarları',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                  ),
                ),
                _buildMenuItem(1, Icons.api, 'Yapay Zeka & API'),
                _buildMenuItem(2, Icons.admin_panel_settings, 'Sistem Yönetimi'),
                _buildMenuItem(3, Icons.people, 'Yürütme Kurulu'),
                _buildMenuItem(4, Icons.business, 'Döner Sermaye Birimleri'),
                _buildMenuItem(5, Icons.folder_copy, 'Şablon ve Form Havuzu'),
              ],
            ),
          ),

          // SAĞ İÇERİK
          Expanded(
            child: _selectedIndex == 4 
              ? const BirimYonetimScreen()
              : _selectedIndex == 5
                ? const SablonYonetimScreen()
                : SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[200]!),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_selectedIndex == 1) ...[
                              ..._buildApiKurumsalBilgi(),
                              const SizedBox(height: 28),
                              ..._buildGeminiAyarlari(),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 32.0),
                                child: Divider(height: 1),
                              ),
                              ..._buildVisionOcrAyarlari(),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 32.0),
                                child: Divider(height: 1),
                              ),
                              ..._buildDeepseekAyarlari(),
                            ],
                            if (_selectedIndex == 2) const AdminDashboardScreen(),
                            if (_selectedIndex == 3) ..._buildYkUyeleriAyarlari(),
                          ],
                        ),
                      ),
                    ),
                    if (_selectedIndex != 2 && _selectedIndex != 4 && _selectedIndex != 5) ...[
                      const SizedBox(height: 24),
                      // KAYDET BUTONU
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 200,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveAyarlar,
                            icon: _isSaving 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.save, color: Colors.white),
                            label: Text(
                              _isSaving ? 'Kaydediliyor...' : 'Kaydet',
                              style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(int index, IconData icon, String title) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        color: isSelected ? AppTheme.primaryColor.withOpacity(0.08) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primaryColor : Colors.grey[600]),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.primaryColor : Colors.grey[800],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  List<Widget> _buildApiKurumsalBilgi() {
    return [
      _buildInfoBox(
        icon: Icons.business_center_outlined,
        title: 'Kurumsal süreklilik — önemli',
        renk: Colors.blue,
        maddeler: const [
          'API anahtarlarını kişisel Gmail hesabınızla değil, birimin resmi Google hesabıyla oluşturun.',
          'Siz görevden ayrılsanız bile sistem çalışmaya devam etsin diye anahtarlar bu ekranda Firestore\'a kaydedilir.',
          'Devir teslimde bir sonraki sorumluya: birim Google hesabı şifresi, AI Studio erişimi ve bu sayfadaki kayıtlı anahtarlar aktarılmalıdır.',
          'Fatura modülünde okuma sırası: Gemini → (taranmış PDF\'te) Google Vision OCR yedek → DeepSeek (isteğe bağlı).',
        ],
      ),
    ];
  }

  List<Widget> _buildGeminiAyarlari() {
    return [
      _buildSectionHeader(
        Icons.auto_awesome,
        'Gemini — Birincil yapay zeka',
        'Fatura PDF okuma ve taranmış belge analizi için ana motor. Taranmış PDF\'lerde görsel okuma (Gemini Vision) kullanılır.',
      ),
      const SizedBox(height: 16),
      _buildInfoBox(
        icon: Icons.mail_outline,
        title: 'Nasıl alınır?',
        renk: Colors.indigo,
        maddeler: const [
          '1. Birim Google hesabıyla https://aistudio.google.com adresine girin.',
          '2. «Get API key» → yeni proje birim adına oluşturulsun.',
          '3. Oluşan anahtarı aşağıya yapıştırın ve Kaydet\'e basın.',
          '4. Ücretsiz kota yetmezse aynı hesapta Cloud faturalandırma açılabilir — yine birim hesabı kullanın.',
        ],
      ),
      const SizedBox(height: 24),
      _buildApiKeyField(
        label: 'Gemini API Key (birim hesabı)',
        controller: _geminiKeyController,
        gizli: _geminiKeyGizli,
        onToggleGizlilik: () => setState(() => _geminiKeyGizli = !_geminiKeyGizli),
        yardim:
            'Zorunlu önerilir. Boş bırakılırsa fatura PDF\'leri yapay zeka ile okunamaz (yalnızca çevrimdışı kural devreye girer).',
      ),
    ];
  }

  List<Widget> _buildVisionOcrAyarlari() {
    return [
      _buildSectionHeader(
        Icons.document_scanner_outlined,
        'Google Vision OCR — Yedek (taranmış PDF)',
        'Gemini Vision hata verdiğinde veya kota dolduğunda taranmış fatura PDF\'lerinden metin çıkarır.',
      ),
      const SizedBox(height: 16),
      _buildInfoBox(
        icon: Icons.cloud_outlined,
        title: 'Nasıl alınır?',
        renk: Colors.teal,
        maddeler: const [
          '1. Aynı birim Google hesabıyla https://console.cloud.google.com açın.',
          '2. Gemini ile aynı projeyi seçin (veya yeni proje oluşturun).',
          '3. «APIs & Services» → «Cloud Vision API» etkinleştirin.',
          '4. «Credentials» → «Create credentials» → «API key» oluşturun.',
          '5. Anahtarı aşağıya yapıştırın. OCR metni çıktıktan sonra yine Gemini veya DeepSeek alanları doldurulur.',
        ],
      ),
      const SizedBox(height: 24),
      _buildApiKeyField(
        label: 'Google Cloud Vision API Key (birim hesabı)',
        controller: _visionKeyController,
        gizli: _visionKeyGizli,
        onToggleGizlilik: () => setState(() => _visionKeyGizli = !_visionKeyGizli),
        yardim:
            'Taranmış PDF yedek katmanı. Gemini çalışıyorsa boş bırakılabilir; kurumsal dayanıklılık için önerilir.',
      ),
    ];
  }

  List<Widget> _buildDeepseekAyarlari() {
    return [
      _buildSectionHeader(
        Icons.psychology,
        'DeepSeek — İsteğe bağlı metin yedeği',
        'Yalnızca metin tabanlı okumada veya OCR sonrası ikinci yapay zeka katmanı olarak kullanılır. Vision desteği yoktur.',
      ),
      const SizedBox(height: 16),
      _buildInfoBox(
        icon: Icons.info_outline,
        title: 'Ne zaman gerekir?',
        renk: Colors.grey,
        maddeler: const [
          'Birim hesabınızda DeepSeek yoksa bu bölümü boş bırakabilirsiniz.',
          'Varsa yine mümkünse kurumsal hesap kullanın; kişisel anahtar devir teslimde sorun çıkarır.',
          'Gemini + Vision OCR çoğu fatura senaryosunu karşılar.',
        ],
      ),
      const SizedBox(height: 24),
      _buildTextField(
        'API Base URL',
        _deepseekUrlController,
        icon: Icons.link,
        hint: 'https://api.deepseek.com/v1',
      ),
      _buildApiKeyField(
        label: 'DeepSeek API Key',
        controller: _deepseekKeyController,
        gizli: _deepseekKeyGizli,
        onToggleGizlilik: () => setState(() => _deepseekKeyGizli = !_deepseekKeyGizli),
        yardim: 'İsteğe bağlı. Boş bırakılabilir.',
      ),
      _buildTextField(
        'Model Adı',
        _deepseekModelController,
        icon: Icons.memory,
        hint: 'deepseek-chat',
      ),
    ];
  }

  List<Widget> _buildYkUyeleriAyarlari() {
    return [
      _buildSectionHeader(Icons.people, 'Yürütme Kurulu Üyeleri', 'Karar defterindeki (PDF) imza tablosunda yer alacak kurul üyelerini sırasıyla ekleyin.'),
      const SizedBox(height: 24),
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _kurulUyeleri.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (oldIndex < newIndex) {
              newIndex -= 1;
            }
            final item = _kurulUyeleri.removeAt(oldIndex);
            _kurulUyeleri.insert(newIndex, item);
          });
        },
        itemBuilder: (context, index) {
          final uye = _kurulUyeleri[index];
          return Container(
            key: ValueKey('${uye.adSoyad}_$index'),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Row(
              children: [
                const Icon(Icons.drag_handle, color: Colors.grey),
                const SizedBox(width: 16),
                CircleAvatar(backgroundColor: AppTheme.primaryColor.withOpacity(0.1), child: Text('${index + 1}')),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(uye.adSoyad, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(uye.gorev, style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _duzenleUyeDialog(index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _kurulUyeleri.removeAt(index);
                    });
                  },
                ),
              ],
            ),
          );
        },
      ),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: _yeniUyeDialog,
        icon: const Icon(Icons.add),
        label: const Text('Yeni Üye Ekle'),
      ),
    ];
  }

  void _yeniUyeDialog() {
    final adCtrl = TextEditingController();
    final gorevCtrl = TextEditingController(text: 'Üye');
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Yeni Kurul Üyesi Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: adCtrl, decoration: const InputDecoration(labelText: 'Üyenin Adı Soyadı')),
            const SizedBox(height: 16),
            TextField(controller: gorevCtrl, decoration: const InputDecoration(labelText: 'Görevi (Başkan, Üye vb.)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              if (adCtrl.text.isNotEmpty) {
                setState(() {
                  _kurulUyeleri.add(YkUyeModel(gorev: gorevCtrl.text, adSoyad: adCtrl.text));
                });
                Navigator.pop(c);
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _duzenleUyeDialog(int index) {
    final uye = _kurulUyeleri[index];
    final adCtrl = TextEditingController(text: uye.adSoyad);
    final gorevCtrl = TextEditingController(text: uye.gorev);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Kurul Üyesi Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: adCtrl, decoration: const InputDecoration(labelText: 'Üyenin Adı Soyadı')),
            const SizedBox(height: 16),
            TextField(controller: gorevCtrl, decoration: const InputDecoration(labelText: 'Görevi (Başkan, Üye vb.)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              if (adCtrl.text.isNotEmpty) {
                setState(() {
                  _kurulUyeleri[index] = YkUyeModel(gorev: gorevCtrl.text, adSoyad: adCtrl.text);
                });
                Navigator.pop(c);
              }
            },
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 28),
            ),
            const SizedBox(width: 16),
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          ],
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: TextStyle(fontSize: 15, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildInfoBox({
    required IconData icon,
    required String title,
    required MaterialColor renk,
    required List<String> maddeler,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: renk.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: renk.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: renk.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: renk.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final madde in maddeler)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: renk.shade700)),
                  Expanded(
                    child: Text(
                      madde,
                      style: TextStyle(fontSize: 13, height: 1.45, color: Colors.grey.shade800),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildApiKeyField({
    required String label,
    required TextEditingController controller,
    required bool gizli,
    required VoidCallback onToggleGizlilik,
    String? yardim,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
          if (yardim != null) ...[
            const SizedBox(height: 4),
            Text(yardim, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.35)),
          ],
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: gizli,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.key, color: Colors.grey[500]),
              suffixIcon: IconButton(
                icon: Icon(gizli ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: onToggleGizlilik,
                tooltip: gizli ? 'Anahtarı göster' : 'Anahtarı gizle',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {IconData? icon, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: icon != null ? Icon(icon, color: Colors.grey[500]) : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ],
      ),
    );
  }
}
