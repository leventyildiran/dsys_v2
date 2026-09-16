import 'package:flutter_test/flutter_test.dart';
import 'package:dsys_v2/features/personel/models/personel_model.dart';
import 'package:dsys_v2/features/personel/services/personel_service.dart';

void main() {
  group('PersonelModel Tests', () {
    test('tamAdGosterim returns unvan + adSoyad + birim when present', () {
      final p = PersonelModel(
        id: '1',
        adSoyad: 'Ahmet Yılmaz',
        unvan: 'Prof. Dr.',
        birimAdi: 'Mühendislik Fakültesi',
        personelTuru: 'Akademik',
      );
      expect(p.tamAdGosterim, equals('Prof. Dr. Ahmet Yılmaz (Mühendislik Fakültesi)'));
    });

    test('tamAdGosterim without birim returns unvan + adSoyad', () {
      final p1 = PersonelModel(
        id: '2',
        adSoyad: 'Mehmet Demir',
        unvan: '',
      );
      expect(p1.tamAdGosterim, equals('Mehmet Demir'));

      final p2 = PersonelModel(
        id: '3',
        adSoyad: 'Mehmet Demir',
        unvan: 'Prof. Dr.',
      );
      expect(p2.tamAdGosterim, equals('Prof. Dr. Mehmet Demir'));
    });

    test('Serialization and Deserialization with new fields', () {
      final json = {
        'tcKimlikNo': '12345678901',
        'adSoyad': 'Ayşe Kaya',
        'unvan': 'Doç. Dr.',
        'birimAdi': 'Tıp Fakültesi',
        'eposta': 'ayse.kaya@usak.edu.tr',
        'telefon': '1234',
        'personelTuru': 'Akademik',
        'kaynak': 'rehber',
        'rehberId': '567',
      };

      final p = PersonelModel.fromMap('doc_123', json);
      expect(p.id, equals('doc_123'));
      expect(p.adSoyad, equals('Ayşe Kaya'));
      expect(p.birimAdi, equals('Tıp Fakültesi'));
      expect(p.eposta, equals('ayse.kaya@usak.edu.tr'));
      expect(p.personelTuru, equals('Akademik'));
      expect(p.kaynak, equals('rehber'));
      expect(p.rehberId, equals('567'));

      final serialized = p.toMap();
      expect(serialized['birimAdi'], equals('Tıp Fakültesi'));
      expect(serialized['eposta'], equals('ayse.kaya@usak.edu.tr'));
    });
  });

  group('PersonelService Normalization Tests', () {
    test('normalizeMetin handles Turkish characters and casing correctly', () {
      expect(PersonelService.normalizeMetin('  ahmet   yılmaz  '), equals('ahmet   yilmaz'));
      expect(PersonelService.normalizeMetin('MEHMET ÖZTÜRK'), equals('mehmet ozturk'));
      expect(PersonelService.normalizeMetin('ŞEFİKA ÇAĞLAR'), equals('sefika caglar'));
    });
  });
}
