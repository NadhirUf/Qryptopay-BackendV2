import 'dart:io';
import 'package:postgres/postgres.dart';

class PostgresClient {
  factory PostgresClient() {
    return _instance;
  }

// --- CONSTRUCTOR (Jalan saat pertama kali server nyala) ---
  PostgresClient._internal() {
    final env = _loadEnvWithFallback();

    // 🚨 FIX: Paksa baca dari Awan dulu (Platform.environment).
    // Kalau di Awan kosong, baru baca env lokal.
    final dbHost =
        Platform.environment['DB_HOST'] ?? env['DB_HOST'] ?? 'localhost';
    final dbPort = int.tryParse(
            Platform.environment['DB_PORT'] ?? env['DB_PORT'] ?? '5432') ??
        5432;
    final dbName =
        Platform.environment['DB_NAME'] ?? env['DB_NAME'] ?? 'qryptopay_db';
    final dbUser =
        Platform.environment['DB_USER'] ?? env['DB_USER'] ?? 'postgres';
    final dbPass =
        Platform.environment['DB_PASS'] ?? env['DB_PASS'] ?? 'password';

    print('🏊 Membuat Pool Database ke $dbHost:$dbPort/$dbName...');

    try {
      // ✅ FIX: Inisialisasi _pool DISINI, bukan di function lain
      _pool = Pool.withEndpoints(
        [
          Endpoint(
            host: dbHost,
            port: dbPort,
            database: dbName,
            username: dbUser,
            password: dbPass,
          ),
        ],
        settings: const PoolSettings(
          maxConnectionCount: 5,
          sslMode: SslMode.disable, // Biarkan disable dulu
        ),
      );
    } catch (e) {
      print('🔥 Gagal buat Pool: $e');
      rethrow;
    }
  }
  static final PostgresClient _instance = PostgresClient._internal();

  // Variabel ini harus diisi SEGERA di constructor
  late final Pool _pool;

  Pool get connection => _pool;

  // Function init kita kosongkan (agar kompatibel dengan middleware lama)
  Future<void> init() async {
    print('✅ Database sudah siap (Synchronous)');
  }

  // Helper untuk kodingan lama
  Future<Result> query(String sql, {Map<String, dynamic>? params}) async {
    return _pool.execute(Sql.named(sql), parameters: params);
  }

  Map<String, String> _loadEnvWithFallback() {
    final env = <String, String>{...Platform.environment};
    final probeRoots = <Directory>{
      Directory.current,
      File.fromUri(Platform.script).parent,
    };

    for (final root in probeRoots) {
      var dir = root;
      for (var i = 0; i < 8; i++) {
        final file = File('${dir.path}/.env');
        if (file.existsSync()) {
          for (final rawLine in file.readAsLinesSync()) {
            final line = rawLine.trim();
            if (line.isEmpty || line.startsWith('#')) continue;

            final separator = line.indexOf('=');
            if (separator <= 0) continue;

            final key = line.substring(0, separator).trim();
            final value = line.substring(separator + 1).trim();
            if (key.isNotEmpty) env[key] = value;
          }
          return env;
        }

        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    }

    return env;
  }
}
