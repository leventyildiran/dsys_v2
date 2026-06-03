import 'package:flutter/material.dart';

class Institution {
  final String id;
  final String name;
  final bool isActive;
  final String licenseEndDate;
  final int userCount;

  Institution({
    required this.id,
    required this.name,
    required this.isActive,
    required this.licenseEndDate,
    required this.userCount,
  });
}

class AdminProvider extends ChangeNotifier {
  final List<Institution> _institutions = [
    Institution(
      id: '1',
      name: 'Uşak Üniversitesi Döner Sermaye',
      isActive: true,
      licenseEndDate: '31.12.2026',
      userCount: 45,
    ),
    Institution(
      id: '2',
      name: 'X Üniversitesi Döner Sermaye',
      isActive: false,
      licenseEndDate: '01.01.2025',
      userCount: 12,
    ),
    Institution(
      id: '3',
      name: 'Y Eğitim ve Araştırma Hastanesi',
      isActive: true,
      licenseEndDate: '15.08.2027',
      userCount: 120,
    ),
  ];

  List<Institution> get institutions => _institutions;

  int get totalInstitutions => _institutions.length;
  int get activeInstitutions => _institutions.where((i) => i.isActive).length;
  int get totalUsers => _institutions.fold(0, (sum, i) => sum + i.userCount);
}
