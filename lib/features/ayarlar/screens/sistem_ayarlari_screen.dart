import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/sistem_ayarlari_model.dart';
import '../../../core/services/sistem_ayarlari_service.dart';
import '../../admin/screens/admin_dashboard_screen.dart';

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
  int _selectedIndex = 0;

  late TextEditingController _hesapAdiController;
  late TextEditingController _ibanController;
  late TextEditingController _geminiKeyController;
  late TextEditingController _deepseekUrlController;
  late TextEditingController _deepseekKeyController;
  late TextEditingController _deepseekModelController;

  @override
  void initState() {
    super.initState();
    _hesapAdiController = TextEditingController();
    _ibanController = TextEditingController();
    _geminiKeyController = TextEditingController();
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
      _deepseekUrlController.text = ayarlar.deepseekApiUrl;
      _deepseekKeyController.text = ayarlar.deepseekApiKey;
      _deepseekModelController.text = ayarlar.deepseekModel;
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
        geminiApiKey: _geminiKeyController.text,
        deepseekApiUrl: _deepseekUrlController.text,
        deepseekApiKey: _deepseekKeyController.text,
        deepseekModel: _deepseekModelController.text,
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
                _buildMenuItem(0, Icons.account_balance, 'Firma & Banka'),
                _buildMenuItem(1, Icons.api, 'Yapay Zeka & API'),
                _buildMenuItem(2, Icons.admin_panel_settings, 'Sistem Yönetimi'),
              ],
            ),
          ),

          // SAĞ İÇERİK
          Expanded(
            child: SingleChildScrollView(
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
                            if (_selectedIndex == 0) ..._buildBankaAyarlari(),
                            if (_selectedIndex == 1) ...[
                              ..._buildGeminiAyarlari(),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 32.0),
                                child: Divider(height: 1),
                              ),
                              ..._buildDeepseekAyarlari(),
                            ],
                            if (_selectedIndex == 2) const AdminDashboardScreen(),
                          ],
                        ),
                      ),
                    ),
                    if (_selectedIndex != 2) ...[
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

  List<Widget> _buildBankaAyarlari() {
    return [
      _buildSectionHeader(Icons.account_balance, 'Fatura Banka Bilgileri', 'Faturanın alt kısmına eklenecek resmi hesap bilgilerini buradan ayarlayabilirsiniz.'),
      const SizedBox(height: 32),
      _buildTextField('Banka ve Hesap Adı', _hesapAdiController, icon: Icons.business),
      _buildTextField('IBAN', _ibanController, icon: Icons.credit_card),
    ];
  }

  List<Widget> _buildGeminiAyarlari() {
    return [
      _buildSectionHeader(Icons.auto_awesome, 'Gemini AI Ayarları', 'Faturaları otomatik okumak için kullanılacak birincil yapay zeka sağlayıcısıdır. Hızlı ve ücretsizdir.'),
      const SizedBox(height: 32),
      _buildTextField('Gemini API Key', _geminiKeyController, icon: Icons.key),
    ];
  }

  List<Widget> _buildDeepseekAyarlari() {
    return [
      _buildSectionHeader(Icons.psychology, 'DeepSeek AI Ayarları', 'Gemini kotası dolduğunda veya hata verdiğinde devreye girecek olan yedek yapay zeka sağlayıcısıdır.'),
      const SizedBox(height: 32),
      _buildTextField('API Base URL', _deepseekUrlController, icon: Icons.link, hint: 'https://api.deepseek.com/v1'),
      _buildTextField('API Key', _deepseekKeyController, icon: Icons.key),
      _buildTextField('Model Adı', _deepseekModelController, icon: Icons.memory, hint: 'deepseek-chat'),
    ];
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
