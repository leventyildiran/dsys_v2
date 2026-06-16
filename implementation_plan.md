# Admin & Kullanıcı Arayüzü Uygulaması

## Goal Description
Bu aşamada kurum içi bir karar yönetim sistemi için **admin paneli**, **kayıt (signup) ekranı**, **onay bekleyen kullanıcı ekranı**, ve **arşiv ekranı** oluşturacağız. Kullanıcılar yalnızca admin onayıyla sisteme giriş yapabilecek ve admin kararları görüntüleyip PDF önizleme ve Word dışa aktarımını sağlayacak. Tüm UI, kurumsal temada, karanlık mod, glassmorphism ve mikro‑animasyonlarla premium bir görünümde olacak. Tüm metinler Türkçe olacak.

## User Review Required
> [!IMPORTANT]
> Onay bekleyen kullanıcı yöneticisi (admin) yetkileri ve rollerin (`admin`, `editor`, `member`) doğru bir şekilde UI'da gösterildiğinden emin olun.
>
> PDF önizleme modalının ve Word dışa aktarma işlevinin mevcut sistemle entegrasyonu (örnek `exportDecisionToWord` ve `generatePdfPreview`) doğrulanmalı.
>
> Router'da navigation guard'ların (admin, member erişim kontrolleri) uygulanması kritik; lütfen test edip geri bildirim verin.

## Open Questions
> [!NOTE]
> - **Kurum teması**: Google Fonts Inter ve koyu HSL tabanlı renk paleti onaylandı.
> - **PDF önizleme**: Mevcut `pdf_viewer` paketi kullanılacak.
> - **Word dışa aktarım**: Mevcut `belge_uretim_servisi.dart` servisi yeniden kullanılacak, yeni paket eklemeye gerek yok.
> - **Editor rolü**: Kararları görüntüleme ve düzenleme yetkisine sahip olacak.

> [!WARNING]
> 1. **Kurum teması**: Renk paleti ve font seçimi (ör. Google Fonts `Inter`) onaylı mı? 
> 2. **PDF önizleme**: Mevcut `pdf_viewer` paketi mi kullanılacak, yoksa özel bir modal mı isteniyor?
> 3. **Word dışa aktarım**: Halihazırda bir servis (`exportDecisionToWord`) var mı, ya da yeni bir paket (`docx_template`) eklememiz gerekiyor?
> 4. **Kullanıcı rolleri**: `editor` rolü ne yetkilere sahip olacak? Şu an sadece `admin` ve `member` tanımlı.

## Proposed Changes
---
### Auth & Router Enhancements
#### [MODIFY] [auth_provider.dart](file:///e:/antivaty/dsys_v2/lib/features/auth/providers/auth_provider.dart)
- `canAccess` getter zaten var, ek olarak `isAdmin` kullanalım.
- Router guard eklemek için `AppRouter` dosyasına navigation guard metodu ekle.

#### [MODIFY] [app_router.dart](file:///e:/antivaty/dsys_v2/lib/router/app_router.dart)
- Yeni `AdminGuard` ve `EditorGuard` eklenerek `authProvider.isAdmin` ve `authProvider.canAccess` kontrolü yapılacak.
- `/admin`, `/signup`, `/pending-approval`, `/archive` rotalarına guard uygulanacak.

---
### UI Screens
#### [NEW] [admin_dashboard_screen.dart](file:///e:/antivaty/dsys_v2/lib/features/admin/screens/admin_dashboard_screen.dart)
- Admin paneli: Bekleyen kullanıcı listesi, karar istatistikleri.
- `UserRequestService` ile istekleri al, onayla/reddet butonları.
- Rol atama dropdown (admin, editor, member).

#### [NEW] [signup_screen.dart](file:///e:/antivaty/dsys_v2/lib/features/auth/screens/signup_screen.dart)
- Kayıt ekranı: e-posta, şifre, isim.
- `UserRequestService.createRequest` çağrısı.
- Toast mesajları, gradient background, Inter font, mikro‑animasyonlu buton.

#### [NEW] [pending_approval_screen.dart](file:///e:/antivaty/dsys_v2/lib/features/auth/screens/pending_approval_screen.dart)
- Giriş sonrası onay bekleme ekranı (`canAccess` false).
- Bekleme mesajı ve admin onay sürecini gösterir.

#### [NEW] [archive_screen.dart](file:///e:/antivaty/dsys_v2/lib/features/decisions/screens/archive_screen.dart)
- Yıllara göre filtreleme.
- Karar kartları (başlık, yürütme kurulu, tarih) glassmorphism.
- Tıklandığında PDF önizleme modalı (pdf_viewer).
- `Export to Word` butonu: mevcut `belge_uretim_servisi` kullanır.
- Mikro‑animasyonlu hover.

---
### PDF Preview Modal
#### [NEW] [pdf_preview_modal.dart](file:///e:/antivaty/dsys_v2/lib/shared/widgets/pdf_preview_modal.dart)
- `showDialog` + `PdfViewer` (pdf_viewer paketi) modal.
- Fade & scale animasyonları.

---
### Word Export Service
#### [MODIFY] [belge_uretim_servisi.dart](file:///e:/antivaty/dsys_v2/lib/features/yk_karar/services/belge_uretim_servisi.dart)
- Mevcut servis karar ve gündem için DOCX üretir, `exportDecisionToWord` gibi fonksiyonları sağlayacak.
- Yeni bir paket eklemeye gerek yok, mevcut kodu yeniden kullanacağız.

---
### Design System (CSS equivalent in Flutter)
#### [NEW] [theme.dart](file:///e:/antivaty/dsys_v2/lib/core/theme/theme.dart)
- Kurumsal koyu tema (HSL 210,15,12), `GoogleFonts.inter`.
- Glassmorphism (`BackdropFilter` blur).
- `AnimatedContainer`, `InkWell` mikro‑animasyonlar.

---
### Verification Plan
#### Automated Tests
- Unit testler: `UserRequestService` approve/reject işlevi.
- Widget test: `AdminDashboardScreen` onay butonları çalışıyor mu.
- Integration test: login → pending approval → admin onay → erişim sağlanıyor.

#### Manual Verification
- Uygulamayı `flutter run` ile başlat, admin hesabıyla giriş yapıp yeni kullanıcı onaylayın.
- Karar listesinde bir karar seçip PDF preview ve Word export butonlarını deneyin.
- Tüm metinlerin Türkçe olduğunu kontrol edin.
- Dark mode ve glassmorphism efektlerinin beklendiği gibi göründüğünden emin olun.

---
**Not:** Tüm yeni dosyalar `e:\antivaty\dsys_v2\` içinde oluşturulacak ve mevcut `pubspec.yaml` içine gereken paket eklemeleri yapılacaktır.
