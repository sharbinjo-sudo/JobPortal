#!/usr/bin/env bash
# Exit on error
set -e

echo "=== Checking Flutter SDK ==="
FLUTTER_DIR="$HOME/flutter"
if [ ! -d "$FLUTTER_DIR" ]; then
  echo "Downloading Flutter SDK (channel stable)..."
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
else
  echo "Using cached Flutter SDK."
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

echo "=== Flutter Version ==="
flutter --version

echo "=== Getting dependencies ==="
flutter pub get

API_URL="${API_BASE_URL:-https://your-backend.onrender.com/api}"
echo "=== Building Flutter Web with API_BASE_URL: $API_URL ==="
flutter build web --release --dart-define=API_BASE_URL="$API_URL"

echo "=== Ensuring Netlify SPA redirects ==="
cp web/_redirects build/web/_redirects || echo "/*    /index.html   200" > build/web/_redirects

echo "=== Build finished successfully ==="
