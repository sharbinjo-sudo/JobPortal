# Setup

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env
python manage.py migrate
python manage.py seed_demo
python manage.py runserver
```

```powershell
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

For the local prototype, set a resume URL with `POST /api/profiles/me/resume/` before applying. Production can replace this with multipart upload to Supabase Storage by setting `DATABASE_URL` to Supabase PostgreSQL, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `SUPABASE_STORAGE_BUCKET`. EmailJS values are public client configuration supplied as Dart defines; they are not secrets. Send EmailJS only after successful API mutations and treat delivery errors as non-blocking UI warnings.
