# ============================================================================
# reset_flutter.ps1
# Limpa todos os caches temporários do Flutter e Gradle que podem corromper
# a porta do ADB ou a ligação do Dart VM service.
#
# USO:
#   cd kitchy_app
#   .\reset_flutter.ps1
#
# Quando usar:
#   - Após erros de WebSocket/ADB ("Connection closed before full header")
#   - Após mudar AndroidManifest.xml ou build.gradle
#   - Após atualizar a versão do Flutter ou Kotlin
#   - Quando o emulador liga mas a app crasha logo no arranque
# ============================================================================

Write-Host ""
Write-Host "=== RESET FLUTTER + GRADLE ===" -ForegroundColor Cyan
Write-Host ""

# 1. Flutter clean (remove build/ e .dart_tool/)
Write-Host "[1/5] flutter clean..." -ForegroundColor Yellow
flutter clean

# 2. Apagar cache Gradle do projeto
$gradleCache = "android\.gradle"
if (Test-Path $gradleCache) {
    Write-Host "[2/5] A apagar $gradleCache..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $gradleCache
} else {
    Write-Host "[2/5] $gradleCache nao encontrado (ok)" -ForegroundColor Gray
}

# 3. Apagar build do projeto Android
$androidBuild = "android\app\build"
if (Test-Path $androidBuild) {
    Write-Host "[3/5] A apagar $androidBuild..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $androidBuild
} else {
    Write-Host "[3/5] $androidBuild nao encontrado (ok)" -ForegroundColor Gray
}

# 4. Restaurar dependências Dart
Write-Host "[4/5] flutter pub get..." -ForegroundColor Yellow
flutter pub get

# 5. Matar processos ADB presos (opcional, descomenta se necessário)
# Write-Host "[5/5] A reiniciar servidor ADB..." -ForegroundColor Yellow
# adb kill-server
# adb start-server

Write-Host ""
Write-Host "[5/5] Pronto! Podes agora correr:" -ForegroundColor Green
Write-Host "       flutter run" -ForegroundColor White
Write-Host ""
Write-Host "Se o emulador nao responder, faz tambem:" -ForegroundColor Gray
Write-Host "   adb kill-server && adb start-server" -ForegroundColor Gray
Write-Host ""
