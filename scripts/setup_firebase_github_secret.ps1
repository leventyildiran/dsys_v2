# GitHub Actions FIREBASE_SERVICE_ACCOUNT secret kurulumu.
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

Get-Content -Raw -Path $keyFile.FullName | gh secret set FIREBASE_SERVICE_ACCOUNT --repo leventyildiran/dsys_v2

Write-Host "FIREBASE_SERVICE_ACCOUNT secret ayarlandı."
Write-Host "Actions: https://github.com/leventyildiran/dsys_v2/actions/workflows/web-deploy.yml"
