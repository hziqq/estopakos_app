import 'dart:convert';
import 'dart:io';
import 'package:postgres/postgres.dart';

/// Konfigurasi koneksi PostgreSQL (pgAdmin 4) untuk Estopa Kos.
class EstopaDbConfig {
  final String host;
  final int port;
  final String database;
  final String username;
  final String password;

  const EstopaDbConfig({
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
  });

  factory EstopaDbConfig.fromEnv() {
    final envMap = <String, String>{};
    final envFiles = [File('backend/.env'), File('.env')];
    for (final f in envFiles) {
      if (f.existsSync()) {
        for (final line in f.readAsLinesSync()) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
          final idx = trimmed.indexOf('=');
          if (idx > 0) {
            final key = trimmed.substring(0, idx).trim();
            final val = trimmed.substring(idx + 1).trim();
            envMap[key] = val;
          }
        }
        break;
      }
    }

    String readKey(String key, String fallback) {
      return Platform.environment[key] ?? envMap[key] ?? fallback;
    }

    return EstopaDbConfig(
      host: readKey('PG_HOST', 'localhost'),
      port: int.tryParse(readKey('PG_PORT', '5432')) ?? 5432,
      database: readKey('PG_DB', 'estopa_kos'),
      username: readKey('PG_USER', 'postgre'),
      password: readKey('PG_PASSWORD', 'admin'),
    );
  }
}

/// Kelas Database PostgreSQL untuk Sistem Informasi Manajemen Estopa Kos
/// (Skema UUID 100% Bahasa Indonesia dengan RBAC akun & peran_akun, tanpa pengeluaran).
class EstopaDatabase {
  final Connection conn;
  final EstopaDbConfig config;

  EstopaDatabase._(this.conn, this.config);

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Pastikan string ID apa pun menjadi UUID valid deterministik untuk PostgreSQL.
  static String ensureUuid(String rawKey) {
    final trimmed = rawKey.trim();
    if (_uuidRegex.hasMatch(trimmed)) {
      return trimmed.toLowerCase();
    }
    final bytes = utf8.encode('estopa_uuid_v5::$trimmed');
    int h1 = 0x811c9dc5;
    int h2 = 0x01000193;
    int h3 = 0x9e3779b9;
    int h4 = 0x85ebca6b;
    for (var i = 0; i < bytes.length; i++) {
      final b = bytes[i];
      h1 = ((h1 ^ b) * 0x01000193) & 0xFFFFFFFF;
      h2 = ((h2 ^ (b + i)) * 0x85ebca6b) & 0xFFFFFFFF;
      h3 = ((h3 + b) * 0xc2b2ae35) & 0xFFFFFFFF;
      h4 = ((h4 ^ (b * 7)) * 0x27d4eb2f) & 0xFFFFFFFF;
    }
    final p1 = h1.toRadixString(16).padLeft(8, '0');
    final p2 = (h2 & 0xFFFF).toRadixString(16).padLeft(4, '0');
    final p3 = ((0x4000) | (h2 >> 20 & 0x0FFF)).toRadixString(16).padLeft(4, '0');
    final p4 = ((0x8000) | (h3 & 0x3FFF)).toRadixString(16).padLeft(4, '0');
    final p5 = '${(h3 >> 16 & 0xFFFF).toRadixString(16).padLeft(4, '0')}${h4.toRadixString(16).padLeft(8, '0')}';
    return '$p1-$p2-$p3-$p4-$p5'.toLowerCase();
  }

  static final String adminAkunUuid = ensureUuid('AKUN-ADMIN-ESTOPA');

  static Future<EstopaDatabase> connectAndInit(
    EstopaDbConfig config, {
    bool reset = false,
  }) async {
    final candidateUsers = <String>[
      config.username,
      if (config.username.toLowerCase() == 'postgre') 'postgres',
      if (config.username.toLowerCase() == 'postgres') 'postgre',
    ];

    String activeUser = config.username;
    Connection? adminConn;
    Object? lastAuthError;

    for (final u in candidateUsers) {
      try {
        adminConn = await Connection.open(
          Endpoint(
            host: config.host,
            port: config.port,
            database: 'postgres',
            username: u,
            password: config.password,
          ),
          settings: const ConnectionSettings(sslMode: SslMode.disable),
        );
        activeUser = u;
        break;
      } catch (e) {
        lastAuthError = e;
      }
    }

    if (adminConn != null) {
      try {
        final dbCheck = await adminConn.execute(
          Sql.named('SELECT 1 FROM pg_database WHERE datname = @db'),
          parameters: {'db': config.database},
        );
        if (dbCheck.isEmpty) {
          await adminConn.execute('CREATE DATABASE "${config.database}"');
          stdout.writeln(
            '[DB] Database "${config.database}" otomatis dibuat di PostgreSQL.',
          );
        }
      } finally {
        await adminConn.close();
      }
    } else if (lastAuthError != null) {
      stderr.writeln('[DB WARN] Gagal cek DB postgres: $lastAuthError');
    }

    final resolvedConfig = EstopaDbConfig(
      host: config.host,
      port: config.port,
      database: config.database,
      username: activeUser,
      password: config.password,
    );

    final conn = await Connection.open(
      Endpoint(
        host: resolvedConfig.host,
        port: resolvedConfig.port,
        database: resolvedConfig.database,
        username: resolvedConfig.username,
        password: resolvedConfig.password,
      ),
      settings: const ConnectionSettings(sslMode: SslMode.disable),
    );

    final db = EstopaDatabase._(conn, resolvedConfig);
    await db._createSchema(reset: reset);
    await db._seedIfEmpty();
    return db;
  }

  // Skema database aplikasi kos (PostgreSQL), 100% Bahasa Indonesia.
  //
  // Catatan pemakaian:
  // - Panggil _createSchema() biasa  -> aman, data tidak hilang (IF NOT EXISTS).
  // - Panggil _createSchema(reset: true) -> HANYA untuk development, semua data dihapus.
  // - Satu statement per conn.execute() supaya aman di semua versi package postgres.
  Future<void> _createSchema({bool reset = false}) async {
    if (reset) {
      await conn.execute('''
        DROP TABLE IF EXISTS
          webhook_terproses, notifikasi, pengumuman_dibaca, pengumuman, keluhan,
          pengeluaran, pembayaran, tagihan, pemesanan, penghuni, kamar,
          riwayat_reset_sandi, peran_akun, akun,
          status_baca_pengumuman, pemesanan_sementara,
          announcement_reads, announcements, complaints, expenses, payments,
          invoices, booking_holds, tenants, rooms, notifications, processed_webhooks
        CASCADE
      ''');
      await conn.execute('DROP FUNCTION IF EXISTS set_diperbarui_pada() CASCADE');
    }

    final statements = <String>[
      // ---------------------------------------------------------------
      // 0. Fungsi pembantu: isi kolom diperbarui_pada otomatis saat UPDATE
      // ---------------------------------------------------------------
      r'''
      CREATE OR REPLACE FUNCTION set_diperbarui_pada() RETURNS TRIGGER AS $$
      BEGIN
        NEW.diperbarui_pada = NOW();
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql
      ''',

      // ---------------------------------------------------------------
      // 1. akun: satu-satunya tempat email, no_hp, dan password
      // ---------------------------------------------------------------
      r'''
      CREATE TABLE IF NOT EXISTS akun (
        id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        email           VARCHAR(120) NOT NULL,
        no_hp           VARCHAR(30)  NOT NULL UNIQUE,
        password_hash   TEXT         NOT NULL,
        aktif           BOOLEAN      NOT NULL DEFAULT TRUE,
        dibuat_pada     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
        diperbarui_pada TIMESTAMPTZ  NOT NULL DEFAULT NOW()
      )
      ''',
      // email tidak peka huruf besar/kecil: Budi@x.com == budi@x.com
      r'CREATE UNIQUE INDEX IF NOT EXISTS ux_akun_email ON akun (LOWER(email))',

      // ---------------------------------------------------------------
      // 2. peran_akun (RBAC)
      // ---------------------------------------------------------------
      r'''
      CREATE TABLE IF NOT EXISTS peran_akun (
        id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        akun_id  UUID NOT NULL REFERENCES akun(id) ON DELETE CASCADE,
        peran    VARCHAR(20) NOT NULL CHECK (peran IN ('admin', 'penghuni')),
        UNIQUE (akun_id, peran)
      )
      ''',

      // ---------------------------------------------------------------
      // 3. riwayat_reset_sandi (audit trail)
      // ---------------------------------------------------------------
      r'''
      CREATE TABLE IF NOT EXISTS riwayat_reset_sandi (
        id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        akun_id              UUID NOT NULL REFERENCES akun(id) ON DELETE CASCADE,
        email_akun_snapshot  VARCHAR(120) NOT NULL,
        direset_oleh         UUID NULL REFERENCES akun(id) ON DELETE SET NULL,
        dibuat_pada          TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
      ''',
      r'CREATE INDEX IF NOT EXISTS ix_riwayat_reset_akun ON riwayat_reset_sandi (akun_id)',

      // ---------------------------------------------------------------
      // 4. kamar
      // ---------------------------------------------------------------
      r'''
      CREATE TABLE IF NOT EXISTS kamar (
        id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        nomor_kamar      VARCHAR(10) NOT NULL UNIQUE,
        lantai           INT         NOT NULL CHECK (lantai BETWEEN 1 AND 4),
        tipe             VARCHAR(10) NOT NULL CHECK (tipe IN ('putri', 'putra')),
        harga_per_bulan  INT         NOT NULL CHECK (harga_per_bulan > 0),
        fasilitas        JSONB       NOT NULL DEFAULT '[]'::jsonb,
        url_foto         TEXT        NULL,
        status           VARCHAR(15) NOT NULL DEFAULT 'tersedia'
                           CHECK (status IN ('tersedia', 'ditahan', 'terisi')),
        ditahan_sampai   TIMESTAMPTZ NULL,
        dibuat_pada      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        diperbarui_pada  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        -- kamar berstatus 'ditahan' wajib punya batas waktu tahan
        CHECK (status <> 'ditahan' OR ditahan_sampai IS NOT NULL)
      )
      ''',
      r'CREATE INDEX IF NOT EXISTS ix_kamar_status ON kamar (status)',

      // ---------------------------------------------------------------
      // 5. penghuni (email & no_hp ada di akun, tidak diduplikasi)
      // ---------------------------------------------------------------
      r'''
      CREATE TABLE IF NOT EXISTS penghuni (
        id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        akun_id              UUID NOT NULL UNIQUE REFERENCES akun(id) ON DELETE CASCADE,
        kamar_id             UUID NULL REFERENCES kamar(id) ON DELETE SET NULL,
        riwayat_nomor_kamar  VARCHAR(30) NULL,
        nama_lengkap         VARCHAR(120) NOT NULL,
        alamat_asal          TEXT NOT NULL,
        nama_orang_tua       VARCHAR(120) NOT NULL,
        no_hp_orang_tua      VARCHAR(30) NOT NULL,
        nomor_ktp            VARCHAR(32) NOT NULL,
        url_ktp              VARCHAR(150) NOT NULL,
        ktp_data             TEXT NULL,
        persetujuan_ktp      BOOLEAN NOT NULL DEFAULT TRUE,
        tanggal_masuk        DATE NULL,
        tanggal_keluar       DATE NULL,
        periode_bayar_bulan  INT NOT NULL DEFAULT 1 CHECK (periode_bayar_bulan IN (1, 3, 6, 12)),
        dibayar_sampai       DATE NULL,
        status               VARCHAR(25) NOT NULL DEFAULT 'menunggu_pembayaran'
                               CHECK (status IN ('menunggu_pembayaran', 'aktif', 'nonaktif')),
        dibuat_pada          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        diperbarui_pada      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        CHECK (tanggal_keluar IS NULL OR tanggal_masuk IS NULL OR tanggal_keluar >= tanggal_masuk)
      )
      ''',
      // satu kamar hanya boleh dipegang SATU penghuni yang aktif/menunggu bayar
      r'''
      CREATE UNIQUE INDEX IF NOT EXISTS ux_penghuni_kamar_berjalan
        ON penghuni (kamar_id)
        WHERE kamar_id IS NOT NULL AND status IN ('menunggu_pembayaran', 'aktif')
      ''',

      // ---------------------------------------------------------------
      // 6. pemesanan (hold kamar 20 menit)
      // ---------------------------------------------------------------
      r'''
      CREATE TABLE IF NOT EXISTS pemesanan (
        id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        kamar_id          UUID NOT NULL REFERENCES kamar(id) ON DELETE CASCADE,
        penghuni_id       UUID NOT NULL REFERENCES penghuni(id) ON DELETE CASCADE,
        durasi_bulan      INT  NOT NULL CHECK (durasi_bulan IN (1, 3, 6, 12)),
        jumlah            INT  NOT NULL CHECK (jumlah > 0),
        status            VARCHAR(20) NOT NULL DEFAULT 'menunggu'
                            CHECK (status IN ('menunggu', 'dibayar', 'kedaluwarsa', 'dibatalkan')),
        kedaluwarsa_pada  TIMESTAMPTZ NOT NULL,
        dibayar_pada      TIMESTAMPTZ NULL,
        dibuat_pada       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        diperbarui_pada   TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
      ''',
      // satu kamar tidak boleh punya dua pemesanan 'menunggu' sekaligus
      r'''
      CREATE UNIQUE INDEX IF NOT EXISTS ux_pemesanan_menunggu_per_kamar
        ON pemesanan (kamar_id) WHERE status = 'menunggu'
      ''',
      r'''
      CREATE INDEX IF NOT EXISTS ix_pemesanan_kedaluwarsa
        ON pemesanan (kedaluwarsa_pada) WHERE status = 'menunggu'
      ''',
      r'CREATE INDEX IF NOT EXISTS ix_pemesanan_penghuni ON pemesanan (penghuni_id)',

      // ---------------------------------------------------------------
      // 7. tagihan (riwayat keuangan: RESTRICT, jangan ikut terhapus)
      // ---------------------------------------------------------------
      r'''
      CREATE TABLE IF NOT EXISTS tagihan (
        id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        penghuni_id              UUID NOT NULL REFERENCES penghuni(id) ON DELETE RESTRICT,
        nama_penghuni_snapshot   VARCHAR(120) NOT NULL,
        nomor_kamar_snapshot     VARCHAR(20)  NOT NULL,
        periode_bulan            INT  NOT NULL DEFAULT 1 CHECK (periode_bulan IN (1, 3, 6, 12)),
        periode_mulai            DATE NOT NULL,
        periode_selesai          DATE NOT NULL,
        jatuh_tempo              DATE NOT NULL,
        biaya_kamar              INT  NOT NULL CHECK (biaya_kamar >= 0),
        biaya_air                INT  NOT NULL DEFAULT 0 CHECK (biaya_air >= 0),
        biaya_admin              INT  NOT NULL DEFAULT 0 CHECK (biaya_admin >= 0),
        denda                    INT  NOT NULL DEFAULT 0 CHECK (denda >= 0),
        jumlah_hari_terlambat    INT  NOT NULL DEFAULT 0 CHECK (jumlah_hari_terlambat >= 0),
        total_tagihan            INT  NOT NULL,
        status                   VARCHAR(15) NOT NULL DEFAULT 'belum_dibayar'
                                   CHECK (status IN ('belum_dibayar', 'terlambat', 'lunas')),
        qr_kedaluwarsa_pada      TIMESTAMPTZ NULL,
        pengingat_terkirim       JSONB NOT NULL DEFAULT '[]'::jsonb,
        dibayar_pada             TIMESTAMPTZ NULL,
        dibuat_pada              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        diperbarui_pada          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        CHECK (periode_selesai > periode_mulai),
        -- total wajib konsisten dengan komponennya
        CHECK (total_tagihan = biaya_kamar + biaya_air + biaya_admin + denda),
        -- tidak boleh ada dua tagihan untuk periode yang sama
        UNIQUE (penghuni_id, periode_mulai)
      )
      ''',
      r'CREATE INDEX IF NOT EXISTS ix_tagihan_status_tempo ON tagihan (status, jatuh_tempo)',

      // ---------------------------------------------------------------
      // 8. pembayaran (pencatatan dana masuk & sumber dana)
      // ---------------------------------------------------------------
      r'''
      CREATE TABLE IF NOT EXISTS pembayaran (
        id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        pemesanan_id            UUID NULL REFERENCES pemesanan(id) ON DELETE SET NULL,
        tagihan_id              UUID NULL REFERENCES tagihan(id)   ON DELETE SET NULL,
        penghuni_id             UUID NULL REFERENCES penghuni(id)  ON DELETE SET NULL,
        nama_penghuni_snapshot  VARCHAR(120) NOT NULL,
        nomor_kamar_snapshot    VARCHAR(20)  NOT NULL,
        jenis_pembayaran        VARCHAR(20)  NOT NULL
                                  CHECK (jenis_pembayaran IN ('pemesanan_awal', 'tagihan_rutin')),
        jumlah                  INT NOT NULL CHECK (jumlah > 0),
        id_order_gateway        VARCHAR(80) NOT NULL UNIQUE,
        qr_code_url             TEXT NOT NULL,
        status                  VARCHAR(20) NOT NULL DEFAULT 'menunggu'
                                  CHECK (status IN ('menunggu', 'berhasil', 'gagal', 'kedaluwarsa')),
        dibayar_pada            TIMESTAMPTZ NULL,
        dibuat_pada             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        diperbarui_pada         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        -- satu pembayaran merujuk paling banyak satu sumber (pemesanan ATAU tagihan)
        CHECK (num_nonnulls(pemesanan_id, tagihan_id) <= 1)
      )
      ''',
      r'''
      CREATE UNIQUE INDEX IF NOT EXISTS ux_pembayaran_menunggu_tagihan
        ON pembayaran (tagihan_id) WHERE status = 'menunggu' AND tagihan_id IS NOT NULL
      ''',
      r'''
      CREATE UNIQUE INDEX IF NOT EXISTS ux_pembayaran_menunggu_pemesanan
        ON pembayaran (pemesanan_id) WHERE status = 'menunggu' AND pemesanan_id IS NOT NULL
      ''',
      r'CREATE INDEX IF NOT EXISTS ix_pembayaran_penghuni ON pembayaran (penghuni_id)',

      // ---------------------------------------------------------------
      // 9. keluhan
      // ---------------------------------------------------------------
      r'''
      CREATE TABLE IF NOT EXISTS keluhan (
        id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        penghuni_id       UUID NOT NULL REFERENCES penghuni(id) ON DELETE CASCADE,
        kamar_id          UUID NULL REFERENCES kamar(id) ON DELETE SET NULL,
        kategori          VARCHAR(60) NOT NULL,
        deskripsi         TEXT NOT NULL,
        url_foto          VARCHAR(150) NULL,
        status            VARCHAR(20) NOT NULL DEFAULT 'diajukan'
                            CHECK (status IN ('diajukan', 'diproses', 'selesai')),
        catatan_admin     TEXT NULL,
        diselesaikan_pada TIMESTAMPTZ NULL,
        dibuat_pada       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        diperbarui_pada   TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
      ''',
      r'CREATE INDEX IF NOT EXISTS ix_keluhan_penghuni ON keluhan (penghuni_id)',
      r'CREATE INDEX IF NOT EXISTS ix_keluhan_status ON keluhan (status)',

      // ---------------------------------------------------------------
      // 10-11. pengumuman & status baca
      // ---------------------------------------------------------------
      r'''
      CREATE TABLE IF NOT EXISTS pengumuman (
        id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        judul               VARCHAR(150) NOT NULL,
        isi                 TEXT NOT NULL,
        tanggal_pengumuman  DATE NOT NULL DEFAULT CURRENT_DATE,
        dibuat_oleh         UUID NULL REFERENCES akun(id) ON DELETE SET NULL,
        dibuat_pada         TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
      ''',
      r'''
      CREATE TABLE IF NOT EXISTS pengumuman_dibaca (
        id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        pengumuman_id  UUID NOT NULL REFERENCES pengumuman(id) ON DELETE CASCADE,
        penghuni_id    UUID NOT NULL REFERENCES penghuni(id)   ON DELETE CASCADE,
        dibaca_pada    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        UNIQUE (pengumuman_id, penghuni_id)
      )
      ''',
      r'CREATE INDEX IF NOT EXISTS ix_pengumuman_dibaca_penghuni ON pengumuman_dibaca (penghuni_id)',

      // ---------------------------------------------------------------
      // 12. notifikasi
      // ---------------------------------------------------------------
      r'''
      CREATE TABLE IF NOT EXISTS notifikasi (
        id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        akun_id       UUID NOT NULL REFERENCES akun(id) ON DELETE CASCADE,
        judul         VARCHAR(150) NOT NULL,
        isi           TEXT NOT NULL,
        tipe          VARCHAR(30) NOT NULL
                        CHECK (tipe IN ('tagihan', 'pembayaran', 'pengumuman', 'keluhan', 'sistem')),
        sudah_dibaca  BOOLEAN NOT NULL DEFAULT FALSE,
        kirim_email   BOOLEAN NOT NULL DEFAULT FALSE,
        dibuat_pada   TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
      ''',
      r'''
      CREATE INDEX IF NOT EXISTS ix_notifikasi_akun_belum_dibaca
        ON notifikasi (akun_id, dibuat_pada DESC) WHERE sudah_dibaca = FALSE
      ''',

      // ---------------------------------------------------------------
      // 13. webhook_terproses (idempotensi payment gateway)
      // ---------------------------------------------------------------
      r'''
      CREATE TABLE IF NOT EXISTS webhook_terproses (
        kunci_webhook   VARCHAR(80) PRIMARY KEY,
        waktu_diproses  TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
      ''',
    ];

    for (final sql in statements) {
      await conn.execute(sql);
    }

    // Pastikan kolom ktp_data tersedia untuk database lama & isi url_foto default kamar
    await conn.execute(
      'ALTER TABLE penghuni ADD COLUMN IF NOT EXISTS ktp_data TEXT NULL',
    );
    await conn.execute('''
      UPDATE kamar
      SET url_foto = CASE
        WHEN nomor_kamar IN ('11','17','23','29','35','36','37','38','39')
             OR harga_per_bulan >= 1500000
          THEN 'assets/images/kamar_besar_ac.jpg'
        ELSE 'assets/images/kamar_kecil.jpg'
      END
      WHERE url_foto IS NULL OR url_foto = ''
    ''');

    // Trigger diperbarui_pada untuk semua tabel yang punya kolomnya
    const tabelBerTrigger = [
      'akun',
      'kamar',
      'penghuni',
      'pemesanan',
      'tagihan',
      'pembayaran',
      'keluhan',
    ];
    for (final t in tabelBerTrigger) {
      await conn.execute('DROP TRIGGER IF EXISTS trg_${t}_diperbarui ON $t');
      await conn.execute('''
        CREATE TRIGGER trg_${t}_diperbarui
        BEFORE UPDATE ON $t
        FOR EACH ROW EXECUTE FUNCTION set_diperbarui_pada()
      ''');
    }
  }

  /// Hash kata sandi deterministik (kompatibel dengan PasswordSecurity di Flutter).
  static String hashPassword(String plainText) {
    const salt = 'estopa_kos_medan_2026_salt';
    final bytes = utf8.encode('$salt::$plainText');
    int h1 = 0x811c9dc5;
    int h2 = 0x01000193;
    for (int i = 0; i < bytes.length; i++) {
      h1 ^= bytes[i];
      h1 = (h1 * 0x01000193) & 0xFFFFFFFF;
      h2 ^= (bytes[i] + i) & 0xFF;
      h2 = (h2 * 0x85ebca6b) & 0xFFFFFFFF;
    }
    final hex1 = h1.toRadixString(16).padLeft(8, '0');
    final hex2 = h2.toRadixString(16).padLeft(8, '0');
    return 'sha256\$$hex1$hex2${hex1.split('').reversed.join()}${hex2.split('').reversed.join()}';
  }

  Future<void> _seedIfEmpty() async {
    final res = await conn.execute('SELECT COUNT(*) FROM kamar');
    final roomCount = (res.first.first as int?) ?? 0;
    if (roomCount > 0) return;

    stdout.writeln(
      '[DB] Mengisi data awal 39 kamar, akun RBAC (@gmail.com), tagihan & dana masuk ke PostgreSQL...',
    );

    final adminPassHash = hashPassword('admin123');
    final defaultPassHash = hashPassword('password123');

    // 1. Buat Akun & Peran Admin (haziqalfareza06@gmail.com)
    await conn.execute(
      Sql.named('''
        INSERT INTO akun (id, email, no_hp, password_hash, aktif)
        VALUES (@id::uuid, @email, @phone, @pwd, TRUE)
        ON CONFLICT (id) DO NOTHING
      '''),
      parameters: {
        'id': adminAkunUuid,
        'email': 'haziqalfareza06@gmail.com',
        'phone': '08116001234',
        'pwd': adminPassHash,
      },
    );
    await conn.execute(
      Sql.named('''
        INSERT INTO peran_akun (id, akun_id, peran)
        VALUES (@id::uuid, @aid::uuid, 'admin')
        ON CONFLICT (akun_id, peran) DO NOTHING
      '''),
      parameters: {
        'id': ensureUuid('PERAN-ADMIN'),
        'aid': adminAkunUuid,
      },
    );

    // 2. Buat 39 Kamar (Nomor 1 s.d. 39) di 4 Lantai
    // - Lantai 1 (Putri): 1-10
    // - Lantai 2 (Putri): 11-22
    // - Lantai 3 (Putra): 23-34
    // - Lantai 4 (Putra): 35-39
    const largeRoomNumbers = {11, 17, 23, 29, 35, 36, 37, 38, 39};
    const smallAcRoomNumbers = {
      2,
      4,
      5,
      8,
      10,
      13,
      15,
      19,
      21,
      22,
      25,
      27,
      30,
      32,
      34,
    };

    int floorForRoom(int num) {
      if (num <= 10) return 1;
      if (num <= 22) return 2;
      if (num <= 34) return 3;
      return 4;
    }

    for (int num = 1; num <= 39; num++) {
      final roomNumber = '$num';
      final floor = floorForRoom(num);
      final tipe = floor <= 2 ? 'putri' : 'putra';
      final isLarge = largeRoomNumbers.contains(num);
      final isSmallAc = smallAcRoomNumbers.contains(num);

      final int price;
      final List<String> facilities;
      if (isLarge) {
        price = 1500000;
        facilities = [
          'Kamar Besar',
          'AC',
          'Kamar Mandi Dalam',
          'Wi-Fi Cepat',
          'Kasur Springbed',
          'Lemari & Meja Belajar',
        ];
      } else if (isSmallAc) {
        price = 1300000;
        facilities = [
          'Kamar Kecil',
          'AC',
          'Kamar Mandi Dalam',
          'Wi-Fi Cepat',
          'Kasur Springbed',
          'Lemari & Meja Belajar',
        ];
      } else {
        price = 900000;
        facilities = [
          'Kamar Kecil',
          'Kipas Angin',
          'Kamar Mandi Dalam',
          'Wi-Fi',
          'Kasur Busa',
          'Lemari Pakaian',
        ];
      }

      final photoAsset = isLarge
          ? 'assets/images/kamar_besar_ac.jpg'
          : 'assets/images/kamar_kecil.jpg';

      await conn.execute(
        Sql.named('''
          INSERT INTO kamar (id, nomor_kamar, lantai, tipe, harga_per_bulan, fasilitas, url_foto, status)
          VALUES (@id::uuid, @num, @floor, @tipe, @price, @fac::jsonb, @foto, 'tersedia')
          ON CONFLICT (nomor_kamar) DO NOTHING
        '''),
        parameters: {
          'id': ensureUuid('RM-$roomNumber'),
          'num': roomNumber,
          'floor': floor,
          'tipe': tipe,
          'price': price,
          'fac': jsonEncode(facilities),
          'foto': photoAsset,
        },
      );
    }

    final now = DateTime.now().toUtc();
    DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

    final seedTenants = [
      {
        'key': 'TNT-001',
        'fullName': 'Nadia Salsabila Siregar',
        'phone': '081260001111',
        'email': 'nadia@gmail.com',
        'originAddress': 'Jl. Sisingamangaraja No. 45, Rantauprapat',
        'parentName': 'H. Ahmad Siregar',
        'parentPhone': '081361112222',
        'ktpNumber': '1209015504040001',
        'ktpFileName': 'ktp_nadia_siregar.jpg',
        'roomNumber': '2',
        'roomNumberSnapshot': '2',
        'isActive': true,
        'periodeBulan': 1,
        'leaseStartDate': dateOnly(now.subtract(const Duration(days: 28))),
        'leaseEndDate': dateOnly(now.add(const Duration(days: 2))),
      },
      {
        'key': 'TNT-002',
        'fullName': 'Rizky Pratama Ginting',
        'phone': '081260002222',
        'email': 'rizky@gmail.com',
        'originAddress': 'Jl. Veteran No. 12, Kabanjahe, Karo',
        'parentName': 'Bapak Darmawan Ginting',
        'parentPhone': '081362223333',
        'ktpNumber': '1206011208030002',
        'ktpFileName': 'ktp_rizky_ginting.jpg',
        'roomNumber': '23',
        'roomNumberSnapshot': '23',
        'isActive': true,
        'periodeBulan': 1,
        'leaseStartDate': dateOnly(now.subtract(const Duration(days: 33))),
        'leaseEndDate': dateOnly(now.subtract(const Duration(days: 3))),
      },
      {
        'key': 'TNT-003',
        'fullName': 'Kevin Immanuel Simanjuntak',
        'phone': '081260003333',
        'email': 'kevin@gmail.com',
        'originAddress': 'Jl. Diponegoro No. 88, Balige, Toba',
        'parentName': 'Bapak Poltak Simanjuntak',
        'parentPhone': '081363334444',
        'ktpNumber': '1212012101040003',
        'ktpFileName': 'ktp_kevin_simanjuntak.jpg',
        'roomNumber': '24',
        'roomNumberSnapshot': '24',
        'isActive': true,
        'periodeBulan': 3,
        'leaseStartDate': dateOnly(now.subtract(const Duration(days: 5))),
        'leaseEndDate': dateOnly(now.add(const Duration(days: 85))),
      },
      {
        'key': 'TNT-004',
        'fullName': 'Dinda Maharani Nasution (Alumni)',
        'phone': '081260004444',
        'email': 'dinda@gmail.com',
        'originAddress': 'Jl. Sudirman No. 19, Padangsidimpuan',
        'parentName': 'Bapak Syahrul Nasution',
        'parentPhone': '081364445555',
        'ktpNumber': '1277014402020004',
        'ktpFileName': 'ktp_dinda_nasution.jpg',
        'roomNumber': null,
        'roomNumberSnapshot': '12 (Sudah Keluar)',
        'isActive': false,
        'periodeBulan': 1,
        'leaseStartDate': dateOnly(now.subtract(const Duration(days: 120))),
        'leaseEndDate': dateOnly(now.subtract(const Duration(days: 30))),
      },
    ];

    final extraOccupiedNumbers = [
      '3',
      '7',
      '11',
      '15',
      '17',
      '25',
      '29',
      '35',
      '36',
    ];
    for (int idx = 0; idx < extraOccupiedNumbers.length; idx++) {
      final numStr = extraOccupiedNumbers[idx];
      seedTenants.add({
        'key': 'TNT-10$idx',
        'fullName': 'Penghuni Kamar $numStr',
        'phone': '08126999000$idx',
        'email': 'kamar$numStr@gmail.com',
        'originAddress': 'Sumatera Utara',
        'parentName': 'Orang Tua Kamar $numStr',
        'parentPhone': '08136999000$idx',
        'ktpNumber': '127101000000000$idx',
        'ktpFileName': 'ktp_kamar_$numStr.jpg',
        'roomNumber': numStr,
        'roomNumberSnapshot': numStr,
        'isActive': true,
        'periodeBulan': 1,
        'leaseStartDate': dateOnly(now.subtract(const Duration(days: 15))),
        'leaseEndDate': dateOnly(now.add(const Duration(days: 15))),
      });
    }

    for (final t in seedTenants) {
      final key = t['key'] as String;
      final akunId = ensureUuid('AKUN-$key');
      final penghuniId = ensureUuid(key);
      final isActive = t['isActive'] as bool;
      final roomNumber = t['roomNumber'] as String?;
      final kamarId = roomNumber != null ? ensureUuid('RM-$roomNumber') : null;

      await conn.execute(
        Sql.named('''
          INSERT INTO akun (id, email, no_hp, password_hash, aktif)
          VALUES (@id::uuid, @email, @phone, @pwd, @aktif)
          ON CONFLICT (id) DO NOTHING
        '''),
        parameters: {
          'id': akunId,
          'email': t['email'],
          'phone': t['phone'],
          'pwd': defaultPassHash,
          'aktif': isActive,
        },
      );

      await conn.execute(
        Sql.named('''
          INSERT INTO peran_akun (id, akun_id, peran)
          VALUES (@id::uuid, @aid::uuid, 'penghuni')
          ON CONFLICT (akun_id, peran) DO NOTHING
        '''),
        parameters: {
          'id': ensureUuid('PERAN-$key'),
          'aid': akunId,
        },
      );

      await conn.execute(
        Sql.named('''
          INSERT INTO penghuni (
            id, akun_id, kamar_id, riwayat_nomor_kamar, nama_lengkap, alamat_asal,
            nama_orang_tua, no_hp_orang_tua, nomor_ktp, url_ktp, persetujuan_ktp,
            tanggal_masuk, tanggal_keluar, periode_bayar_bulan, dibayar_sampai, status
          ) VALUES (
            @id::uuid, @aid::uuid, @kid::uuid, @snap, @name, @addr,
            @pname, @pphone, @ktp, @urlKtp, TRUE,
            @tMasuk, @tKeluar, @periode, @dibayarSampai, @status
          )
          ON CONFLICT (id) DO NOTHING
        '''),
        parameters: {
          'id': penghuniId,
          'aid': akunId,
          'kid': kamarId,
          'snap': t['roomNumberSnapshot'],
          'name': t['fullName'],
          'addr': t['originAddress'],
          'pname': t['parentName'],
          'pphone': t['parentPhone'],
          'ktp': t['ktpNumber'],
          'urlKtp': t['ktpFileName'],
          'tMasuk': t['leaseStartDate'],
          'tKeluar': isActive ? null : t['leaseEndDate'],
          'periode': t['periodeBulan'],
          'dibayarSampai': t['leaseEndDate'],
          'status': isActive ? 'aktif' : 'nonaktif',
        },
      );

      if (kamarId != null && isActive) {
        await conn.execute(
          Sql.named('''
            UPDATE kamar
            SET status = 'terisi', ditahan_sampai = NULL
            WHERE id = @kid::uuid
          '''),
          parameters: {'kid': kamarId},
        );
      }
    }

    // 3. Seed Tagihan (tagihan)
    final tnt1 = ensureUuid('TNT-001');
    final tnt2 = ensureUuid('TNT-002');
    final tnt3 = ensureUuid('TNT-003');
    final tnt4 = ensureUuid('TNT-004');
    final inv1 = ensureUuid('INV-2026-001');
    final inv2 = ensureUuid('INV-2026-002');
    final inv3 = ensureUuid('INV-2026-003');

    await conn.execute(
      Sql.named('''
        INSERT INTO tagihan (
          id, penghuni_id, nama_penghuni_snapshot, nomor_kamar_snapshot,
          periode_bulan, periode_mulai, periode_selesai, jatuh_tempo,
          biaya_kamar, biaya_air, biaya_admin, denda, jumlah_hari_terlambat,
          total_tagihan, status, pengingat_terkirim, dibayar_pada
        ) VALUES
        (@i1::uuid, @t1::uuid, 'Nadia Salsabila Siregar', '2',
         1, @m1, @s1, @j1, 1300000, 35000, 4000, 0, 0,
         1339000, 'belum_dibayar', @r1::jsonb, NULL),
        (@i2::uuid, @t2::uuid, 'Rizky Pratama Ginting', '23',
         1, @m2, @s2, @j2, 1500000, 35000, 4000, 150000, 3,
         1689000, 'terlambat', @r2::jsonb, NULL),
        (@i3::uuid, @t3::uuid, 'Kevin Immanuel Simanjuntak', '24',
         3, @m3, @s3, @j3, 2700000, 105000, 4000, 0, 0,
         2809000, 'lunas', @r3::jsonb, @paid3)
        ON CONFLICT (id) DO NOTHING
      '''),
      parameters: {
        'i1': inv1,
        't1': tnt1,
        'm1': dateOnly(now.add(const Duration(days: 2))),
        's1': dateOnly(now.add(const Duration(days: 32))),
        'j1': dateOnly(now.add(const Duration(days: 2))),
        'r1': jsonEncode(['H-3', 'H-2']),
        'i2': inv2,
        't2': tnt2,
        'm2': dateOnly(now.subtract(const Duration(days: 3))),
        's2': dateOnly(now.add(const Duration(days: 27))),
        'j2': dateOnly(now.subtract(const Duration(days: 3))),
        'r2': jsonEncode([
          'H-3',
          'H-2',
          'H-1',
          'Denda Hari ke-1',
          'Denda Hari ke-2',
          'Denda Hari ke-3',
        ]),
        'i3': inv3,
        't3': tnt3,
        'm3': dateOnly(now.subtract(const Duration(days: 5))),
        's3': dateOnly(now.add(const Duration(days: 85))),
        'j3': dateOnly(now.subtract(const Duration(days: 5))),
        'r3': jsonEncode(['H-3']),
        'paid3': now.subtract(const Duration(days: 5)),
      },
    );

    // 4. Seed Pembayaran / Dana Masuk (pembayaran)
    await conn.execute(
      Sql.named('''
        INSERT INTO pembayaran (
          id, pemesanan_id, tagihan_id, penghuni_id,
          nama_penghuni_snapshot, nomor_kamar_snapshot,
          jenis_pembayaran, jumlah, id_order_gateway, qr_code_url, status, dibayar_pada
        ) VALUES
        (@p1::uuid, NULL, @i3::uuid, @t3::uuid,
         'Kevin Immanuel Simanjuntak', '24',
         'tagihan_rutin', 2809000, 'GW-QRIS-9928172', 'QRIS-INV-24-2809000', 'berhasil', @dt1),
        (@p2::uuid, NULL, NULL, @t1::uuid,
         'Nadia Salsabila Siregar', '2',
         'pemesanan_awal', 1339000, 'GW-QRBOOK-8817261', 'QRIS-BOOK-2-1339000', 'berhasil', @dt2),
        (@p3::uuid, NULL, NULL, @t4::uuid,
         'Dinda Maharani Nasution (Alumni)', '12',
         'tagihan_rutin', 939000, 'GW-QRIS-7712390', 'QRIS-INV-12-939000', 'berhasil', @dt3)
        ON CONFLICT (id) DO NOTHING
      '''),
      parameters: {
        'p1': ensureUuid('PAY-2026-101'),
        'i3': inv3,
        't3': tnt3,
        'dt1': now.subtract(const Duration(days: 5)),
        'p2': ensureUuid('PAY-2026-102'),
        't1': tnt1,
        'dt2': now.subtract(const Duration(days: 28)),
        'p3': ensureUuid('PAY-2026-103'),
        't4': tnt4,
        'dt3': now.subtract(const Duration(days: 60)),
      },
    );

    // 5. Seed Keluhan (keluhan)
    await conn.execute(
      Sql.named('''
        INSERT INTO keluhan (
          id, penghuni_id, kamar_id, kategori, deskripsi,
          url_foto, status, catatan_admin, diselesaikan_pada, dibuat_pada
        ) VALUES
        (@c1::uuid, @t1::uuid, @k1::uuid, 'Kamar Mandi / Air',
         'Kran wastafel kamar mandi dalam agak menetes saat ditutup rapat.',
         'foto_kran_2.jpg', 'diproses',
         'Tukang pipa dijadwalkan datang besok pukul 10.00 WIB.', NULL, @dt1),
        (@c2::uuid, @t2::uuid, @k2::uuid, 'Internet / Wi-Fi',
         'Sinyal Wi-Fi di pojok kamar 23 agak lemah saat malam hari.',
         NULL, 'selesai',
         'Repeater lantai 3 sudah di-restart dan dipindah ke tengah lorong.', @dt2, @dt2)
        ON CONFLICT (id) DO NOTHING
      '''),
      parameters: {
        'c1': ensureUuid('CMP-001'),
        't1': tnt1,
        'k1': ensureUuid('RM-2'),
        'dt1': now.subtract(const Duration(days: 1, hours: 4)),
        'c2': ensureUuid('CMP-002'),
        't2': tnt2,
        'k2': ensureUuid('RM-23'),
        'dt2': now.subtract(const Duration(days: 6)),
      },
    );

    // 6. Seed Pengumuman (pengumuman & pengumuman_dibaca)
    final ann1 = ensureUuid('ANN-001');
    final ann2 = ensureUuid('ANN-002');
    await conn.execute(
      Sql.named('''
        INSERT INTO pengumuman (id, judul, isi, tanggal_pengumuman, dibuat_oleh, dibuat_pada)
        VALUES
        (@a1::uuid, 'Jadwal Pembersihan Tandon Air Utama Lantai 4',
         'Diberitahukan kepada seluruh penghuni Estopa Kos bahwa pada hari Sabtu pukul 09.00 - 11.00 WIB akan dilakukan pengurasan tandon air. Mohon menampung air secukupnya.',
         @d1, @adm::uuid, @dt1),
        (@a2::uuid, 'Ketentuan Jam Malam & Tamu Lawan Jenis',
         'Demi kenyamanan dan keamanan bersama di lingkungan Jl. Sei Padang, batas waktu kunjungan tamu di ruang tunggu adalah pukul 22.00 WIB. Tamu lawan jenis dilarang keras masuk ke area kamar.',
         @d2, @adm::uuid, @dt2)
        ON CONFLICT (id) DO NOTHING
      '''),
      parameters: {
        'a1': ann1,
        'd1': dateOnly(now.subtract(const Duration(days: 2))),
        'dt1': now.subtract(const Duration(days: 2)),
        'a2': ann2,
        'd2': dateOnly(now.subtract(const Duration(days: 14))),
        'dt2': now.subtract(const Duration(days: 14)),
        'adm': adminAkunUuid,
      },
    );

    final reads = [
      [ann1, tnt1],
      [ann1, tnt3],
      [ann2, tnt1],
      [ann2, tnt2],
      [ann2, tnt3],
    ];
    for (var i = 0; i < reads.length; i++) {
      await conn.execute(
        Sql.named('''
          INSERT INTO pengumuman_dibaca (id, pengumuman_id, penghuni_id)
          VALUES (@id::uuid, @aid::uuid, @tid::uuid)
          ON CONFLICT (pengumuman_id, penghuni_id) DO NOTHING
        '''),
        parameters: {
          'id': ensureUuid('READ-$i'),
          'aid': reads[i][0],
          'tid': reads[i][1],
        },
      );
    }

    // 7. Seed Notifikasi (notifikasi)
    await conn.execute(
      Sql.named('''
        INSERT INTO notifikasi (id, akun_id, judul, isi, tipe, sudah_dibaca, kirim_email, dibuat_pada)
        VALUES
        (@n1::uuid, @ak1::uuid, 'Pengingat Tagihan H-2 (Kamar 2)',
         'Halo Nadia, tagihan sewa Kamar 2 akan jatuh tempo dalam 2 hari. Silakan buat kode QR pembayaran di menu Tagihan.',
         'tagihan', FALSE, TRUE, @dt1),
        (@n2::uuid, @ak2::uuid, 'Peringatan Keterlambatan Hari ke-3 (+Rp150.000)',
         'Tagihan Kamar 23 telah melewati jatuh tempo 3 hari. Denda keterlambatan Rp50.000/hari otomatis ditambahkan.',
         'tagihan', FALSE, TRUE, @dt2),
        (@n3::uuid, @adm::uuid, 'Laporan Keluhan Baru: Kamar 2',
         'Nadia Salsabila Siregar (Kamar 2) mengirimkan keluhan kategori Kamar Mandi / Air.',
         'keluhan', FALSE, TRUE, @dt3)
        ON CONFLICT (id) DO NOTHING
      '''),
      parameters: {
        'n1': ensureUuid('NTF-001'),
        'ak1': ensureUuid('AKUN-TNT-001'),
        'dt1': now.subtract(const Duration(hours: 5)),
        'n2': ensureUuid('NTF-002'),
        'ak2': ensureUuid('AKUN-TNT-002'),
        'dt2': now.subtract(const Duration(hours: 2)),
        'n3': ensureUuid('NTF-003'),
        'adm': adminAkunUuid,
        'dt3': now.subtract(const Duration(days: 1, hours: 4)),
      },
    );
  }

  /// Cron Job: Bersihkan pemesanan yang sudah lewat 20 menit (FR-15 & NFR-04).
  Future<int> cleanupExpiredBookingHolds() async {
    return conn.runTx((s) async {
      final expiredRows = await s.execute(
        Sql.named('''
          SELECT p.id, p.kamar_id, p.penghuni_id, pg.akun_id
          FROM pemesanan p
          JOIN penghuni pg ON pg.id = p.penghuni_id
          WHERE p.status = 'menunggu' AND p.kedaluwarsa_pada <= @now
        '''),
        parameters: {'now': DateTime.now().toUtc()},
      );
      if (expiredRows.isEmpty) return 0;

      for (final row in expiredRows) {
        final pemesananId = row[0].toString();
        final kamarId = row[1].toString();
        final akunId = row[3].toString();

        await s.execute(
          Sql.named('''
            UPDATE kamar
            SET status = 'tersedia', ditahan_sampai = NULL
            WHERE id = @kid::uuid AND status = 'ditahan'
          '''),
          parameters: {'kid': kamarId},
        );
        await s.execute(
          Sql.named('DELETE FROM pemesanan WHERE id = @pid::uuid'),
          parameters: {'pid': pemesananId},
        );
        // Hapus akun & biodata sementara yang belum bayar (NFR-04)
        await s.execute(
          Sql.named('''
            DELETE FROM akun
            WHERE id = @aid::uuid
              AND EXISTS (
                SELECT 1 FROM penghuni pg
                WHERE pg.akun_id = akun.id AND pg.status = 'menunggu_pembayaran'
              )
          '''),
          parameters: {'aid': akunId},
        );
      }
      return expiredRows.length;
    });
  }
}
