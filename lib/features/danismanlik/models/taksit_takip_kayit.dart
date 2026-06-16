import 'danismanlik_model.dart';
import 'taksit_model.dart';

/// Konsolide takip listesinde taksit + üst danışmanlık bağlamı.
class TaksitTakipKayit {
  const TaksitTakipKayit({
    required this.danismanlikId,
    required this.danismanlik,
    required this.taksit,
  });

  final String danismanlikId;
  final DanismanlikModel danismanlik;
  final TaksitModel taksit;

  String get firmaEtiket =>
      danismanlik.firmaUnvan?.isNotEmpty == true
          ? danismanlik.firmaUnvan!
          : danismanlik.konusu;

  String get birimEtiket => danismanlik.birimKisaAd ?? danismanlik.birimId;
}
