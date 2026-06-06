import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsys_v2/features/yk_karar/models/yk_karar_model.dart';
import 'package:dsys_v2/features/yk_karar/services/belge_uretim_servisi.dart';
import 'package:dsys_v2/core/models/sistem_ayarlari_model.dart';

// BelgeUretimServisi içerisindeki private _buildDocxFromTemplate metoduna erişim olmadığı için,
// o metodu test edebilmek amacıyla geçici olarak public bir wrapper method açmamız veya 
// pub spec içerisinde test edebilmek için içeriğini kopyalayabiliriz.
// Ancak Dart'ta private metodlara testten erişilemiyor.

void main() {
  test('Test Markdown Table to Word XML Generation', () {
    final markdownContent = '''
### KARAR NO: 2026/12
Orhan Şaşmaz Tekstil İnşaat Turizm Sanayi ve Ticaret Ltd. Şti. firmasının talep ettiği "Danışmanlık Hizmeti" için 1 aylık süreyle görevlendirilen öğretim elemanının katkı oranlarının aşağıdaki şekilde belirlenmesine oy birliği ile karar verilmiştir.

| Adı Soyadı | Faaliyet Türü | Adet/Saat |
|---|---|---|
| Öğr. Gör. Dr. Neslihan ÖPÖZ VURAL | Tasarım | 20 Adet |
| Öğr. Gör. Dr. Neslihan ÖPÖZ VURAL | Teknik Uygulama | 20 Saat |
| | | Boş Hücre Test |

Karar verilmiştir.
''';

    final resultXml = BelgeUretimServisi.buildDocumentBodyXml(markdownContent, '', null);
    
    // Check if the XML table generated has correct boundaries and font size
    expect(resultXml.contains('<w:tbl>'), true);
    expect(resultXml.contains('Neslihan'), true);
    expect(resultXml.contains('<w:color w:val="auto"/>') || resultXml.contains('w:color="auto"'), true); // checking black border
    expect(resultXml.contains('B8CCE4'), true); // checking header fill
    expect(resultXml.contains('<w:sz w:val="22"/>'), true); // 11pt font size
  });
}
