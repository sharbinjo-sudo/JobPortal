param(
  [string]$ApiBaseUrl = "http://127.0.0.1:8000/api"
)

Write-Host "=== Building Flutter Web for Production ===" -ForegroundColor Cyan
Write-Host "API Base URL: $ApiBaseUrl" -ForegroundColor Gray

flutter build web --release --dart-define=API_BASE_URL=$ApiBaseUrl

if (Test-Path "web/_redirects") {
  Copy-Item -Path "web/_redirects" -Destination "build/web/_redirects" -Force
}

Write-Host "=== Build Successful! ===" -ForegroundColor Green
Write-Host "Output directory: frontend/build/web" -ForegroundColor White
Write-Host "To deploy to Netlify using CLI, run:" -ForegroundColor Yellow
Write-Host "  npx netlify deploy --dir=build/web --prod" -ForegroundColor Yellow
