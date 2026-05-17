# QryptoPay Backend (Panduan Lengkap Windows)

Project ini adalah backend API QryptoPay menggunakan Dart Frog + PostgreSQL, plus frontend mock di `frontend_mock/`.

## 1. Software yang Wajib Diinstall

1. Dart SDK 3.x  
   Download: https://dart.dev/get-dart
2. PostgreSQL (server + psql + pgAdmin)  
   Download: https://www.postgresql.org/download/windows/
3. Python 3.x (untuk menjalankan frontend mock)  
   Download: https://www.python.org/downloads/windows/

Setelah install, cek di Command Prompt (`cmd`):

```bat
dart --version
psql --version
python --version
```

Jika ada yang "not recognized", restart terminal/Windows lalu cek lagi.

## 2. Buka Project

1. Extract / clone project.
2. Buka terminal di folder project `pay` (folder yang berisi `pubspec.yaml`).
3. Pastikan file penting ada:
   - `pubspec.yaml`
   - `.env`
   - `backup.sql`

## 3. Setup File `.env`

Isi `.env` di root project seperti ini (sesuaikan password PostgreSQL di laptop client):

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=qryptopay_db
DB_USER=postgres
DB_PASS=ISI_PASSWORD_POSTGRES_ANDA

PORT=8080
ENV=development
```

Catatan:
- `DB_PASS` harus sama dengan password user `postgres` saat instalasi PostgreSQL.
- Jika ingin backend jalan di port lain, ubah `PORT`.

## 4. Setup Database PostgreSQL (Windows)

Gunakan salah satu cara di bawah.

### Opsi A (Paling aman): pakai `psql`

1. Buka `cmd`.
2. Buat database:

```bat
set PGPASSWORD=ISI_PASSWORD_POSTGRES_ANDA
psql -h localhost -p 5432 -U postgres -c "CREATE DATABASE qryptopay_db;"
```

3. Masih di folder project `pay`, import dump:

```bat
psql -h localhost -p 5432 -U postgres -d qryptopay_db -f backup.sql
```

4. Verifikasi tabel:

```bat
psql -h localhost -p 5432 -U postgres -d qryptopay_db -c "\dt"
```

### Opsi B: pakai pgAdmin

1. Buka pgAdmin, login pakai password PostgreSQL.
2. Klik kanan `Databases` > `Create` > `Database...`.
3. Nama database: `qryptopay_db`, lalu `Save`.
4. Klik menu `Tools` > `Query Tool` (untuk cek saja, bukan import dump besar).
5. Untuk import `backup.sql` tetap disarankan pakai `psql` (Opsi A), karena lebih stabil untuk file dump.

## 5. Install Dependency Project

Di folder project `pay`:

```bat
dart pub get
dart pub global activate dart_frog_cli
```

Jika perintah `dart_frog` tidak dikenali, jalankan via:

```bat
dart pub global run dart_frog_cli:dart_frog --version
```

## 6. Jalankan Backend

Di folder project `pay`:

```bat
dart_frog dev --port 8080
```

Kalau `dart_frog` tidak terbaca, pakai:

```bat
dart pub global run dart_frog_cli:dart_frog dev --port 8080
```

API akan jalan di:

`http://localhost:8080`

## 7. Test Backend Cepat

Buka browser:

- `http://localhost:8080/`

Atau test endpoint admin (PowerShell):

```powershell
Invoke-WebRequest -Uri "http://localhost:8080/api/v1/admin/dashboard" -Headers @{"x-admin-key"="RAHASIA_QARYPTOPAY"}
```

## 8. Jalankan Frontend Mock

1. Pastikan `frontend_mock/admin.html` memakai:

```js
const BASE_URL = 'http://localhost:8080';
```

2. Buka terminal baru, lalu:

```bat
cd frontend_mock
python -m http.server 5500
```

3. Buka browser:

- `http://localhost:5500/admin.html`
- `http://localhost:5500/login.html`

## 9. Akun Demo

- Admin:
  - Email: `admin@qryptopay.com`
  - Password: `admin12345`
- User:
  - Email: `demo@qryptopay.com` | Password: `hash123`
  - Email: `sultan@crypto.com` | Password: `123456`

## 10. Troubleshooting Umum

### `database "qryptopay_db" does not exist`
Database belum dibuat. Jalankan langkah create database dulu.

### `password authentication failed for user "postgres"`
Password di `.env` / `PGPASSWORD` tidak sama dengan password PostgreSQL.

### `relation "users" does not exist`
Import `backup.sql` belum berhasil atau masuk ke database lain.

### `dart_frog is not recognized`
Pakai:
`dart pub global run dart_frog_cli:dart_frog dev --port 8080`

### `python is not recognized`
Install ulang Python lalu centang opsi "Add Python to PATH".
