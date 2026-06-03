import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const DsysApp());
}

class DsysApp extends StatelessWidget {
  const DsysApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DSYS v2',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const Scaffold(
        body: Center(
          child: Text('DSYS v2 Firebase Kasasına Başarıyla Bağlandı!'),
        ),
      ),
    );
  }
}
