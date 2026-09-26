#!/usr/bin/env bash
# Exit on error
set -o errexit

echo "=== Installing dependencies ==="
pip install --upgrade pip
pip install -r requirements.txt

echo "=== Applying database migrations ==="
python manage.py migrate --noinput

echo "=== Collecting static files for WhiteNoise ==="
python manage.py collectstatic --noinput

echo "=== Build finished successfully ==="
