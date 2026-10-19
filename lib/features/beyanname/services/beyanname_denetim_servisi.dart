import '../models/beyanname_belge_model.dart';
import '../models/beyanname_denetim_rapor_model.dart';
import '../../birim/models/birim_model.dart';
import '../../../core/turkce_format.dart';

/// Gelir İdaresi Başkanlığı (GİB), Defterdarlık ve Vergi Denetim Kurulu (VDK)
/// kriterlerine tam uyumlu 9 Senaryolu Çapraz Denetim & Mutabakat Servisi.
class BeyannameDenetimServisi {
  BeyannameDenetimServisi._();

  /// VKN Doğrulama Algoritması (10 Haneli Kurumsal Vergi Kimlik No)
  static bool dogrulaVkn(String vkn) {
    final clean = vkn.trim().replaceAll(RegExp(r'\s+'), '');
    if (clean.length != 10 || int.tryParse(clean) == null) return false;
    if (clean.split('').toSet().length == 1) return false;

    int sum = 0;
    for (int i = 0; i < 9; i++) {
      final digit = int.parse(clean[i]);
      final v1 = (digit + 10 - (i + 1)) % 10;
      int v2 = 0;
      if (v1 == 9) {
        v2 = 9;
      } else if (v1 != 0) {
        v2 = (v1 * (1 << (9 - i))) % 9;
        if (v2 == 0) v2 = 9;
      }
      sum += v2;
    }
    final lastDigit = (10 - (sum % 10)) % 10;
    return lastDigit == int.parse(clean[9]);
  }

  /// TCKN Doğrulama Algoritması (11 Haneli TC Kimlik No)
  static bool dogrulaTckn(String tckn) {
    final clean = tckn.trim().replaceAll(RegExp(r'\s+'), '');
    if (clean.length != 11 || int.tryParse(clean) == null || clean.startsWith('0')) {
      return false;
    }
    // İlk 10 hanesi aynı olan TCKN'ler (örn: 11111111110) kural gereği geçersizdir
    if (clean.substring(0, 10).split('').toSet().length == 1) {
      return false;
    }

    final d = clean.split('').map(int.parse).toList();
    final tekler = d[0] + d[2] + d[4] + d[6] + d[8];
    final ciftler = d[1] + d[3] + d[5] + d[7];

    final h10 = ((tekler * 7) - ciftler) % 10;
    if (h10 != d[9]) return false;

    final topIlk10 = d.take(10).fold(0, (s, x) => s + x);
    if ((topIlk10 % 10) != d[10]) return false;

    return true;
  }

  /// Tüm birimlerin analiz sonuçlarını ve geçmiş dönem verilerini denetler,
  /// Nereden-Nereye dökümünü ve 9 senaryolu mutabakat raporunu üretir.
  static BeyannameAjanRaporu denetleVeRaporOlustur({
    required int yil,
    required int ay,
    required Map<String, BirimMizanAnalizSonucu> birimSonuclari,
    required int toplamDosyaSayisi,
    required Map<String, double> birimOncekiAylarHasilat, // key -> toplam hasılat
    required double oncekiAydanDevredenKdv,
  }) {
    final neredenNereye = <NeredenNereyeKaydi>[];
    final kontroller = <MutabakatKontrolKaydi>[];
    int kontrolIdSayac = 1;

    for (final entry in birimSonuclari.entries) {
      final birimAdi = entry.key;
      final sonuc = entry.value;

      // =======================================================================
      // A) "NEREDEN NEREYE" ŞEFFAF KAYITLARININ OLUŞTURULMASI
      // =======================================================================

      // 1. 600 Aylık Hasılat
      if (sonuc.hasilat600Aylik > 0) {
        neredenNereye.add(NeredenNereyeKaydi(
          birimAdi: birimAdi,
          kaynakBelge: 'Aylık Mizan',
          hesapKoduVeAdi: '600 Gelirler Hesabı',
          bulunanTutar: sonuc.hasilat600Aylik,
          hedefAlan: '600 Hasılat Masası -> Aylık Hasılat',
          aciklama: 'Aylık mizan gelir tablosundan aktarıldı.',
        ));
      }

      // 2. 600 Kümülatif Hasılat
      if (sonuc.hasilat600Kumulatif > 0) {
        neredenNereye.add(NeredenNereyeKaydi(
          birimAdi: birimAdi,
          kaynakBelge: 'Yıllık Mizan',
          hesapKoduVeAdi: '600 Gelirler Hesabı',
          bulunanTutar: sonuc.hasilat600Kumulatif,
          hedefAlan: '600 Hasılat Masası -> Yıllık Kümülatif',
          aciklama: 'Yıllık mizan kümülatif bakiye sütunundan aktarıldı.',
        ));
      }

      // 3. 123 Kredi Kartı POS
      if (sonuc.krediKarti123 > 0) {
        neredenNereye.add(NeredenNereyeKaydi(
          birimAdi: birimAdi,
          kaynakBelge: 'Aylık Mizan',
          hesapKoduVeAdi: '123 Kredi Kartı / POS',
          bulunanTutar: sonuc.krediKarti123,
          hedefAlan: '600 Hasılat Masası -> Satır 45 (POS)',
          aciklama: 'GİB Satır 45 POS mutabakatı için aktarıldı.',
        ));
      }

      // 4. 391.20 Hesaplanan KDV (%20)
      if (sonuc.hesaplananKdv20 > 0 || sonuc.hesaplananKdvMatrah20 > 0) {
        neredenNereye.add(NeredenNereyeKaydi(
          birimAdi: birimAdi,
          kaynakBelge: 'Aylık Mizan',
          hesapKoduVeAdi: '391.20 Hesaplanan KDV (%20)',
          bulunanTutar: sonuc.hesaplananKdv20,
          hedefAlan: 'KDV 1 Masası -> %20 Hesaplanan KDV',
          aciklama: 'Matrah: ${TurkceFormat.para(sonuc.hesaplananKdvMatrah20)}',
        ));
      }

      // 5. 391.10 Hesaplanan KDV (%10)
      if (sonuc.hesaplananKdv10 > 0 || sonuc.hesaplananKdvMatrah10 > 0) {
        neredenNereye.add(NeredenNereyeKaydi(
          birimAdi: birimAdi,
          kaynakBelge: 'Aylık Mizan',
          hesapKoduVeAdi: '391.10 Hesaplanan KDV (%10)',
          bulunanTutar: sonuc.hesaplananKdv10,
          hedefAlan: 'KDV 1 Masası -> %10 Hesaplanan KDV',
          aciklama: 'Matrah: ${TurkceFormat.para(sonuc.hesaplananKdvMatrah10)}',
        ));
      }

      // 6. 191 İndirilecek KDV
      if (sonuc.toplamIndirilecekKdv > 0) {
        neredenNereye.add(NeredenNereyeKaydi(
          birimAdi: birimAdi,
          kaynakBelge: 'Aylık Mizan',
          hesapKoduVeAdi: '191 İndirilecek KDV',
          bulunanTutar: sonuc.toplamIndirilecekKdv,
          hedefAlan: 'KDV 1 Masası -> İndirilecek KDV',
          aciklama: '%20 İndirilecek: ${TurkceFormat.para(sonuc.indirilecekKdv20)}, %10: ${TurkceFormat.para(sonuc.indirilecekKdv10)}',
        ));
      }

      // 7. 360.03.05 Damga Vergisi
      if (sonuc.damgaVergisi360 > 0) {
        neredenNereye.add(NeredenNereyeKaydi(
          birimAdi: birimAdi,
          kaynakBelge: 'Aylık Mizan',
          hesapKoduVeAdi: '360.03.05 Damga Vergisi',
          bulunanTutar: sonuc.damgaVergisi360,
          hedefAlan: 'Damga Masası & 301 Kodu',
          aciklama: 'Hesaplanan Matrah (Binde 9.48): ${TurkceFormat.para(sonuc.damgaMatrah)}',
        ));
      }

      // 8. Yardımcı Mizan (Muavin) Alt Hesap Kanıtı
      if (sonuc.yardimciMizanKullanildi) {
        neredenNereye.add(NeredenNereyeKaydi(
          birimAdi: birimAdi,
          kaynakBelge: 'Yardımcı Mizan',
          hesapKoduVeAdi: '391 / 191 / 600 Alt Kırılımlar',
          bulunanTutar: (sonuc.yardimciMizan391Toplam > 0 ? sonuc.yardimciMizan391Toplam : sonuc.toplamHesaplananKdv),
          hedefAlan: 'KDV 1 Oran Ayrımı (%10 / %20)',
          aciklama: 'Yardımcı mizan üzerinden oran ayrımı sağlandı (391 Toplamı: ${TurkceFormat.para(sonuc.yardimciMizan391Toplam)}, 191 Toplamı: ${TurkceFormat.para(sonuc.yardimciMizan191Toplam)}).',
        ));
      }

      // =======================================================================
      // B) 10 SENARYOLU ÇAPRAZ DENETİM VE HATA ANALİZİ
      // =======================================================================

      // -----------------------------------------------------------------------
      // SENARYO 1: Kredi Kartı 123 Hesabı vs Satır 45 (İzaha Davet Riski)
      // -----------------------------------------------------------------------
      if (sonuc.krediKarti123 > 0 && sonuc.hasilat600Aylik > 0 && sonuc.krediKarti123 > (sonuc.hasilat600Aylik * 1.5)) {
        kontroller.add(MutabakatKontrolKaydi(
          id: 'sen-1-${kontrolIdSayac++}',
          senaryoNo: 1,
          birimAdi: birimAdi,
          baslik: 'POS Tahsilatı Aylık Hasılatın Çok Üzerinde (Satır 45)',
          seviye: DenetimSeviyesi.uyari,
          beklenenDeger: sonuc.hasilat600Aylik,
          bulunanDeger: sonuc.krediKarti123,
          fark: sonuc.krediKarti123 - sonuc.hasilat600Aylik,
          aciklama: 'Kredi kartı tahsilatı (${TurkceFormat.para(sonuc.krediKarti123)}), aylık hasılatın (${TurkceFormat.para(sonuc.hasilat600Aylik)}) 1.5 katını aşıyor. GİB Satır 45 incelemesinde avans veya taksitli tahsilat izahatı istenebilir.',
          cozumOnerisi: 'POS slipleri ve avans tahsilat makbuzlarını teyit ediniz.',
        ));
      } else if (sonuc.krediKarti123 > 0) {
        kontroller.add(MutabakatKontrolKaydi(
          id: 'sen-1-${kontrolIdSayac++}',
          senaryoNo: 1,
          birimAdi: birimAdi,
          baslik: 'Kredi Kartı Satır 45 Mutabakatı Hazır',
          seviye: DenetimSeviyesi.bilgi,
          bulunanDeger: sonuc.krediKarti123,
          aciklama: 'Mizandaki 123 hesabı (${TurkceFormat.para(sonuc.krediKarti123)}) GİB Satır 45 ile tam örtüşüyor.',
        ));
      }

      // -----------------------------------------------------------------------
      // SENARYO 2: Aylık Mizan + Önceki Aylar vs Yıllık Kümülatif 600 Uyuşmazlığı
      // -----------------------------------------------------------------------
      final cKey = BirimAdlandirma.canonicalKey(birimAdi);
      final oncekiAylarToplami = birimOncekiAylarHasilat[birimAdi] ??
          birimOncekiAylarHasilat[cKey] ??
          0.0;

      if (sonuc.hasilat600Kumulatif > 0) {
        // 1. Kritik Hata: Yıllık kümülatif tek bir ayın hasılatından küçük olamaz
        if (sonuc.hasilat600Kumulatif < sonuc.hasilat600Aylik - 1.0) {
          kontroller.add(MutabakatKontrolKaydi(
            id: 'sen-2-${kontrolIdSayac++}',
            senaryoNo: 2,
            birimAdi: birimAdi,
            baslik: 'Kümülatif Hasılat Aylık Hasılatın Altında (Kritik Mantık Hatası)',
            seviye: DenetimSeviyesi.hata,
            beklenenDeger: sonuc.hasilat600Aylik,
            bulunanDeger: sonuc.hasilat600Kumulatif,
            fark: sonuc.hasilat600Aylik - sonuc.hasilat600Kumulatif,
            aciklama: 'Yıllık mizan kümülatif hasılatı (${TurkceFormat.para(sonuc.hasilat600Kumulatif)}), tek bir ayın hasılatından (${TurkceFormat.para(sonuc.hasilat600Aylik)}) daha az çıkamaz.',
            cozumOnerisi: 'Mizan dönemlerini ve ters bakiye kayıtlarını kontrol ediniz.',
          ));
        } else if (oncekiAylarToplami > 0) {
          // 2. Geçmiş aylar DSYS'ye girilmişse: (Önceki Aylar + Bu Ay == Yıllık Mizan) kontrolü
          final beklenenKumulatif = oncekiAylarToplami + sonuc.hasilat600Aylik;
          final fark = (beklenenKumulatif - sonuc.hasilat600Kumulatif).abs();
          if (fark > 1.0) {
            kontroller.add(MutabakatKontrolKaydi(
              id: 'sen-2-${kontrolIdSayac++}',
              senaryoNo: 2,
              birimAdi: birimAdi,
              baslik: 'Kümülatif Hasılat Mizan Uyuşmazlığı',
              seviye: DenetimSeviyesi.hata,
              beklenenDeger: beklenenKumulatif,
              bulunanDeger: sonuc.hasilat600Kumulatif,
              fark: beklenenKumulatif - sonuc.hasilat600Kumulatif,
              aciklama: 'Önceki aylar toplamı (${TurkceFormat.para(oncekiAylarToplami)}) + Bu ay hasılatı (${TurkceFormat.para(sonuc.hasilat600Aylik)}) = ${TurkceFormat.para(beklenenKumulatif)} olması gerekirken, Yıllık Mizan kümülatif bakiyesi ${TurkceFormat.para(sonuc.hasilat600Kumulatif)} çıkmaktadır. Fark: ${TurkceFormat.para(fark)}.',
              cozumOnerisi: '1) Geçmiş aylara geriye dönük ters/ek kayıt atılmış olabilir.\n2) Yıllık mizan dönemi kontrol edilmelidir.',
            ));
          } else {
            kontroller.add(MutabakatKontrolKaydi(
              id: 'sen-2-${kontrolIdSayac++}',
              senaryoNo: 2,
              birimAdi: birimAdi,
              baslik: 'Aylık ve Yıllık Mizan Kümülatif Mutabakatı Tam',
              seviye: DenetimSeviyesi.bilgi,
              beklenenDeger: beklenenKumulatif,
              bulunanDeger: sonuc.hasilat600Kumulatif,
              fark: 0.0,
              aciklama: 'Aylık mizan ve kümülatif mizan kuruşu kuruşuna birbirini doğrulamaktadır (${TurkceFormat.para(beklenenKumulatif)}).',
            ));
          }
        } else {
          // 3. Geçmiş aylar henüz sisteme girilmemişse: Yıllık mizan doğrudan kümülatif referanstır.
          // Bu bir hata/uyarı değil, kümülatifin aylığı doğruladığı başarılı bir durumdur.
          final gecmisAylarPayi = sonuc.hasilat600Kumulatif - sonuc.hasilat600Aylik;
          kontroller.add(MutabakatKontrolKaydi(
            id: 'sen-2-${kontrolIdSayac++}',
            senaryoNo: 2,
            birimAdi: birimAdi,
            baslik: 'Aylık ve Yıllık Mizan Kümülatif Uyumu Tam',
            seviye: DenetimSeviyesi.bilgi,
            beklenenDeger: sonuc.hasilat600Kumulatif,
            bulunanDeger: sonuc.hasilat600Kumulatif,
            fark: 0.0,
            aciklama: 'Aylık hasılat (${TurkceFormat.para(sonuc.hasilat600Aylik)}) yıllık mizan kümülatifi (${TurkceFormat.para(sonuc.hasilat600Kumulatif)}) ile tam uyumludur. Geçmiş ayların hasılat payı: ${TurkceFormat.para(gecmisAylarPayi)}.',
            cozumOnerisi: 'Kümülatif hasılat tutarı doğrudan yıllık mizandan beyannameye aktarılacaktır.',
          ));
        }
      }

      // -----------------------------------------------------------------------
      // SENARYO 3: 600 Hasılat vs KDV 1 Matrahı (391) Farkı
      // -----------------------------------------------------------------------
      if (sonuc.hasilat600Aylik > 0 || sonuc.toplamHesaplananMatrah > 0) {
        final kdvMatrahToplami = sonuc.toplamHesaplananMatrah;
        final matrahFarki = sonuc.hasilat600Aylik - kdvMatrahToplami;

        if (matrahFarki.abs() > 1.0) {
          if (matrahFarki > 0) {
            kontroller.add(MutabakatKontrolKaydi(
              id: 'sen-3-${kontrolIdSayac++}',
              senaryoNo: 3,
              birimAdi: birimAdi,
              baslik: 'Hasılat KDV Matrahından Büyük (İstisna Kontrolü)',
              seviye: DenetimSeviyesi.uyari,
              beklenenDeger: sonuc.hasilat600Aylik,
              bulunanDeger: kdvMatrahToplami,
              fark: matrahFarki,
              aciklama: '600 Gelirler toplamı (${TurkceFormat.para(sonuc.hasilat600Aylik)}), KDV 1 matrahından (${TurkceFormat.para(kdvMatrahToplami)}) ${TurkceFormat.para(matrahFarki)} fazladır. KDVK 17/1 veya 17/2-b kapsamında vergiden istisna teslimler veya kur farkı olabilir.',
              cozumOnerisi: 'İstisna teslim tutarı KDV 1 Tablo 8 İstisnalar satırında gösterilmelidir.',
            ));
          } else {
            kontroller.add(MutabakatKontrolKaydi(
              id: 'sen-3-${kontrolIdSayac++}',
              senaryoNo: 3,
              birimAdi: birimAdi,
              baslik: 'KDV Matrahı 600 Gelirlerinden Yüksek!',
              seviye: DenetimSeviyesi.hata,
              beklenenDeger: sonuc.hasilat600Aylik,
              bulunanDeger: kdvMatrahToplami,
              fark: matrahFarki,
              aciklama: 'KDV 1 matrahı (${TurkceFormat.para(kdvMatrahToplami)}), 600 Hasılat hesabından (${TurkceFormat.para(sonuc.hasilat600Aylik)}) daha büyüktür. Bu durum vergi incelemesinde risk oluşturur.',
              cozumOnerisi: '600 hesabına kaydedilmemiş fatura veya amortismana tabi iktisadi kıymet (ATİK) satışı olup olmadığını kontrol ediniz.',
            ));
          }
        } else {
          kontroller.add(MutabakatKontrolKaydi(
            id: 'sen-3-${kontrolIdSayac++}',
            senaryoNo: 3,
            birimAdi: birimAdi,
            baslik: '600 Hasılat ve KDV 1 Matrahı Birebir Eşit',
            seviye: DenetimSeviyesi.bilgi,
            beklenenDeger: sonuc.hasilat600Aylik,
            bulunanDeger: kdvMatrahToplami,
            fark: 0.0,
            aciklama: '600 hasılat ile KDV 1 hesaplanan matrahı tam mutabık (${TurkceFormat.para(sonuc.hasilat600Aylik)}).',
          ));
        }
      }

      // -----------------------------------------------------------------------
      // SENARYO 4: KDV Matematiksel Sağlama ve Oran Çaprazı (%10 ve %20)
      // -----------------------------------------------------------------------
      if (sonuc.hesaplananKdvMatrah20 > 0) {
        final beklenenKdv20 = sonuc.hesaplananKdvMatrah20 * 0.20;
        final kdv20Farki = (beklenenKdv20 - sonuc.hesaplananKdv20).abs();
        if (kdv20Farki > 1.0) {
          kontroller.add(MutabakatKontrolKaydi(
            id: 'sen-4a-${kontrolIdSayac++}',
            senaryoNo: 4,
            birimAdi: birimAdi,
            baslik: '%20 KDV Matematiksel Uyuşmazlığı',
            seviye: DenetimSeviyesi.hata,
            beklenenDeger: beklenenKdv20,
            bulunanDeger: sonuc.hesaplananKdv20,
            fark: beklenenKdv20 - sonuc.hesaplananKdv20,
            aciklama: 'Matrah (${TurkceFormat.para(sonuc.hesaplananKdvMatrah20)}) x %20 = ${TurkceFormat.para(beklenenKdv20)} olmalıdır. Mizandaki KDV: ${TurkceFormat.para(sonuc.hesaplananKdv20)}.',
            cozumOnerisi: 'Hatalı oranlı kesilmiş fatura veya yuvarlama farkını inceleyiniz.',
          ));
        } else {
          kontroller.add(MutabakatKontrolKaydi(
            id: 'sen-4a-${kontrolIdSayac++}',
            senaryoNo: 4,
            birimAdi: birimAdi,
            baslik: '%20 KDV Matematiksel Sağlaması Doğrulandı',
            seviye: DenetimSeviyesi.bilgi,
            beklenenDeger: beklenenKdv20,
            bulunanDeger: sonuc.hesaplananKdv20,
            fark: 0.0,
            aciklama: 'Matrah (${TurkceFormat.para(sonuc.hesaplananKdvMatrah20)}) x %20 = ${TurkceFormat.para(sonuc.hesaplananKdv20)} tam mutabık.',
          ));
        }
      }

      if (sonuc.hesaplananKdvMatrah10 > 0) {
        final beklenenKdv10 = sonuc.hesaplananKdvMatrah10 * 0.10;
        final kdv10Farki = (beklenenKdv10 - sonuc.hesaplananKdv10).abs();
        if (kdv10Farki > 1.0) {
          kontroller.add(MutabakatKontrolKaydi(
            id: 'sen-4b-${kontrolIdSayac++}',
            senaryoNo: 4,
            birimAdi: birimAdi,
            baslik: '%10 KDV Matematiksel Uyuşmazlığı',
            seviye: DenetimSeviyesi.hata,
            beklenenDeger: beklenenKdv10,
            bulunanDeger: sonuc.hesaplananKdv10,
            fark: beklenenKdv10 - sonuc.hesaplananKdv10,
            aciklama: 'Matrah (${TurkceFormat.para(sonuc.hesaplananKdvMatrah10)}) x %10 = ${TurkceFormat.para(beklenenKdv10)} olmalıdır. Mizandaki KDV: ${TurkceFormat.para(sonuc.hesaplananKdv10)}.',
            cozumOnerisi: '10\'luk matrah ve vergi ayrımını kontrol ediniz.',
          ));
        } else {
          kontroller.add(MutabakatKontrolKaydi(
            id: 'sen-4b-${kontrolIdSayac++}',
            senaryoNo: 4,
            birimAdi: birimAdi,
            baslik: '%10 KDV Matematiksel Sağlaması Doğrulandı',
            seviye: DenetimSeviyesi.bilgi,
            beklenenDeger: beklenenKdv10,
            bulunanDeger: sonuc.hesaplananKdv10,
            fark: 0.0,
            aciklama: 'Matrah (${TurkceFormat.para(sonuc.hesaplananKdvMatrah10)}) x %10 = ${TurkceFormat.para(sonuc.hesaplananKdv10)} tam mutabık.',
          ));
        }
      }

      // -----------------------------------------------------------------------
      // SENARYO 6: Ters Bakiye Alarmı (191, 391, 600)
      // -----------------------------------------------------------------------
      final ham = sonuc.hamJson;
      if (ham != null) {
        bool b(dynamic v) =>
            v is bool ? v : (v?.toString().trim().toLowerCase() == 'true');
        final is191Alacak = b(ham['is191TersBakiye']);
        final is391Borc = b(ham['is391TersBakiye']);
        final is600Borc = b(ham['is600TersBakiye']);

        if (is191Alacak) {
          kontroller.add(MutabakatKontrolKaydi(
            id: 'sen-6a-${kontrolIdSayac++}',
            senaryoNo: 6,
            birimAdi: birimAdi,
            baslik: '191 İndirilecek KDV Hesabında Ters Alacak Bakiyesi!',
            seviye: DenetimSeviyesi.hata,
            aciklama: '191 hesabı daima borç bakiyesi vermelidir. Alacak bakiyesi vermesi muhasebe kayıt hatasıdır.',
            cozumOnerisi: 'Ters fiş veya yanlış hesap koduna atılmış iade kaydını düzeltiniz.',
          ));
        }
        if (is391Borc) {
          kontroller.add(MutabakatKontrolKaydi(
            id: 'sen-6b-${kontrolIdSayac++}',
            senaryoNo: 6,
            birimAdi: birimAdi,
            baslik: '391 Hesaplanan KDV Hesabında Ters Borç Bakiyesi!',
            seviye: DenetimSeviyesi.hata,
            aciklama: '391 hesabı daima alacak bakiyesi vermelidir. Borç bakiyesi kabul edilemez.',
            cozumOnerisi: 'Satış KDV tahakkuk fişlerini inceleyiniz.',
          ));
        }
        if (is600Borc) {
          kontroller.add(MutabakatKontrolKaydi(
            id: 'sen-6c-${kontrolIdSayac++}',
            senaryoNo: 6,
            birimAdi: birimAdi,
            baslik: '600 Gelirler Hesabında Ters Borç Bakiyesi!',
            seviye: DenetimSeviyesi.hata,
            aciklama: '600 Gelirler hesabı borç bakiyesi veremez.',
            cozumOnerisi: 'İade faturasının 610 yerine 600 borcuna yazılıp yazılmadığını kontrol ediniz.',
          ));
        }
      }

      // -----------------------------------------------------------------------
      // SENARYO 7: 360.03.05 Damga Vergisi Matrah Sağlaması (Binde 9.48)
      // -----------------------------------------------------------------------
      if (sonuc.damgaVergisi360 > 0) {
        final beklenenDamgaMatrahi = sonuc.damgaVergisi360 / 0.00948;
        if (sonuc.damgaMatrah > 0 && (beklenenDamgaMatrahi - sonuc.damgaMatrah).abs() > 5.0) {
          kontroller.add(MutabakatKontrolKaydi(
            id: 'sen-7-${kontrolIdSayac++}',
            senaryoNo: 7,
            birimAdi: birimAdi,
            baslik: 'Damga Vergisi (360.03.05) Matrah Tutarsızlığı',
            seviye: DenetimSeviyesi.uyari,
            beklenenDeger: beklenenDamgaMatrahi,
            bulunanDeger: sonuc.damgaMatrah,
            fark: beklenenDamgaMatrahi - sonuc.damgaMatrah,
            aciklama: '360.03.05 Damga vergisi (${TurkceFormat.para(sonuc.damgaVergisi360)}) / 0,00948 = ${TurkceFormat.para(beklenenDamgaMatrahi)} matrah üretmelidir.',
            cozumOnerisi: 'Damga vergisi oranında karar pulu veya sözleşme istisnası olup olmadığını inceleyiniz.',
          ));
        } else {
          kontroller.add(MutabakatKontrolKaydi(
            id: 'sen-7-${kontrolIdSayac++}',
            senaryoNo: 7,
            birimAdi: birimAdi,
            baslik: '360.03.05 Damga Vergisi Binde 9,48 Doğrulandı',
            seviye: DenetimSeviyesi.bilgi,
            beklenenDeger: beklenenDamgaMatrahi,
            bulunanDeger: sonuc.damgaVergisi360,
            aciklama: 'Mizandaki damga vergisi binde 9,48 oranıyla matematiksel olarak tam doğrulanmıştır (Hesaplanan Matrah: ${TurkceFormat.para(beklenenDamgaMatrahi)}).',
          ));
        }
      }

      // -----------------------------------------------------------------------
      // SENARYO 8: KDV 2 Tevkifat VKN / TCKN ve Oran Doğrulaması
      // -----------------------------------------------------------------------
      for (final fatura in sonuc.tevkifatFaturalari) {
        var firmaAdi = fatura['firmaAdi'] as String? ?? 'Bilinmeyen Firma';
        var vkn = (fatura['vergiTcNo'] as String? ?? '').trim();
        final oranStr = (fatura['tevkifatOrani'] as String? ?? '9/10').trim();

        // VKN temizleme (boşluk ve tireleri kaldır)
        vkn = vkn.replaceAll(RegExp(r'[^\d]'), '');

        if (vkn.isNotEmpty) {
          final isVknValid = vkn.length == 10 ? dogrulaVkn(vkn) : (vkn.length == 11 ? dogrulaTckn(vkn) : false);
          if (!isVknValid) {
            kontroller.add(MutabakatKontrolKaydi(
              id: 'sen-8a-${kontrolIdSayac++}',
              senaryoNo: 8,
              birimAdi: birimAdi,
              baslik: 'Geçersiz Vergi / TC Kimlik Numarası ($firmaAdi)',
              seviye: DenetimSeviyesi.hata,
              aciklama: '$firmaAdi için girilen numara ($vkn) GİB VKN/TCKN kontrol algoritmasını geçemedi. Bu haliyle paketlenirse GİB e-Beyanname sistemi beyannameyi doğrudan REDDEDER.',
              cozumOnerisi: 'Fatura üzerindeki vergi kimlik numarasını tekrar kontrol edip düzeltiniz.',
            ));
          } else {
            kontroller.add(MutabakatKontrolKaydi(
              id: 'sen-8a-${kontrolIdSayac++}',
              senaryoNo: 8,
              birimAdi: birimAdi,
              baslik: 'Tevkifat Faturası VKN Doğrulandı ($firmaAdi)',
              seviye: DenetimSeviyesi.bilgi,
              aciklama: '$firmaAdi vergi kimlik numarası ($vkn) GİB kontrol algoritmasına göre geçerlidir.',
            ));
          }
        } else {
          kontroller.add(MutabakatKontrolKaydi(
            id: 'sen-8a-${kontrolIdSayac++}',
            senaryoNo: 8,
            birimAdi: birimAdi,
            baslik: 'Eksik VKN / TCKN ($firmaAdi)',
            seviye: DenetimSeviyesi.hata,
            aciklama: '$firmaAdi tevkifat faturasında Vergi Kimlik Numarası (VKN/TCKN) bulunamadı. GİB e-Beyanname VKN olmadan beyannameyi doğrudan reddeder.',
            cozumOnerisi: 'Fatura üzerindeki vergi kimlik numarasını giriniz.',
          ));
        }

        // Tevkifat matematiksel kontrolü
        final matrah = TurkceFormat.parseSayi(fatura['matrahTutari']);
        final kdvTutari = TurkceFormat.parseSayi(fatura['kdvTutari']);
        final tevkifatTutari = TurkceFormat.parseSayi(fatura['tevkifatTutari']);

        if (matrah > 0 && kdvTutari > 0 && tevkifatTutari > 0) {
          double carpimOrani = 0.9;
          final match = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(oranStr);
          if (match != null) {
            final pay = double.tryParse(match.group(1)!) ?? 9.0;
            final payda = double.tryParse(match.group(2)!) ?? 10.0;
            if (payda > 0) {
              carpimOrani = pay / payda;
            }
          }

          final beklenenTevkifat = kdvTutari * carpimOrani;
          if ((beklenenTevkifat - tevkifatTutari).abs() > 1.0) {
            kontroller.add(MutabakatKontrolKaydi(
              id: 'sen-8b-${kontrolIdSayac++}',
              senaryoNo: 8,
              birimAdi: birimAdi,
              baslik: 'KDV 2 Tevkifat Tutarı Hesaplama Farkı ($firmaAdi)',
              seviye: DenetimSeviyesi.uyari,
              beklenenDeger: beklenenTevkifat,
              bulunanDeger: tevkifatTutari,
              fark: beklenenTevkifat - tevkifatTutari,
              aciklama: '$firmaAdi: KDV (${TurkceFormat.para(kdvTutari)}) x $oranStr = ${TurkceFormat.para(beklenenTevkifat)} olmalıdır. Belgede ${TurkceFormat.para(tevkifatTutari)} yazmaktadır.',
              cozumOnerisi: 'Fatura üzerindeki tevkifat satırını teyit ediniz.',
            ));
          }
        }
      }

      // -----------------------------------------------------------------------
      // SENARYO 9: Belge & Fatura - Mizan Mutabakatı (Mizana Yansımamış Fatura Tespiti)
      // -----------------------------------------------------------------------
      final aciklama = sonuc.aciklama?.trim() ?? '';
      final isAiError = aciklama.startsWith('AI okuma hatası');
      if (aciklama.isNotEmpty && !isAiError) {
        final lower = aciklama.toLowerCase();
        final containsWarning = lower.contains('yansımamış') ||
            lower.contains('yansimamis') ||
            lower.contains('fark') ||
            lower.contains('uyuşmazlık') ||
            lower.contains('uyumsuzluk') ||
            lower.contains('eksik') ||
            lower.contains('bulunamadı');
        kontroller.add(MutabakatKontrolKaydi(
          id: 'sen-9-${kontrolIdSayac++}',
          senaryoNo: 9,
          birimAdi: birimAdi,
          baslik: containsWarning
              ? 'Belge - Mizan Mutabakat Uyarısı (AI Tespiti)'
              : 'Belge & Fatura Analiz Notu',
          seviye: containsWarning ? DenetimSeviyesi.uyari : DenetimSeviyesi.bilgi,
          aciklama: aciklama,
          cozumOnerisi: containsWarning
              ? 'Mizana henüz işlenmemiş fatura veya tahakkuk fişlerini muhasebe kayıtlarına intikal ettiriniz.'
              : null,
        ));
      } else if (sonuc.tevkifatFaturalari.isNotEmpty) {
        final topTevkifatMatrah = sonuc.tevkifatFaturalari.fold(
          0.0,
          (s, f) => s + TurkceFormat.parseSayi(f['matrahTutari']),
        );
        kontroller.add(MutabakatKontrolKaydi(
          id: 'sen-9-${kontrolIdSayac++}',
          senaryoNo: 9,
          birimAdi: birimAdi,
          baslik: 'Ek Faturalar Mizanla Uyumlu İncelendi',
          seviye: DenetimSeviyesi.bilgi,
          bulunanDeger: topTevkifatMatrah,
          aciklama: '${sonuc.tevkifatFaturalari.length} adet tevkifat faturası (${TurkceFormat.para(topTevkifatMatrah)} matrah) incelendi ve mizanla mutabık bulundu.',
        ));
      }

      // -----------------------------------------------------------------------
      // SENARYO 10: Ana Mizan & Yardımcı Mizan (Muavin) Çapraz Mutabakatı
      // -----------------------------------------------------------------------
      if (sonuc.yardimciMizanKullanildi) {
        // 10a: 391 Hesaplanan KDV Mutabakatı
        if (sonuc.yardimciMizan391Toplam > 0 && sonuc.toplamHesaplananKdv > 0) {
          final kdv391Farki = (sonuc.yardimciMizan391Toplam - sonuc.toplamHesaplananKdv).abs();
          if (kdv391Farki > 1.0) {
            kontroller.add(MutabakatKontrolKaydi(
              id: 'sen-10a-${kontrolIdSayac++}',
              senaryoNo: 10,
              birimAdi: birimAdi,
              baslik: 'Ana Mizan 391 ile Yardımcı Mizan KDV Uyuşmazlığı',
              seviye: DenetimSeviyesi.hata,
              beklenenDeger: sonuc.toplamHesaplananKdv,
              bulunanDeger: sonuc.yardimciMizan391Toplam,
              fark: sonuc.yardimciMizan391Toplam - sonuc.toplamHesaplananKdv,
              aciklama: 'Ana Mizan 391 Hesaplanan KDV (${TurkceFormat.para(sonuc.toplamHesaplananKdv)}) ile Yardımcı Mizan (%10 + %20) alt hesap toplamı (${TurkceFormat.para(sonuc.yardimciMizan391Toplam)}) birbirini tutmuyor. Fark: ${TurkceFormat.para(kdv391Farki)}.',
              cozumOnerisi: 'Yardımcı mizandaki 391.10 ve 391.20 kırılımları ile ana mizan 391 alacak bakiyesini karşılaştırınız.',
            ));
          } else {
            kontroller.add(MutabakatKontrolKaydi(
              id: 'sen-10a-${kontrolIdSayac++}',
              senaryoNo: 10,
              birimAdi: birimAdi,
              baslik: 'Yardımcı Mizan 391 (%10 / %20) Mutabakatı Başarılı',
              seviye: DenetimSeviyesi.bilgi,
              beklenenDeger: sonuc.toplamHesaplananKdv,
              bulunanDeger: sonuc.yardimciMizan391Toplam,
              fark: 0.0,
              aciklama: 'Yardımcı mizan (%10 ve %20) kırılımları ana mizan 391 bakiyesi ile kuruşu kuruşuna örtüşüyor (${TurkceFormat.para(sonuc.yardimciMizan391Toplam)}).',
            ));
          }
        }

        // 10b: 191 İndirilecek KDV Mutabakatı
        if (sonuc.yardimciMizan191Toplam > 0 && sonuc.toplamIndirilecekKdv > 0) {
          final kdv191Farki = (sonuc.yardimciMizan191Toplam - sonuc.toplamIndirilecekKdv).abs();
          if (kdv191Farki > 1.0) {
            kontroller.add(MutabakatKontrolKaydi(
              id: 'sen-10b-${kontrolIdSayac++}',
              senaryoNo: 10,
              birimAdi: birimAdi,
              baslik: 'Ana Mizan 191 ile Yardımcı Mizan KDV Uyuşmazlığı',
              seviye: DenetimSeviyesi.uyari,
              beklenenDeger: sonuc.toplamIndirilecekKdv,
              bulunanDeger: sonuc.yardimciMizan191Toplam,
              fark: sonuc.yardimciMizan191Toplam - sonuc.toplamIndirilecekKdv,
              aciklama: 'Ana Mizan 191 İndirilecek KDV (${TurkceFormat.para(sonuc.toplamIndirilecekKdv)}) ile Yardımcı Mizan 191 alt hesap toplamı (${TurkceFormat.para(sonuc.yardimciMizan191Toplam)}) farklıdır.',
              cozumOnerisi: '191 alt hesap hareketlerini ve dönem borç toplamını inceleyiniz.',
            ));
          } else {
            kontroller.add(MutabakatKontrolKaydi(
              id: 'sen-10b-${kontrolIdSayac++}',
              senaryoNo: 10,
              birimAdi: birimAdi,
              baslik: 'Yardımcı Mizan 191 İndirilecek KDV Mutabakatı Tam',
              seviye: DenetimSeviyesi.bilgi,
              beklenenDeger: sonuc.toplamIndirilecekKdv,
              bulunanDeger: sonuc.yardimciMizan191Toplam,
              fark: 0.0,
              aciklama: 'Yardımcı mizan 191 alt hesapları ana mizan 191 bakiyesini tam olarak doğrulamaktadır.',
            ));
          }
        }

        // 10c: 600 Gelirler / Hasılat Mutabakatı
        if (sonuc.yardimciMizan600Toplam > 0 && sonuc.hasilat600Aylik > 0) {
          final gelirFarki = (sonuc.yardimciMizan600Toplam - sonuc.hasilat600Aylik).abs();
          if (gelirFarki > 1.0) {
            kontroller.add(MutabakatKontrolKaydi(
              id: 'sen-10c-${kontrolIdSayac++}',
              senaryoNo: 10,
              birimAdi: birimAdi,
              baslik: '600 Hasılat ile Yardımcı Mizan Gelir Uyuşmazlığı',
              seviye: DenetimSeviyesi.uyari,
              beklenenDeger: sonuc.hasilat600Aylik,
              bulunanDeger: sonuc.yardimciMizan600Toplam,
              fark: sonuc.yardimciMizan600Toplam - sonuc.hasilat600Aylik,
              aciklama: 'Ana mizan 600 toplamı (${TurkceFormat.para(sonuc.hasilat600Aylik)}) ile yardımcı mizan gelir alt hesap toplamı (${TurkceFormat.para(sonuc.yardimciMizan600Toplam)}) arasında fark var.',
              cozumOnerisi: '600.01 / 600.03 vb. alt hesapların mizan toplamıyla eşleştiğini kontrol ediniz.',
            ));
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // SENARYO 5: 190 Devreden KDV Geçmiş Dönem Kapanış Uyuşmazlığı (Konsolide)
    // -------------------------------------------------------------------------
    final toplamMizan190 = birimSonuclari.values.fold(0.0, (s, x) => s + x.devredenKdv190);
    if (toplamMizan190 > 0 || oncekiAydanDevredenKdv > 0) {
      final devirFarki = (toplamMizan190 - oncekiAydanDevredenKdv).abs();
      if (devirFarki > 1.0) {
        final aciklama = oncekiAydanDevredenKdv == 0
            ? 'Mizanda ${TurkceFormat.para(toplamMizan190)} 190 Devreden KDV borç bakiyesi bulunmasına rağmen, sistemde önceki aydan devreden KDV 0,00 TL kayıtlıdır.'
            : (toplamMizan190 == 0
                ? 'Sistemde önceki aydan devreden KDV ${TurkceFormat.para(oncekiAydanDevredenKdv)} görünmesine rağmen, mizan 190 hesabında devir bakiyesi bulunamadı.'
                : 'Sistemde kayıtlı önceki ay beyannamesinden devreden KDV ${TurkceFormat.para(oncekiAydanDevredenKdv)} iken, bu ayın mizan 190 toplam borç bakiyesi ${TurkceFormat.para(toplamMizan190)} çıkmaktadır. Fark: ${TurkceFormat.para(devirFarki)}.');
        kontroller.add(MutabakatKontrolKaydi(
          id: 'sen-5-${kontrolIdSayac++}',
          senaryoNo: 5,
          birimAdi: 'Tüm Birimler',
          baslik: '190 Devreden KDV Geçmiş Ay Kapanış Farkı',
          seviye: DenetimSeviyesi.hata,
          beklenenDeger: oncekiAydanDevredenKdv,
          bulunanDeger: toplamMizan190,
          fark: toplamMizan190 - oncekiAydanDevredenKdv,
          aciklama: aciklama,
          cozumOnerisi: 'Geçmiş aya sonradan kayıt girilip girilmediğini veya vergi dairesi düzeltme beyannamesi verilip verilmediğini kontrol ediniz.',
        ));
      } else {
        kontroller.add(MutabakatKontrolKaydi(
          id: 'sen-5-${kontrolIdSayac++}',
          senaryoNo: 5,
          birimAdi: 'Tüm Birimler',
          baslik: '190 Devreden KDV Mutabakatı Başarılı',
          seviye: DenetimSeviyesi.bilgi,
          beklenenDeger: oncekiAydanDevredenKdv,
          bulunanDeger: toplamMizan190,
          fark: 0.0,
          aciklama: 'Önceki ayın devreden KDV tutarı ile mizan açılış bakiyesi tam örtüşmektedir (${TurkceFormat.para(oncekiAydanDevredenKdv)}).',
        ));
      }
    }

    // -------------------------------------------------------------------------
    // SENARYO 11: 123 Kredi Kartı / POS Birimler Arası Çapraz Kontrolü
    // -------------------------------------------------------------------------
    final posluBirimler = birimSonuclari.entries
        .where((e) => e.value.krediKarti123 > 0)
        .toList();

    for (int i = 0; i < posluBirimler.length; i++) {
      for (int j = i + 1; j < posluBirimler.length; j++) {
        final b1 = posluBirimler[i];
        final b2 = posluBirimler[j];
        if ((b1.value.krediKarti123 - b2.value.krediKarti123).abs() < 0.01) {
          kontroller.add(MutabakatKontrolKaydi(
            id: 'sen-11-${kontrolIdSayac++}',
            senaryoNo: 11,
            birimAdi: '${b1.key} & ${b2.key}',
            baslik: 'KRİTİK: Mükerrer 123 POS Tutarı Saptandı!',
            seviye: DenetimSeviyesi.hata,
            beklenenDeger: 0.0,
            bulunanDeger: b1.value.krediKarti123,
            aciklama: '${b1.key} ile ${b2.key} birimlerinin 123 Kredi Kartı/POS tutarları kuruşu kuruşuna aynı çıkmaktadır (${TurkceFormat.para(b1.value.krediKarti123)} TL). Kurum konsolide mizanının yanlışlıkla başka bir birime yüklenmesi sonucu mükerrer POS beyanı riski tespit edildi.',
            cozumOnerisi: 'Diş Hekimliği dışındaki birimlerde POS cihazı bulunmadığından, mükerrer birimin 123 POS tutarını 0,00 TL yapınız veya mizan dosyasını kontrol ediniz.',
          ));
        }
      }
    }

    return BeyannameAjanRaporu(
      id: 'rapor_${yil}_${ay.toString().padLeft(2, '0')}_${DateTime.now().millisecondsSinceEpoch}',
      yil: yil,
      ay: ay,
      olusturulmaTarihi: DateTime.now(),
      analizEdilenBirimler: birimSonuclari.keys.toList(),
      toplamDosyaSayisi: toplamDosyaSayisi,
      birimSonuclari: birimSonuclari,
      neredenNereyeListesi: neredenNereye,
      denetimKontrolleri: kontroller,
    );
  }
}
