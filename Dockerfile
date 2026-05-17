# ---------------------------------------------------
# TAHAP 1: BUILD (Menyiapkan Project)
# ---------------------------------------------------
FROM dart:stable AS build

WORKDIR /app

# 1. Copy file definisi paket dulu
COPY pubspec.yaml ./

# 2. HAPUS pubspec.lock jika ada (PENTING: Agar tidak bentrok versi)
RUN rm -f pubspec.lock

# 3. Download dependencies (Fresh Install)
RUN dart pub get

# 4. Copy seluruh kode program
COPY . .

# 5. Install Dart Frog CLI
RUN dart pub global activate dart_frog_cli

# 6. BUILD PROJECT
# Perintah ini akan membuat folder baru di /app/build
# Folder itu berisi server yang "siap pakai"
RUN dart pub global run dart_frog_cli:dart_frog build

# ---------------------------------------------------
# TAHAP 2: RUNTIME (Menjalankan Server)
# ---------------------------------------------------
FROM dart:stable

WORKDIR /app

# 7. Copy HANYA folder hasil build dari Tahap 1
# Kita tidak copy source code mentah, tapi hasil jadi-nya
COPY --from=build /app/build /app

# 8. DOWNLOAD DEPENDENCIES UNTUK HASIL BUILD (CRUCIAL STEP!)
# Server butuh paket-paket ini untuk berjalan
RUN dart pub get

# 9. Buka Port
ENV PORT=8080
EXPOSE 8080

# 10. Jalankan Server
CMD ["dart", "bin/server.dart", "--hostname=0.0.0.0"]