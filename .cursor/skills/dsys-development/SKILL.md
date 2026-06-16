---
name: Flutter & Firebase DSYS Development Skill
description: Core guidelines, business logic formulas, document formatting rules, and command automation playbooks for the Uşak University Döner Sermaye Yönetim Sistemi (DSYS).
tags: [flutter, firebase, dart, clean-architecture, agent, math-simulation, docx-generation, senior-engineer]
version: 1.1.0
---

# 🛠️ Uşak University DSYS - Agent Skill & Playbook

This document serves as the official machine-readable and human-readable Agent Skill for the Döner Sermaye Yönetim Sistemi (DSYS). The agent must read this file to guarantee adherence to project guidelines, clean coding standards, mathematical precision, and automated quality gates.

---

## 1. Core System Restrictions & Guardrails
*   **NO Anonymous/Guest Login:** Anonymous authentication (`signInAnonymously`) or guest sessions are **strictly prohibited**. Access is restricted entirely to authenticated email/password accounts via Firebase Authentication.
*   **Loading & Splash Protection:** All asynchronous operations (Futures, Streams) must handle loading, empty, and error states gracefully. Use loaders, shimmer effects, or splash overlays to block UI interaction during network requests to prevent `null` pointer exceptions and UI locks.
*   **Data Integrity Protection:** Never overwrite or corrupt existing files. Target modifications precisely to the requested lines or components.

---

## 2. Senior Flutter Architecture & Software Engineering Discipline (Ustalık Seviyesi)

The agent must act as a **Senior Flutter Architect and Master Software Engineer**, writing clean, scalable, and production-grade code. Adhere strictly to the following engineering patterns:

### 2.1 Clean Architecture & Separation of Concerns
*   **Layer Separation:** Keep business logic, network requests, and UI rendering decoupled.
    *   **Presentation Layer:** Widgets and UI pages. UI widgets must only read/display state and forward events.
    *   **Domain Layer:** Models, Entities, and Business Use Cases (pure Dart, no Firebase or UI dependencies).
    *   **Data Layer:** Repositories, Services, and Data Sources (Firestore APIs, Local Caching).
*   **Dependency Injection (DI):** Do not hardcode singleton instantiations inside widgets. Inject repositories and services into State Providers (e.g. `ChangeNotifier`) via constructor injection to maintain unit testability.

### 2.2 Advanced State Management & Lifecycle Discipline
*   **Rebuild Minimization:** Avoid using global `setState()` calls. Use selective rebuilding:
    *   Use `ValueNotifier<T>` and `ValueListenableBuilder<T>` for local widget updates.
    *   Use `Selector` instead of `Consumer` in Provider to listen only to specific fields of a class, preventing redundant UI updates.
*   **Lifecycle Leak Prevention:** Every controller (e.g., `TextEditingController`, `ScrollController`, `AnimationController`), focus node, listener, stream subscription, and timer **MUST** be explicitly disposed of inside the `dispose()` method.
*   **Asynchronous Widget Safety:** Before executing state changes or UI actions after an `await` call, always verify if the widget is still in the tree:
    ```dart
    if (!mounted) return;
    ```

### 2.3 Robust Error Handling & Resilience
*   **Zero Silent Crashes:** Every service or repository method must be wrapped in `try-catch` blocks. Catch specific exceptions (e.g., `FirebaseAuthException`, `FirebaseException`) rather than generic ones where possible.
*   **User-Friendly Error Notification:** Log errors to the console internally, but show clean, localized error messages to the user via SnackBar or error widgets instead of displaying technical stack traces.

### 2.4 Code Cleanliness & Readability
*   **Micro-Widget Decomposition:** Break down complex screen widgets into smaller, single-responsibility private widgets. (If a widget's build method exceeds 100 lines, extract its components).
*   **Constants & Constructors:** Define `const` constructors for all immutable widgets. Avoid using hardcoded magic numbers or duplicate string keys; place colors, paddings, and string constants in dedicated configuration files.

---

## 3. Firebase Development Skill

### 3.1 Unidirectional Data Flow
*   Maintain a strict architecture: `Firestore DB (Source)` ➔ `Repository / Service` ➔ `State Provider (ChangeNotifier)` ➔ `UI Widget`.
*   Keep business logic separate from layout widgets.

### 3.2 Firestore Architecture (Multi-Tenant SaaS)
*   All collections must resolve under the root `universiteler` path to support multi-tenancy:
    `firestore-root/universiteler/{universiteId}/[birimler|personel|danismanliklar|sistemAyarlari]`
*   Use composite indexes for combined queries containing filters and sort orders.

---

## 4. DSYS Specific Domain Skill

### 4.1 Turkish Currency & Punctuation Rules
*   All monetary outputs must use the Turkish locale formatting rules:
    *   Thousands separator: Dot (`.`)
    *   Decimal separator: Comma (`,`)
    *   Currency suffix: `TL`
    *   Example: `120.000,00 TL`
*   All dates must be formatted as: `dd.MM.yyyy` (e.g., `30.05.2026`).
*   Katsayi (coefficient) representation must contain exactly 2 decimal places: `19,50` or `0,42`.
*   All document titles and project topics must use typographic quotation marks (`“` and `”`).

### 4.2 Dynamic Math Calculations
*   **Standart Consultancy Taksit Matrah Formulation:**
    ```
    kdvHaricMatrah = Round( brutTaksitTutarı / (1 + (kdvOrani / 100)), 2 )
    ```
    *   Deductions:
        *   `Hazine Payi = Round( kdvHaricMatrah * (hazinePayiOrani / 100), 2 )`
        *   `BAP Payi = Round( kdvHaricMatrah * (bapPayiOrani / 100), 2 )`
        *   `Arac Gerec Payi = Round( kdvHaricMatrah * (aracGerecPayiOrani / 100), 2 )`
        *   `DagitilabilirTutar = kdvHaricMatrah - (Hazine Payi + BAP Payi + Arac Gerec Payi)`
*   **Sanayi İşbirliği (YÖK 58/k) Formulation:**
    *   No Hazine, BAP, or Araç-Gereç deductions (all set to `0.00`).
    *   `DagitilabilirTutar = Round( kdvHaricMatrah * 0.85, 2 )`
    *   `Birim Kalani = kdvHaricMatrah - DagitilabilirTutar` (corresponds to %15).

### 4.3 Kuruş Yuvarlama Katsayı Simülasyonu
To prevent the sum of individual hakediş payments from exceeding the total `DagitilabilirTutar` due to rounding issues, execute this iterative double-rounding logic:
```dart
double katsayiSimulasyonu(double dagitilabilirTutar, double toplamPuan, List<PersonelPuanModel> personeller) {
  double katsayi = double.parse((dagitilabilirTutar / toplamPuan).toStringAsFixed(2));
  
  while (true) {
    double hakedisToplam = 0.0;
    
    for (var personel in personeller) {
      double bireyselPuan = personel.faaliyetPuani * personel.unvanKatsayisi;
      double hakedis = double.parse((bireyselPuan * katsayi).toStringAsFixed(2));
      hakedisToplam += hakedis;
    }
    
    if (hakedisToplam > dagitilabilirTutar) {
      katsayi = double.parse((katsayi - 0.01).toStringAsFixed(2));
    } else {
      break;
    }
  }
  return katsayi;
}
```
Write the residual fraction to the unit's rollover balance:
`artikBakiye = DagitilabilirTutar - SumOfHakedis`

### 4.4 EYDMA Yasal Tavan Kontrolü
```
eydma = (gostergeEk + gostergeMakamTemsil) * memurMaasKatsayisi
unvanTavani = eydma * (unvanTavanCarpani / 100)
kalanTavanLimiti = max(0.0, unvanTavani - toplamAylikMevcutGelir)
```
If `yeniHakedis > kalanTavanLimiti`, set `odenebilirHakedis = kalanTavanLimiti`, and route `fazlalik = yeniHakedis - odenebilirHakedis` back to the unit reserve pool.

### 4.5 Official Word & Table Template Strings
*   **Template A (Standart):**
    `"Üniversitemiz {BIRIM_AD} Müdürlüğü’nün {BIRIM_EVRAK_TARIHI} tarih ve {BIRIM_EVRAK_SAYISI} sayılı yazısı ile {BIRIM_KURUL_TARIHI} tarih, {BIRIM_TOPLANTI_SAYI} toplantı sayılı ve {BIRIM_KARAR_NO} numaralı kararına istinaden; Döner Sermaye Yürütme Kurulu’nun {YK_KARAR_TARIHI} tarih ve {YK_KARAR_NO} sayılı kararı ile {FIRMA_UNVAN}’nin talep ettiği “{ISIN_KONUSU}” kapsamında {DANISMANLIK_SURESI} ay süreyle Danışmanlık Hizmeti için görevlendirilen {HOCA_UNVAN} {HOCA_AD_SOYAD} tarafından verilen danışmanlık hizmetine istinaden elde edilen gelirden ayrılan katkı payından aşağıdaki gelir getirici faaliyet cetveli doğrultusunda, dönem ek ödeme katsayısının {KATSAYI} şeklinde belirlenmesi ve elde edilen puanlara göre hesaplanacak katkı payı dağıtımının gerçekleştirilmesine;"`
*   **Template B (58/k):**
    `"Üniversitemiz Yönetim Kurulunun {UYK_KARAR_TARIHI} tarih, {UYK_TOPLANTI_SAYI} toplantı sayılı, {UYK_KARAR_NO} numaralı kararıyla 2547 Sayılı Yükseköğretim Kanunun 58. maddesinin (k) fıkrası kapsamında {FIRMA_UNVAN} ye teknik danışmanlık hizmeti vermek üzere görevlendirilen {HOCA_UNVAN} {HOCA_AD_SOYAD} tarafından {HIZMET_BASLANGIC_TARIHI}-{HIZMET_BITIS_TARIHI} ({DANISMANLIK_SURESI} Aylık) tarihleri arasında gerçekleştirilen hizmet için elde edilen {GELIR_TUTARI} TL gelirden ayrılan {KATKI_PAYI_TUTARI} TL katkı payının adı geçen öğretim üyesine tahakkuk ettirilmesine;"`

---

## 5. Actionable Command Playbook (Test / Analyze / Build)

The agent must execute these specific commands sequentially for code updates, verification, and QA gates.

### 5.1 Skill: Code Prep & Generation
```powershell
# Get packages
flutter pub get

# Generate freezed / json_serializable models (if applicable)
dart run build_runner build --delete-conflicting-outputs
```

### 5.2 Skill: Linting & Diagnostics
```powershell
# Format code
flutter format .

# Check diagnostics and apply automatic fixes
flutter fix --apply .

# Run static analysis
flutter analyze
```

### 5.3 Skill: Unit Testing
```powershell
# Run all unit tests
flutter test
```

### 5.4 Skill: Release Packaging
```powershell
# Clean build cache
flutter clean

# Fetch packages
flutter pub get

# Build Release APK
flutter build apk --release
```

---

## 6. YK Karar Modülü (dsys_v2) — Zorunlu QA

Bu bölüm `dsys_v2` Yürütme Kurulu modülü içindir. Ayrıntılı iş kuralları için kök dizindeki `AGENTS.md` dosyasını oku.

### 6.1 Word → Word ilkesi
* Tablolar **asla yeniden çizilmez**. Eşleşen bölümün OOXML'i (`docxBodyXml`) birebir korunur.
* Editörde yalnızca paragraf metni düzenlenir; kayıtta `mergeParagraphsIntoBodyXml` kullanılır.

### 6.2 Birim regression testi (her değişiklikten sonra)
```powershell
node import_yk_sablonlar.js
node test_tum_birimler.js
node verify_sablon_tablolari.js UBATAM
```
* `test_tum_birimler.js` exit code 0 olmalı — 7 birim karar + gündem arşivi + birleştirme.
* Bir birim tökezlerse ana YK kararı hatalı olur; merge öncesi `YkKararButunlukServisi` kontrolü zorunludur.

### 6.3 Firebase şablon yükleme
```powershell
node import_yk_sablonlar.js --upload
```
