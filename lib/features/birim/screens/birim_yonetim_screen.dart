import 'package:flutter/material.dart';

import '../models/birim_model.dart';
import '../services/birim_service.dart';
import '../../../core/theme/app_theme.dart';

class BirimYonetimScreen extends StatefulWidget {
  const BirimYonetimScreen({super.key});

  @override
  State<BirimYonetimScreen> createState() => _BirimYonetimScreenState();
}

class _BirimYonetimScreenState extends State<BirimYonetimScreen> {
  final BirimService _birimService = BirimService();
  BirimTuru? _seciliTur;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Birim Yönetimi',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _birimEkleDialog(context),
                icon: const Icon(Icons.add_business),
                label: const Text('Yeni Birim'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filtre
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Tümü'),
                selected: _seciliTur == null,
                onSelected: (_) => setState(() => _seciliTur = null),
              ),
              ...BirimTuru.values.map((t) => FilterChip(
                    label: Text(t.displayName),
                    selected: _seciliTur == t,
                    onSelected: (_) => setState(() => _seciliTur = t),
                  )),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: StreamBuilder<List<BirimModel>>(
              stream: _birimService.stream(onlyActive: false),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Birim verileri alınamadı. ${snapshot.error}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var birimler = snapshot.data!;
                if (_seciliTur != null) {
                  birimler = birimler.where((b) => b.tur == _seciliTur).toList();
                }

                if (birimler.isEmpty) {
                  return Center(
                    child: Text(
                      'Birim bulunamadı.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: birimler.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _BirimKarti(
                      birim: birimler[index],
                      onDuzenle: () => _birimDuzenleDialog(context, birimler[index]),
                      onDurumDegistir: () => _durumDegistir(birimler[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _birimEkleDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    String ad = '';
    String kisaAd = '';
    BirimTuru tur = BirimTuru.merkez;
    String mudurAd = '';
    String hesapAdi = '';
    String iban = '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Yeni Birim Ekle'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Birim Adı',
                      prefixIcon: Icon(Icons.business),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Zorunlu alan' : null,
                    onSaved: (v) => ad = v!.trim(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Kısa Ad (ör: DTS, UBATAM)',
                      prefixIcon: Icon(Icons.short_text),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Zorunlu alan' : null,
                    onSaved: (v) => kisaAd = v!.trim(),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<BirimTuru>(
                    value: tur,
                    decoration: const InputDecoration(
                      labelText: 'Birim Türü',
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(),
                    ),
                    items: BirimTuru.values
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.displayName),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => tur = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Müdür Adı',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    onSaved: (v) => mudurAd = v?.trim() ?? '',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Banka / Hesap Adı',
                      prefixIcon: Icon(Icons.account_balance),
                      border: OutlineInputBorder(),
                    ),
                    onSaved: (v) => hesapAdi = v?.trim() ?? '',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'IBAN',
                      prefixIcon: Icon(Icons.credit_card),
                      border: OutlineInputBorder(),
                    ),
                    onSaved: (v) => iban = v?.trim() ?? '',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  try {
                    final birim = BirimModel(
                      id: '',
                      ad: ad,
                      kisaAd: kisaAd,
                      tur: tur,
                      mudurAd: mudurAd.isNotEmpty ? mudurAd : null,
                      iban: iban.isNotEmpty ? iban : null,
                      hesapAdi: hesapAdi.isNotEmpty ? hesapAdi : null,
                      aktif: true,
                    );
                    await _birimService.create(birim);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Birim başarıyla eklendi.'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _birimDuzenleDialog(BuildContext context, BirimModel birim) async {
    final formKey = GlobalKey<FormState>();
    String ad = birim.ad;
    String kisaAd = birim.kisaAd;
    BirimTuru tur = birim.tur;
    String mudurAd = birim.mudurAd ?? '';
    String iban = birim.iban ?? '';
    String hesapAdi = birim.hesapAdi ?? '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Düzenle: ${birim.kisaAd}'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: ad,
                    decoration: const InputDecoration(
                      labelText: 'Birim Adı',
                      prefixIcon: Icon(Icons.business),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Zorunlu alan' : null,
                    onSaved: (v) => ad = v!.trim(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: kisaAd,
                    decoration: const InputDecoration(
                      labelText: 'Kısa Ad',
                      prefixIcon: Icon(Icons.short_text),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Zorunlu alan' : null,
                    onSaved: (v) => kisaAd = v!.trim(),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<BirimTuru>(
                    value: tur,
                    decoration: const InputDecoration(
                      labelText: 'Birim Türü',
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(),
                    ),
                    items: BirimTuru.values
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.displayName),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => tur = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: hesapAdi,
                    decoration: const InputDecoration(
                      labelText: 'Banka / Hesap Adı',
                      prefixIcon: Icon(Icons.account_balance),
                      border: OutlineInputBorder(),
                    ),
                    onSaved: (v) => hesapAdi = v?.trim() ?? '',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: iban,
                    decoration: const InputDecoration(
                      labelText: 'IBAN',
                      prefixIcon: Icon(Icons.credit_card),
                      border: OutlineInputBorder(),
                    ),
                    onSaved: (v) => iban = v?.trim() ?? '',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  try {
                    await _birimService.update(birim.id, {
                      'ad': ad,
                      'kisaAd': kisaAd,
                      'tur': tur.value,
                      'mudurAd': mudurAd.isNotEmpty ? mudurAd : null,
                      'iban': iban.isNotEmpty ? iban : null,
                      'hesapAdi': hesapAdi.isNotEmpty ? hesapAdi : null,
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Birim güncellendi.'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              },
              child: const Text('Güncelle'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _durumDegistir(BirimModel birim) async {
    final yeniDurum = !birim.aktif;
    try {
      await _birimService.update(birim.id, {'aktif': yeniDurum});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(yeniDurum ? '${birim.kisaAd} aktif edildi.' : '${birim.kisaAd} deaktif edildi.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _BirimKarti extends StatelessWidget {
  const _BirimKarti({
    required this.birim,
    required this.onDuzenle,
    required this.onDurumDegistir,
  });

  final BirimModel birim;
  final VoidCallback onDuzenle;
  final VoidCallback onDurumDegistir;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: birim.aktif ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey.shade200,
          child: Icon(
            Icons.business_rounded,
            color: birim.aktif ? AppTheme.primaryColor : Colors.grey,
          ),
        ),
        title: Text(
          birim.ad,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: birim.aktif ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text(
          '${birim.kisaAd} • ${birim.tur.displayName}${birim.mudurAd != null ? ' • ${birim.mudurAd}' : ''}',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: birim.aktif ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                birim.aktif ? 'Aktif' : 'Pasif',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: birim.aktif ? Colors.green : Colors.red,
                ),
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Düzenle',
              onPressed: onDuzenle,
              color: Colors.blue,
            ),
            IconButton(
              icon: Icon(
                birim.aktif ? Icons.block : Icons.check_circle_outline,
              ),
              tooltip: birim.aktif ? 'Deaktif Et' : 'Aktif Et',
              onPressed: onDurumDegistir,
              color: birim.aktif ? Colors.red : Colors.green,
            ),
          ],
        ),
      ),
    );
  }
}
