#!/usr/bin/env bash
set -e

API_URL="${1:-${API_BASE_URL:-http://127.0.0.1:8000/api}}"

echo "=== Building Flutter Web for Production ==="
echo "API Base URL: $API_URL"

flutter build web --release --dart-define=API_BASE_URL="$API_URL"

if [ -f "web/_redirects" ]; then
  cp web/_redirects build/web/_redirects
fi

echo "=== Build Successful! ==="
echo "Output directory: frontend/build/web"
echo "To deploy to Netlify using CLI, run:"
echo "  npx netlify deploy --dir=build/web --prod"
