import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../../core/turkce_format.dart';

/// GİB e-Fatura / e-Arşiv Karekodundan veya gömülü UBL-TR XML akışından
/// %100 kesinlikle çıkarılan resmi fatura verisi.
class GibKarekodFaturaVerisi {
  final String saticiVknTckn;
  final String aliciVknTckn;
  final String saticiUnvan;
  final String faturaNo;
  final String faturaTarihi; // GG.AA.YYYY
  final String faturaTipi; // SATIS, TEVKIFAT, ISTISNA, IADE
  final String senaryo;
  final String ettn;
  final double matrah;
  final int kdvOrani;
  final double kdvTutari;
  final double vergiDahilToplam;
  final double odenecekTutar;
  final double tevkifatTutari;
  final String tevkifatOrani; // Örn: "9/10", "7/10", "5/10"

  const GibKarekodFaturaVerisi({
    required this.saticiVknTckn,
    this.aliciVknTckn = '',
    this.saticiUnvan = '',
    this.faturaNo = '',
    this.faturaTarihi = '',
    this.faturaTipi = 'SATIS',
    this.senaryo = '',
    this.ettn = '',
    required this.matrah,
    this.kdvOrani = 20,
    required this.kdvTutari,
    required this.vergiDahilToplam,
    required this.odenecekTutar,
    this.tevkifatTutari = 0.0,
    this.tevkifatOrani = '',
  });

  bool get tevkifatliMi =>
      tevkifatTutari > 0.01 || faturaTipi.toUpperCase().contains('TEVKIFAT');

  /// Beyanname KDV-2 tevkifat listesi formatına dönüştürür.
  Map<String, dynamic> toBeyannameTevkifatMap({String? yedekFirmaAdi}) {
    final EtkinFirma = saticiUnvan.trim().isNotEmpty
        ? saticiUnvan.trim()
        : ((yedekFirmaAdi != null && yedekFirmaAdi.trim().isNotEmpty)
            ? yedekFirmaAdi.trim()
            : 'VKN: $saticiVknTckn');
    return {
      'firmaAdi': EtkinFirma,
      'vergiTcNo': saticiVknTckn,
      'faturaNo': faturaNo,
      'faturaTarihi': faturaTarihi,
      'matrahTutari': matrah,
      'kdvOrani': kdvOrani,
      'kdvTutari': kdvTutari,
      'tevkifatTutari': tevkifatTutari > 0
          ? tevkifatTutari
          : double.parse((kdvTutari * 0.9).toStringAsFixed(2)),
      'tevkifatOrani': tevkifatOrani.isNotEmpty ? tevkifatOrani : '9/10',
      'kaynak': 'GİB Karekod / UBL (Yerel %100 Kesin)',
    };
  }

  /// Yerel kural motorlarının (FaturaOfflineParser ve MizanDeterministikParser)
  /// doğrudan okuyabileceği standart Türkçe fatura metin bloğu üretir.
  String toSentetikFaturaMetni({String? ekUnvan}) {
    final unvan = saticiUnvan.trim().isNotEmpty
        ? saticiUnvan.trim()
        : (ekUnvan != null && ekUnvan.trim().isNotEmpty
            ? ekUnvan.trim()
            : 'DÜZENLEYEN FİRMA ($saticiVknTckn)');
    final trMatrah = TurkceFormat.para(matrah);
    final trKdv = TurkceFormat.para(kdvTutari);
    final trVergiDahil = TurkceFormat.para(vergiDahilToplam);
    final trOdenecek = TurkceFormat.para(odenecekTutar);
    final trTevkifat = TurkceFormat.para(tevkifatTutari);
    final oranEtiket = tevkifatOrani.isNotEmpty ? tevkifatOrani : '9/10';

    return '''
=== GİB RESMİ KAREKOD / UBL VERİSİ ===
Düzenleyen Firma: $unvan
VKN: $saticiVknTckn
Alıcı VKN: $aliciVknTckn
Fatura No: $faturaNo
Fatura Tarihi: $faturaTarihi
ETTN: $ettn
Fatura Tipi: $faturaTipi
Mal Hizmet Toplam Tutarı: $trMatrah TL
KDV Matrahı (%$kdvOrani): $trMatrah TL
Hesaplanan KDV (%$kdvOrani): $trKdv TL
${tevkifatTutari > 0 ? 'Hesaplanan KDV Tevkifat ($oranEtiket): $trTevkifat TL\nTevkifat Oranı: $oranEtiket' : ''}
Vergiler Dahil Toplam Tutar: $trVergiDahil TL
Ödenecek Tutar: $trOdenecek TL
''';
  }
}

/// GİB e-Belge Karekod (QR) JSON ve gömülü UBL-TR XML çözücü.
class GibKarekodVeUblCozucu {
  const GibKarekodVeUblCozucu._();

  /// Karekod içinden çıkan JSON metnini çözümler.
  static GibKarekodFaturaVerisi? cozGibKarekodJson(String rawQr) {
    final trimmed = rawQr.trim();
    if (!trimmed.contains('{') || !trimmed.contains('}')) return null;

    try {
      final start = trimmed.indexOf('{');
      final end = trimmed.lastIndexOf('}');
      if (start < 0 || end <= start) return null;
      final jsonSlice = trimmed.substring(start, end + 1);
      final decoded = jsonDecode(jsonSlice);
      if (decoded is! Map) return null;

      // Anahtarları küçük harfe normalize et
      final norm = <String, dynamic>{};
      for (final entry in decoded.entries) {
        norm[entry.key.toString().toLowerCase().trim()] = entry.value;
      }

      final saticiVkn = _sadeceRakam(
        norm['vkntckn'] ?? norm['saticivkntckn'] ?? norm['vkn'] ?? norm['tckn'],
      );
      if (saticiVkn.length != 10 && saticiVkn.length != 11) return null;

      final aliciVkn = _sadeceRakam(norm['avkntckn'] ?? norm['alicivkntckn']);
      final faturaNo = (norm['no'] ?? norm['faturano'] ?? '').toString().trim();
      final tarihRaw = (norm['tarih'] ?? norm['faturatarihi'] ?? '').toString().trim();
      final faturaTarihi = _normalizeTarih(tarihRaw);
      final tip = (norm['tip'] ?? norm['faturatipi'] ?? 'SATIS').toString().trim().toUpperCase();
      final senaryo = (norm['senaryo'] ?? '').toString().trim();
      final ettn = (norm['ettn'] ?? norm['uuid'] ?? '').toString().trim();
      final saticiUnvan = (norm['unvan'] ?? norm['saticiunvan'] ?? norm['firmaadi'] ?? '').toString().trim();

      double matrah = _parseQrSayi(norm['malhizmettoplam'] ?? norm['matrah']);
      double kdvTutari = 0.0;
      int kdvOrani = 20;

      // kdvmatrah(20), hesaplanankdv(20) gibi dinamik alanları tara
      double kdvMatrahToplam = 0.0;
      for (final entry in norm.entries) {
        final k = entry.key;
        if (k.startsWith('kdvmatrah')) {
          final m = _parseQrSayi(entry.value);
          if (m > 0) kdvMatrahToplam += m;
          final oranMatch = RegExp(r'\((\d+)\)').firstMatch(k);
          if (oranMatch != null && m > 0) {
            kdvOrani = int.tryParse(oranMatch.group(1)!) ?? kdvOrani;
          }
        } else if (k.startsWith('hesaplanankdv') && !k.contains('tevkifat')) {
          final kv = _parseQrSayi(entry.value);
          if (kv > 0) kdvTutari += kv;
          final oranMatch = RegExp(r'\((\d+)\)').firstMatch(k);
          if (oranMatch != null && kv > 0) {
            kdvOrani = int.tryParse(oranMatch.group(1)!) ?? kdvOrani;
          }
        }
      }

      if (matrah <= 0 && kdvMatrahToplam > 0) {
        matrah = kdvMatrahToplam;
      }
      if (matrah <= 0) return null;

      double vergiDahil = _parseQrSayi(
        norm['vergidahil'] ?? norm['vergilerdahil'] ?? norm['toplam'],
      );
      if (vergiDahil <= 0) {
        vergiDahil = double.parse((matrah + kdvTutari).toStringAsFixed(2));
      }

      double odenecek = _parseQrSayi(
        norm['odenecek'] ?? norm['odenecektutar'] ?? norm['net'],
      );
      if (odenecek <= 0) {
        odenecek = vergiDahil;
      }

      double tevkifatTutari = _parseQrSayi(
        norm['tevkifattutari'] ?? norm['hesaplanankdvtevkifat'],
      );
      // GİB karekodunda vergidahil ile odenecek arasındaki fark doğrudan KDV Tevkifat tutarıdır!
      if (tevkifatTutari <= 0 && vergiDahil > odenecek + 0.05 && kdvTutari > 0) {
        final fark = double.parse((vergiDahil - odenecek).toStringAsFixed(2));
        if (fark <= kdvTutari + 0.5) {
          tevkifatTutari = fark;
        }
      }

      String tevkifatOrani = (norm['tevkifatorani'] ?? '').toString().trim();
      if (tevkifatOrani.isEmpty && tevkifatTutari > 0 && kdvTutari > 0) {
        final pay = ((tevkifatTutari / kdvTutari) * 10).round().clamp(1, 10);
        tevkifatOrani = '$pay/10';
      }

      return GibKarekodFaturaVerisi(
        saticiVknTckn: saticiVkn,
        aliciVknTckn: aliciVkn,
        saticiUnvan: saticiUnvan,
        faturaNo: faturaNo,
        faturaTarihi: faturaTarihi,
        faturaTipi: tip,
        senaryo: senaryo,
        ettn: ettn,
        matrah: matrah,
        kdvOrani: kdvOrani,
        kdvTutari: kdvTutari,
        vergiDahilToplam: vergiDahil,
        odenecekTutar: odenecek,
        tevkifatTutari: tevkifatTutari,
        tevkifatOrani: tevkifatOrani,
      );
    } catch (_) {
      return null;
    }
  }

  /// PDF veya XML dosyasının ham baytları (raw stream) içinde gömülü GİB Karekod JSON
  /// veya UBL-TR XML verisi olup olmadığını 0ms içinde tarar.
  static List<GibKarekodFaturaVerisi> hamBaytlardanGomuluVeriCikar(Uint8List bytes) {
    final sonuclar = <GibKarekodFaturaVerisi>[];
    if (bytes.isEmpty) return sonuclar;

    // 20 MB üstü ham taramayı sınırla
    final slice = bytes.length > 12 * 1024 * 1024
        ? bytes.sublist(0, 12 * 1024 * 1024)
        : bytes;
    final rawText = latin1.decode(slice, allowInvalid: true);

    // 1) Gömülü GİB Karekod JSON araması: {"vkntckn": ...}
    final qrJsonRegex = RegExp(
      r'\{[^{}]{10,1200}"vkntckn"\s*:\s*"\d{10,11}"[^{}]{10,1200}\}',
      caseSensitive: false,
    );
    for (final m in qrJsonRegex.allMatches(rawText)) {
      final veri = cozGibKarekodJson(m.group(0)!);
      if (veri != null && !_mukerrerMi(sonuclar, veri)) {
        sonuclar.add(veri);
      }
    }

    // 2) Gömülü UBL-TR XML araması (<Invoice ...> ... </Invoice>)
    if (rawText.contains('AccountingSupplierParty') && rawText.contains('TaxExclusiveAmount')) {
      String utf8Text;
      try {
        utf8Text = utf8.decode(slice, allowMalformed: true);
      } catch (_) {
        utf8Text = rawText;
      }
      final ublVerisi = _cozUblTrXml(utf8Text);
      if (ublVerisi != null && !_mukerrerMi(sonuclar, ublVerisi)) {
        sonuclar.add(ublVerisi);
      }
    }

    return sonuclar;
  }

  /// UBL-TR 1.2 e-Fatura XML içeriğinden resmi alanları çıkarır.
  static GibKarekodFaturaVerisi? _cozUblTrXml(String xml) {
    try {
      // Satıcı bilgileri
      final supplierBlock = RegExp(
        r'<cac:AccountingSupplierParty>([\s\S]*?)</cac:AccountingSupplierParty>',
      ).firstMatch(xml)?.group(1) ?? '';
      final saticiVkn = RegExp(
        r'<cbc:ID[^>]*schemeID="(?:VKN|TCKN)"[^>]*>(\d{10,11})</cbc:ID>',
      ).firstMatch(supplierBlock)?.group(1) ?? '';
      if (saticiVkn.isEmpty) return null;

      final unvan = RegExp(r'<cac:PartyName>\s*<cbc:Name>([^<]+)</cbc:Name>')
              .firstMatch(supplierBlock)
              ?.group(1)
              ?.trim() ??
          '';

      // Alıcı VKN
      final customerBlock = RegExp(
        r'<cac:AccountingCustomerParty>([\s\S]*?)</cac:AccountingCustomerParty>',
      ).firstMatch(xml)?.group(1) ?? '';
      final aliciVkn = RegExp(
        r'<cbc:ID[^>]*schemeID="(?:VKN|TCKN)"[^>]*>(\d{10,11})</cbc:ID>',
      ).firstMatch(customerBlock)?.group(1) ?? '';

      final faturaNo = RegExp(r'<cbc:ID>([A-Z0-9]{16})</cbc:ID>')
              .firstMatch(xml)
              ?.group(1) ??
          '';
      final tarih = _normalizeTarih(
        RegExp(r'<cbc:IssueDate>([^<]+)</cbc:IssueDate>')
                .firstMatch(xml)
                ?.group(1) ??
            '',
      );
      final tip = RegExp(r'<cbc:InvoiceTypeCode>([^<]+)</cbc:InvoiceTypeCode>')
              .firstMatch(xml)
              ?.group(1) ??
          'SATIS';
      final ettn = RegExp(r'<cbc:UUID>([^<]+)</cbc:UUID>')
              .firstMatch(xml)
              ?.group(1) ??
          '';

      // Parasal toplamlar (LegalMonetaryTotal)
      final monetaryBlock = RegExp(
        r'<cac:LegalMonetaryTotal>([\s\S]*?)</cac:LegalMonetaryTotal>',
      ).firstMatch(xml)?.group(1) ?? '';
      final matrah = _parseQrSayi(
        RegExp(r'<cbc:TaxExclusiveAmount[^>]*>([^<]+)</cbc:TaxExclusiveAmount>')
            .firstMatch(monetaryBlock)
            ?.group(1),
      );
      if (matrah <= 0) return null;

      final vergiDahil = _parseQrSayi(
        RegExp(r'<cbc:TaxInclusiveAmount[^>]*>([^<]+)</cbc:TaxInclusiveAmount>')
            .firstMatch(monetaryBlock)
            ?.group(1),
      );
      final odenecek = _parseQrSayi(
        RegExp(r'<cbc:PayableAmount[^>]*>([^<]+)</cbc:PayableAmount>')
            .firstMatch(monetaryBlock)
            ?.group(1),
      );

      // KDV ve Tevkifat
      final taxTotalBlock = RegExp(
        r'<cac:TaxTotal>([\s\S]*?)</cac:TaxTotal>',
      ).firstMatch(xml)?.group(1) ?? '';
      final kdvTutari = _parseQrSayi(
        RegExp(r'<cbc:TaxAmount[^>]*>([^<]+)</cbc:TaxAmount>')
            .firstMatch(taxTotalBlock)
            ?.group(1),
      );
      final kdvOrani = int.tryParse(
            RegExp(r'<cbc:Percent>(\d+)</cbc:Percent>')
                    .firstMatch(taxTotalBlock)
                    ?.group(1) ??
                '20',
          ) ??
          20;

      final withholdingBlock = RegExp(
        r'<cac:WithholdingTaxTotal>([\s\S]*?)</cac:WithholdingTaxTotal>',
      ).firstMatch(xml)?.group(1) ?? '';
      double tevkifatTutari = _parseQrSayi(
        RegExp(r'<cbc:TaxAmount[^>]*>([^<]+)</cbc:TaxAmount>')
            .firstMatch(withholdingBlock)
            ?.group(1),
      );
      if (tevkifatTutari <= 0 && vergiDahil > odenecek + 0.05 && odenecek > 0) {
        tevkifatTutari = double.parse((vergiDahil - odenecek).toStringAsFixed(2));
      }

      String tevkifatOrani = '';
      final tevPercent = int.tryParse(
        RegExp(r'<cbc:Percent>(\d+)</cbc:Percent>')
                .firstMatch(withholdingBlock)
                ?.group(1) ??
            '',
      );
      if (tevPercent != null && tevPercent > 0) {
        tevkifatOrani = '${(tevPercent / 10).round()}/10';
      } else if (tevkifatTutari > 0 && kdvTutari > 0) {
        final pay = ((tevkifatTutari / kdvTutari) * 10).round().clamp(1, 10);
        tevkifatOrani = '$pay/10';
      }

      return GibKarekodFaturaVerisi(
        saticiVknTckn: saticiVkn,
        aliciVknTckn: aliciVkn,
        saticiUnvan: unvan,
        faturaNo: faturaNo,
        faturaTarihi: tarih,
        faturaTipi: tip,
        ettn: ettn,
        matrah: matrah,
        kdvOrani: kdvOrani,
        kdvTutari: kdvTutari,
        vergiDahilToplam: vergiDahil > 0 ? vergiDahil : matrah + kdvTutari,
        odenecekTutar: odenecek > 0 ? odenecek : vergiDahil,
        tevkifatTutari: tevkifatTutari,
        tevkifatOrani: tevkifatOrani,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _mukerrerMi(List<GibKarekodFaturaVerisi> liste, GibKarekodFaturaVerisi yeni) {
    return liste.any((x) =>
        (x.faturaNo.isNotEmpty && x.faturaNo == yeni.faturaNo) ||
        (x.saticiVknTckn == yeni.saticiVknTckn && (x.matrah - yeni.matrah).abs() < 0.05));
  }

  static String _sadeceRakam(dynamic val) {
    if (val == null) return '';
    return val.toString().replaceAll(RegExp(r'[^\d]'), '');
  }

  static String _normalizeTarih(String raw) {
    final s = raw.trim();
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    if (iso != null) {
      return '${iso.group(3)}.${iso.group(2)}.${iso.group(1)}';
    }
    return s;
  }

  /// GİB Karekod içindeki sayılar hem "15000.00" (nokta ondalık) hem de "15.000,00" (Türkçe format) olabilir.
  static double _parseQrSayi(dynamic raw) {
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();
    final s = raw.toString().trim().replaceAll(RegExp(r'[^\d.,-]'), '');
    if (s.isEmpty) return 0.0;
    // Hem nokta hem virgül varsa Türkçe/Avrupa ayrımı yap
    if (s.contains(',') && s.contains('.')) {
      if (s.lastIndexOf(',') > s.lastIndexOf('.')) {
        return double.tryParse(s.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;
      } else {
        return double.tryParse(s.replaceAll(',', '')) ?? 0.0;
      }
    }
    // Sadece nokta varsa ve sondan 3. karakter değilse (örn: "15000.00" veya "1500.5") standart nokta ondalıktır!
    if (s.contains('.') && !s.contains(',')) {
      final parts = s.split('.');
      if (parts.length == 2 && parts.last.length <= 2) {
        return double.tryParse(s) ?? 0.0;
      }
    }
    return TurkceFormat.parseSayi(s);
  }
}
