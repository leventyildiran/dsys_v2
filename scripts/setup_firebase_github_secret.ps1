# GitHub Actions FIREBASE_SERVICE_ACCOUNT_B64 secret kurulumu.
# Önkoşul: gh auth login (bir kez)
# Kullanım: .\scripts\setup_firebase_github_secret.ps1

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

$keyFile = Get-ChildItem -Path $repoRoot -Filter '*firebase-adminsdk*.json' -File |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $keyFile) {
    Write-Error "Firebase service account JSON bulunamadı. Dosyayı proje köküne koyun (*firebase-adminsdk*.json)."
}

$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    Write-Error "GitHub CLI (gh) yüklü değil. winget install GitHub.cli"
}

gh auth status 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "GitHub oturumu yok. Tarayıcıda giriş yapın..."
    gh auth login -h github.com -p https -w
}

$raw = Get-Content -Raw -Path $keyFile.FullName
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($raw))
gh secret set FIREBASE_SERVICE_ACCOUNT_B64 --repo leventyildiran/dsys_v2 --body $b64

Write-Host "FIREBASE_SERVICE_ACCOUNT_B64 secret ayarlandı (base64)."
Write-Host "Actions: https://github.com/leventyildiran/dsys_v2/actions/workflows/web-deploy.yml"
