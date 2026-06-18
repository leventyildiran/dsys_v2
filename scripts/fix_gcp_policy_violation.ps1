# GCP politika ihlali — sızan service account anahtarı temizliği
# Kullanım: .\scripts\fix_gcp_policy_violation.ps1

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host "=== DSYS GCP Politika İhlali Onarımı ===" -ForegroundColor Cyan
Write-Host ""

# Ölü anahtar GOOGLE_APPLICATION_CREDENTIALS üzerinden yüklenmesin
if ($env:GOOGLE_APPLICATION_CREDENTIALS) {
    Write-Host "GOOGLE_APPLICATION_CREDENTIALS temizleniyor (oturum için): $($env:GOOGLE_APPLICATION_CREDENTIALS)"
    Remove-Item Env:GOOGLE_APPLICATION_CREDENTIALS
}

Write-Host "[1/4] Service account anahtarı döndürülüyor..."
node scripts/rotate_service_account_key.js
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Otomatik döndürme başarısız — Firebase Console'dan manuel anahtar üretin:" -ForegroundColor Yellow
    Write-Host "https://console.firebase.google.com/project/dsys-44b8e/settings/serviceaccounts/adminsdk"
    Write-Host "Ardından: .\scripts\setup_firebase_github_secret.ps1"
    Write-Host ""
    $continue = Read-Host "Manuel anahtarı kurduktan sonra git temizliği için Enter'a basın (iptal: n)"
    if ($continue -eq 'n') { exit 1 }
}

Write-Host ""
Write-Host "[2/4] Git geçmişinden sızan JSON siliniyor..."
node scripts/purge_leaked_credentials_from_git.js

Write-Host ""
Write-Host "[3/4] API anahtarı kısıtlaması (manuel):"
Write-Host "https://console.cloud.google.com/apis/credentials?project=dsys-44b8e"
Write-Host "Browser / Web API anahtarlarını şu referrer'lara kısıtlayın:"
Write-Host "  https://dsys-44b8e.web.app/*"
Write-Host "  https://dsys-44b8e.firebaseapp.com/*"
Write-Host "  http://localhost:*"

Write-Host ""
Write-Host "[4/4] GCP politika e-postasındaki bağlantıdan ihlal bildirimine yanıt verin."
Write-Host ""
Write-Host "GitHub'a force push gerekir:" -ForegroundColor Yellow
Write-Host "  git push origin --force --all"
Write-Host "  git push origin --force --tags"
