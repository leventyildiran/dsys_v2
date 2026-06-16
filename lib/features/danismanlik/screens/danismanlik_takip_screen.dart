import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/turkce_format.dart';
import '../models/taksit_model.dart';
import '../models/taksit_takip_kayit.dart';
import '../providers/taksit_takip_provider.dart';
import '../services/taksit_onay_akisi.dart';
import '../services/taksit_takip_service.dart';
import '../widgets/danismanlik_layout.dart';
import '../widgets/taksit_pipeline.dart';

/// Tüm danışmanlıklardaki taksitleri onay hattı üzerinden takip eder.
class DanismanlikTakipScreen extends StatelessWidget {
  const DanismanlikTakipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TaksitTakipProvider(),
      child: const _DanismanlikTakipBody(),
    );
  }
}

class _DanismanlikTakipBody extends StatelessWidget {
  const _DanismanlikTakipBody();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaksitTakipProvider>();
    final filtered = provider.filtrelenmis;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DanismanlikLayout.kompaktBaslik(
            baslik: 'Ödeme Takibi',
            altBaslik: 'Onay hattı · Excel hesaplama · ödeme durumu',
            aksiyon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.go('/danismanlik'),
                  icon: const Icon(Icons.list_alt, size: 16),
                  label: const Text('Liste'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
          if (provider.hata != null) _mesajBanner(provider.hata!, Colors.red, context),
          if (provider.basari != null) _mesajBanner(provider.basari!, Colors.green, context),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return DanismanlikLayout.ikiKolon(
                        genislik: constraints.maxWidth,
                        ana: _buildTakipListesi(context, provider, filtered),
                        yan: _buildKontrolPaneli(context, provider),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTakipListesi(
    BuildContext context,
    TaksitTakipProvider provider,
    List<TaksitTakipKayit> filtered,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heroOzet(provider.istatistik, filtered.length),
        const SizedBox(height: 12),
        Expanded(
          child: filtered.isEmpty
              ? _bosDurum(provider)
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: DanismanlikLayout.sectionGap),
                    child: _taksitKarti(context, filtered[i], provider),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildKontrolPaneli(BuildContext context, TaksitTakipProvider provider) {
    final oncelikli = provider.oncelikliKayitlar.take(4).toList();
    return Container(
      padding: const EdgeInsets.all(DanismanlikLayout.kartPadding),
      decoration: DanismanlikLayout.kart(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DanismanlikLayout.kartBaslik('Kontrol Merkezi', icon: Icons.tune),
          const SizedBox(height: 12),
          TextField(
            onChanged: provider.aramaDegistir,
            decoration: InputDecoration(
              hintText: 'Firma, birim veya konu ara',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              filled: true,
              fillColor: Colors.blueGrey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _filtreCubugu(context, provider),
          const Divider(height: 24),
          Row(
            children: [
              Icon(Icons.priority_high, size: 16, color: Colors.orange.shade700),
              const SizedBox(width: 6),
              Text(
                'Öncelikli İşler',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.blueGrey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (oncelikli.isEmpty)
            Text(
              'Acil işlem bekleyen taksit yok.',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500),
            )
          else
            ...oncelikli.map((k) => _oncelikSatiri(context, k, provider)),
          const Spacer(),
          _yardimKutusu(),
        ],
      ),
    );
  }

  Widget _mesajBanner(String mesaj, Color renk, BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: renk.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(mesaj, style: TextStyle(color: renk, fontSize: 12))),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () => context.read<TaksitTakipProvider>().mesajlariTemizle(),
          ),
        ],
      ),
    );
  }

  Widget _heroOzet(TaksitTakipIstatistik s, int gorunen) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bugünkü Takip Panosu',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '$gorunen kayıt gösteriliyor · ${TurkceFormat.para(s.toplamTutar)} toplam taksit',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 12),
                ),
              ],
            ),
          ),
          _heroKpi('Bekleyen', '${s.onayBekleyen}', Colors.orange.shade200),
          _heroKpi('Onaylı', '${s.onaylanan}', Colors.green.shade200),
          _heroKpi('Ödenen', '${s.odenen}', Colors.blue.shade100),
          if (s.geciken > 0) _heroKpi('Geciken', '${s.geciken}', Colors.red.shade200),
        ],
      ),
    );
  }

  Widget _heroKpi(String etiket, String deger, Color renk) {
    return Container(
      width: 82,
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Text(deger, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: renk)),
          Text(etiket, style: const TextStyle(fontSize: 10, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _filtreCubugu(BuildContext context, TaksitTakipProvider provider) {
    final durumlar = [null, ...TaksitDurum.values];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: durumlar.map((d) {
        final selected = provider.filtre == d;
        return ChoiceChip(
          label: Text(d?.displayName ?? 'Tümü'),
          selected: selected,
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : Colors.blueGrey.shade700,
          ),
          selectedColor: _durumRenk(d),
          backgroundColor: Colors.blueGrey.shade50,
          side: BorderSide.none,
          visualDensity: VisualDensity.compact,
          onSelected: (_) => provider.filtreDegistir(d),
        );
      }).toList(),
    );
  }

  Widget _taksitKarti(BuildContext context, TaksitTakipKayit kayit, TaksitTakipProvider provider) {
    final t = kayit.taksit;
    final sonraki = TaksitOnayAkisi.sonrakiDurum(t.durum);
    final onceki = TaksitOnayAkisi.oncekiDurum(t.durum);

    final renk = _durumRenk(t.durum);
    final sonrakiEtiket = sonraki == null ? 'Tamamlandı' : TaksitOnayAkisi.ilerletEtiketi(t.durum);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(DanismanlikLayout.kartPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: renk.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: renk.withValues(alpha: 0.13),
                child: Text(
                  '${t.ayNo}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: renk),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kayit.firmaEtiket,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${kayit.birimEtiket} · ${TurkceFormat.para(t.brutTutar)}',
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
                    ),
                  ],
                ),
              ),
              _durumChip(t.durum),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TaksitPipeline(durum: t.durum),
          ),
          if (t.ekOdemeKatsayisi != null || t.dagitilabilirTutar != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                if (t.ekOdemeKatsayisi != null)
                  _bilgiEtiket('Katsayı: ${TurkceFormat.katsayi(t.ekOdemeKatsayisi!)}'),
                if (t.dagitilabilirTutar != null)
                  _bilgiEtiket('Dağıtılabilir: ${TurkceFormat.para(t.dagitilabilirTutar!)}'),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onceki != null)
                TextButton.icon(
                  onPressed: provider.isProcessing ? null : () => provider.durumGeriAl(kayit),
                  icon: const Icon(Icons.arrow_back, size: 14),
                  label: const Text('Geri Al'),
                ),
              TextButton.icon(
                onPressed: () => context.push('/danismanlik/detay/${kayit.danismanlikId}'),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('Detay'),
              ),
              TextButton.icon(
                onPressed: () => context.push(
                  '/danismanlik/dagitim',
                  extra: DanismanlikRouteExtra(model: kayit.danismanlik, taksit: t),
                ),
                icon: const Icon(Icons.table_view, size: 14),
                label: const Text('Excel Hesaplama'),
              ),
              if (sonraki != null)
                FilledButton.icon(
                  onPressed: provider.isProcessing ? null : () => provider.durumIlerlet(kayit),
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: Text(sonrakiEtiket),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _durumChip(TaksitDurum durum) {
    final renk = _durumRenk(durum);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        durum.displayName,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: renk),
      ),
    );
  }

  Color _durumRenk(TaksitDurum? durum) {
    switch (durum) {
      case null:
        return Colors.indigo;
      case TaksitDurum.taslak:
        return Colors.grey.shade600;
      case TaksitDurum.mudurOnayinda:
      case TaksitDurum.merkezOnayinda:
        return Colors.orange.shade700;
      case TaksitDurum.ykGundeminde:
        return Colors.purple.shade600;
      case TaksitDurum.onaylandi:
        return Colors.green.shade700;
      case TaksitDurum.odendi:
        return Colors.blue.shade700;
      case TaksitDurum.gecikti:
        return Colors.red.shade700;
    }
  }

  Widget _oncelikSatiri(
    BuildContext context,
    TaksitTakipKayit kayit,
    TaksitTakipProvider provider,
  ) {
    final renk = _durumRenk(kayit.taksit.durum);
    final sonraki = TaksitOnayAkisi.sonrakiDurum(kayit.taksit.durum);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: renk.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kayit.firmaEtiket,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            'Ay ${kayit.taksit.ayNo} · ${kayit.taksit.durum.displayName}',
            style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600),
          ),
          if (sonraki != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: provider.isProcessing ? null : () => provider.durumIlerlet(kayit),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: renk,
                ),
                child: Text(TaksitOnayAkisi.ilerletEtiketi(kayit.taksit.durum)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _yardimKutusu() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, size: 18, color: Colors.indigo.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'YK Gündemindeki taksitlerde “Onayla & Dağıt” Excel hesabını çalıştırır ve YK arşivine taslak karar gönderir.',
              style: TextStyle(fontSize: 11, height: 1.35, color: Colors.indigo.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bosDurum(TaksitTakipProvider provider) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: DanismanlikLayout.kart(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.manage_search, size: 42, color: Colors.blueGrey.shade300),
            const SizedBox(height: 12),
            Text(
              provider.arama.isEmpty ? 'Taksit kaydı bulunamadı.' : 'Arama veya filtreye uygun kayıt yok.',
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.blueGrey.shade700),
            ),
            const SizedBox(height: 4),
            Text(
              'Filtreleri değiştirerek veya danışmanlık detayından taksit ekleyerek devam edin.',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _bilgiEtiket(String metin) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(metin, style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade700)),
    );
  }
}
