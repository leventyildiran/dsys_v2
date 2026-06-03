import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase yapılandırma sınıfı.
///
/// Bu dosya `flutterfire configure` komutuyla otomatik oluşturulmalıdır.
/// Aşağıdaki değerler placeholder'dır; gerçek proje bilgileriyle
/// güncellenmelidir.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions Linux için yapılandırılmamıştır.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions bu platform için yapılandırılmamıştır.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBvW5QXKJVSbcyW3ELIuBpd3k5R6GsGaV8',
    appId: '1:752318324432:web:b452cf72fade563b7bc8d5',
    messagingSenderId: '752318324432',
    projectId: 'dsys-44b8e',
    authDomain: 'dsys-44b8e.firebaseapp.com',
    storageBucket: 'dsys-44b8e.firebasestorage.app',
  );

  // Not: macOS ve Windows platformları henüz Firebase Console'da yapılandırılmamıştır.
  // Aktif platformlar: Web, Android, iOS.
  // Bu platformlar gerektiğinde `flutterfire configure` ile güncellenecektir.

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDW_rTwCsZrIaLj4y4jwy-AjVZNSj9RS2o',
    appId: '1:752318324432:android:090bb7f4ca18a62c7bc8d5',
    messagingSenderId: '752318324432',
    projectId: 'dsys-44b8e',
    storageBucket: 'dsys-44b8e.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC_1ii-bymR8isIz4Vlt_hWSq82dOI0DqA',
    appId: '1:752318324432:ios:d82fb87c4cf3a1927bc8d5',
    messagingSenderId: '752318324432',
    projectId: 'dsys-44b8e',
    storageBucket: 'dsys-44b8e.firebasestorage.app',
    iosBundleId: 'tr.edu.usak.dsys',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR-API-KEY',
    appId: '1:000000000000:macos:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'dsys-usak',
    storageBucket: 'dsys-usak.appspot.com',
    iosBundleId: 'com.usak.dsys',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'YOUR-API-KEY',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'dsys-usak',
    authDomain: 'dsys-usak.firebaseapp.com',
    storageBucket: 'dsys-usak.appspot.com',
  );
}
