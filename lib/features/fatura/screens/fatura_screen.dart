import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/batch_fatura_provider.dart';
import 'batch_verification_screen.dart';

class FaturaScreen extends StatelessWidget {
  const FaturaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BatchFaturaProvider(),
      child: const BatchVerificationScreen(),
    );
  }
}
