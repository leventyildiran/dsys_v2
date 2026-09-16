import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsys_v2/core/turkce_format.dart';

void main() {
  group('TurkceFormat para ve sayı parse testleri', () {
    test('binlikNoktaEkle doğru çalışır', () {
      expect(TurkceFormat.binlikNoktaEkle('1000'), '1.000');
      expect(TurkceFormat.binlikNoktaEkle('1000000'), '1.000.000');
      expect(TurkceFormat.binlikNoktaEkle('500'), '500');
      expect(TurkceFormat.binlikNoktaEkle(''), '');
    });

    test('parseSayi Türkçe formatları eksiksiz çözer', () {
      expect(TurkceFormat.parseSayi('1.000.000,00'), 1000000.0);
      expect(TurkceFormat.parseSayi('1.000.000'), 1000000.0);
      expect(TurkceFormat.parseSayi('1000000'), 1000000.0);
      expect(TurkceFormat.parseSayi('4.420,93'), 4420.93);
      expect(TurkceFormat.parseSayi('4420,93'), 4420.93);
      expect(TurkceFormat.parseSayi('4420.93'), 4420.93);
      expect(TurkceFormat.parseSayi('1.000'), 1000.0);
      expect(TurkceFormat.parseSayi('25.000'), 25000.0);
      expect(TurkceFormat.parseSayi('0,50'), 0.50);
      expect(TurkceFormat.parseSayi('0'), 0.0);
      expect(TurkceFormat.parseSayi(''), 0.0);
    });
  });

  group('TurkceParaInputFormatter canlı yazma testleri', () {
    const formatter = TurkceParaInputFormatter();

    TextEditingValue type(String oldText, String newText) {
      return formatter.formatEditUpdate(
        TextEditingValue(
          text: oldText,
          selection: TextSelection.collapsed(offset: oldText.length),
        ),
        TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        ),
      );
    }

    test('1000000 yazıldığında adım adım 1.000.000 yapar', () {
      var val = type('', '1');
      expect(val.text, '1');

      val = type('1', '10');
      expect(val.text, '10');

      val = type('10', '100');
      expect(val.text, '100');

      val = type('100', '1000');
      expect(val.text, '1.000');

      val = type('1.000', '1.0000');
      expect(val.text, '10.000');

      val = type('10.000', '10.0000');
      expect(val.text, '100.000');

      val = type('100.000', '100.0000');
      expect(val.text, '1.000.000');
      expect(val.selection.extentOffset, 9);
    });

    test('Kullanıcı virgül ve kuruş girdiğinde korur', () {
      var val = type('1.000.000', '1.000.000,');
      expect(val.text, '1.000.000,');

      val = type('1.000.000,', '1.000.000,5');
      expect(val.text, '1.000.000,5');

      val = type('1.000.000,5', '1.000.000,50');
      expect(val.text, '1.000.000,50');

      // 3. kuruş basamağına izin vermez
      val = type('1.000.000,50', '1.000.000,508');
      expect(val.text, '1.000.000,50');
    });

    test('Numpad nokta basıldığında virgüle çevirir', () {
      var val = type('1.000', '1.000.');
      expect(val.text, '1.000,');

      val = type('1.000,', '1.000,75');
      expect(val.text, '1.000,75');
    });

    test('Silme (Backspace) durumunda noktaları otomatik düzenler', () {
      var val = type('1.000.000', '1.000.00');
      expect(val.text, '100.000');

      val = type('100.000', '100.00');
      expect(val.text, '10.000');
    });
  });
}
