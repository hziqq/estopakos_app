import 'dart:io';
import 'db.dart';

/// Skrip satu-kali untuk mereset & membuat skema database `estopa_kos`
/// (UUID + RBAC `akun` & `peran_akun`, tanpa `pengeluaran`, 100% Bahasa Indonesia).
Future<void> main() async {
  final cfg = EstopaDbConfig.fromEnv();
  stdout.writeln(
    'Menghubungkan ke PostgreSQL ${cfg.host}:${cfg.port} (user: ${cfg.username})...',
  );

  final db = await EstopaDatabase.connectAndInit(cfg, reset: true);
  final tables = [
    'akun',
    'peran_akun',
    'riwayat_reset_sandi',
    'kamar',
    'penghuni',
    'pemesanan',
    'tagihan',
    'pembayaran',
    'keluhan',
    'pengumuman',
    'pengumuman_dibaca',
    'notifikasi',
    'webhook_terproses',
  ];

  stdout.writeln(
    'Sukses! Ringkasan isi database "${db.config.database}" (Skema Baru Bahasa Indonesia):',
  );
  for (final t in tables) {
    final res = await db.conn.execute('SELECT COUNT(*) FROM $t');
    stdout.writeln(' - $t: ${res.first.first} baris');
  }
  await db.conn.close();
}
