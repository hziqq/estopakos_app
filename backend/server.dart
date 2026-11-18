import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:postgres/postgres.dart';
import 'db.dart';
import 'email_service.dart';

/// Server Backend REST API PostgreSQL + Webhook Payment Gateway + Cron Scheduler
/// untuk Sistem Informasi Manajemen Estopa Kos (Skema Baru UUID + RBAC Bahasa Indonesia).
void main() async {
  final dbConfig = EstopaDbConfig.fromEnv();
  final emailService = EstopaEmailService.fromEnv();
  stdout.writeln(
    '[BOOT] Menghubungkan ke PostgreSQL ${dbConfig.host}:${dbConfig.port}/${dbConfig.database} (user: ${dbConfig.username})...',
  );

  late final EstopaDatabase db;
  try {
    db = await EstopaDatabase.connectAndInit(dbConfig);
    stdout.writeln(
      '[DB] Terkoneksi ke PostgreSQL "${db.config.database}" (user: ${db.config.username})!',
    );
  } catch (e) {
    stderr.writeln('[ERROR] Gagal konek ke PostgreSQL: $e');
    stderr.writeln(
      'Pastikan PostgreSQL berjalan dan periksa PG_USER / PG_PASSWORD di backend/.env.',
    );
    exit(1);
  }

  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);

  stdout.writeln('===========================================================');
  stdout.writeln(' ESTOPA KOS BACKEND API (POSTGRESQL UUID & RBAC) AKTIF');
  stdout.writeln(' URL Server : http://localhost:$port/api');
  stdout.writeln(' Database   : PostgreSQL (${db.config.database})');
  stdout.writeln(' Email Admin: ${emailService.smtpUser}');
  stdout.writeln(
    ' SMTP Status: ${emailService.isSmtpConfigured ? "SIAP KIRIM EMAIL OTOMATIS" : "BELUM DIATUR"}',
  );
  stdout.writeln('===========================================================');

  // Cron Scheduler (setiap 30 detik membersihkan pemesanan > 20 menit FR-15)
  Timer.periodic(const Duration(seconds: 30), (_) async {
    try {
      final cleaned = await db.cleanupExpiredBookingHolds();
      if (cleaned > 0) {
        stdout.writeln(
          '[CRON ${DateTime.now().toIso8601String()}] Membersihkan $cleaned pemesanan kedaluwarsa (>20m) & mengembalikan kamar.',
        );
      }
    } catch (e) {
      stderr.writeln('[CRON ERROR] $e');
    }
  });

  await for (final HttpRequest req in server) {
    req.response.headers.contentType = ContentType.json;
    req.response.headers.add('Access-Control-Allow-Origin', '*');
    req.response.headers.add(
      'Access-Control-Allow-Methods',
      'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    );
    req.response.headers.add(
      'Access-Control-Allow-Headers',
      'Content-Type, Accept',
    );

    if (req.method == 'OPTIONS') {
      req.response.statusCode = HttpStatus.noContent;
      await req.response.close();
      continue;
    }

    final path = req.uri.path;
    final method = req.method;

    try {
      if (method == 'GET' && path == '/api/health') {
        final countRes = await db.conn.execute('SELECT COUNT(*) FROM kamar');
        req.response.write(
          jsonEncode({
            'status': 'ok',
            'database': 'postgresql',
            'db_name': db.config.database,
            'rooms_total': countRes.first.first,
          }),
        );
      } else if (method == 'GET' && path == '/api/bootstrap') {
        await db.cleanupExpiredBookingHolds();
        final data = await _loadBootstrap(db.conn);
        req.response.write(jsonEncode(data));
      } else if (method == 'POST' && path == '/api/bookings') {
        final body = await _readJson(req);
        final hold = await _createBookingHold(db.conn, body);
        req.response.write(jsonEncode(hold));
      } else if (method == 'POST' && path == '/api/bookings/expire') {
        final body = await _readJson(req);
        await _expireBookingHold(db.conn, body['holdId'] as String);
        req.response.write(jsonEncode({'status': 'expired_and_cleaned'}));
      } else if (method == 'POST' && path == '/api/bookings/pay') {
        final body = await _readJson(req);
        final res = await _completeBookingPayment(
          db.conn,
          emailService,
          body['holdId'] as String,
          plainPassword: body['plainPassword'] as String?,
          skipEmail: body['skipEmail'] == true,
        );
        req.response.write(jsonEncode(res));
      } else if (method == 'GET' && path == '/api/email/config') {
        req.response.write(
          jsonEncode({
            'smtpHost': emailService.smtpHost,
            'smtpPort': emailService.smtpPort,
            'smtpUser': emailService.smtpUser,
            'smtpConfigured': emailService.isSmtpConfigured,
          }),
        );
      } else if (method == 'POST' && path == '/api/email/config') {
        final body = await _readJson(req);
        emailService.updateSmtpConfig(
          host: (body['smtpHost'] as String?) ?? 'smtp.gmail.com',
          port: (body['smtpPort'] as int?) ?? 587,
          user: (body['smtpUser'] as String?) ?? 'haziqalfareza06@gmail.com',
          pass: (body['smtpPass'] as String?) ?? '',
        );
        req.response.write(
          jsonEncode({
            'status': 'updated',
            'smtpConfigured': emailService.isSmtpConfigured,
            'smtpUser': emailService.smtpUser,
          }),
        );
      } else if (method == 'POST' && path == '/api/email/welcome') {
        final body = await _readJson(req);
        final delivery = await emailService.sendWelcomeBookingEmail(
          fullName: (body['fullName'] as String?) ?? 'Penghuni Estopa Kos',
          email: (body['email'] as String?) ?? '',
          phone: (body['phone'] as String?) ?? '-',
          roomNumber: (body['roomNumber'] as String?) ?? '-',
          months: (body['months'] as int?) ?? 1,
          roomCost: (body['roomCost'] as int?) ?? 0,
          waterCost: (body['waterCost'] as int?) ?? 35000,
          transactionFee: (body['transactionFee'] as int?) ?? 4000,
          totalAmount: (body['totalAmount'] as int?) ?? 0,
          plainPassword: body['plainPassword'] as String?,
        );
        req.response.write(jsonEncode(delivery.toJson()));
      } else if (method == 'POST' && path == '/api/invoices/months') {
        final body = await _readJson(req);
        await _updateInvoiceMonths(
          db.conn,
          body['invoiceId'] as String,
          body['months'] as int,
          roomNumber: body['roomNumber'] as String?,
        );
        req.response.write(jsonEncode({'status': 'updated'}));
      } else if (method == 'POST' && path == '/api/invoices/qr') {
        final body = await _readJson(req);
        await _generateInvoiceQr(
          db.conn,
          invoiceId: body['invoiceId'] as String,
          qrCode: body['qrCode'] as String,
          expiresAt: DateTime.parse(body['expiresAt'] as String).toUtc(),
          roomNumber: body['roomNumber'] as String?,
        );
        req.response.write(jsonEncode({'status': 'qr_generated'}));
      } else if (method == 'POST' && path == '/api/invoices/simulate-late') {
        final body = await _readJson(req);
        await _simulateLateDay(
          db.conn,
          body['invoiceId'] as String,
          roomNumber: body['roomNumber'] as String?,
        );
        req.response.write(jsonEncode({'status': 'overdue_updated'}));
      } else if (method == 'POST' && path == '/api/invoices/pay') {
        final body = await _readJson(req);
        await _payInvoice(
          db.conn,
          body['invoiceId'] as String,
          roomNumber: body['roomNumber'] as String?,
        );
        req.response.write(jsonEncode({'status': 'paid'}));
      } else if (method == 'POST' && path == '/api/reminders/trigger') {
        final count = await _triggerReminders(db.conn);
        req.response.write(jsonEncode({'sent': count}));
      } else if (method == 'PUT' && path == '/api/rooms') {
        final body = await _readJson(req);
        final roomUuid = EstopaDatabase.ensureUuid(body['id'] as String);
        await db.conn.execute(
          Sql.named('''
            UPDATE kamar
            SET nomor_kamar = @num, lantai = @floor, harga_per_bulan = @price,
                tipe = @gender, fasilitas = @fac::jsonb
            WHERE id = @id::uuid
          '''),
          parameters: {
            'id': roomUuid,
            'num': body['number'],
            'floor': body['floor'],
            'price': body['pricePerMonth'],
            'gender': body['gender'],
            'fac': jsonEncode(body['facilities']),
          },
        );
        req.response.write(jsonEncode({'status': 'updated'}));
      } else if (method == 'POST' && path == '/api/rooms/vacate') {
        final body = await _readJson(req);
        await _vacateRoom(db.conn, body['roomId'] as String);
        req.response.write(jsonEncode({'status': 'vacated'}));
      } else if (method == 'POST' && path == '/api/tenants') {
        final body = await _readJson(req);
        await _addTenantByAdmin(db.conn, body);
        req.response.write(jsonEncode({'status': 'created'}));
      } else if (method == 'PUT' && path == '/api/tenants') {
        final body = await _readJson(req);
        await _updateTenantByAdmin(db.conn, body);
        req.response.write(jsonEncode({'status': 'updated'}));
      } else if (method == 'POST' && path == '/api/tenants/reset-password') {
        final body = await _readJson(req);
        await _resetTenantPassword(
          db.conn,
          tenantId: body['tenantId'] as String,
          passwordHash: body['passwordHash'] as String,
        );
        req.response.write(jsonEncode({'status': 'password_reset'}));
      } else if (method == 'POST' && path == '/api/complaints') {
        final body = await _readJson(req);
        await _createComplaint(db.conn, body);
        req.response.write(jsonEncode({'status': 'created'}));
      } else if (method == 'PATCH' && path == '/api/complaints/status') {
        final body = await _readJson(req);
        await _updateComplaintStatus(db.conn, body);
        req.response.write(jsonEncode({'status': 'updated'}));
      } else if (method == 'POST' && path == '/api/announcements') {
        final body = await _readJson(req);
        await _createAnnouncement(db.conn, body);
        req.response.write(jsonEncode({'status': 'created'}));
      } else if (method == 'POST' && path == '/api/announcements/read') {
        final body = await _readJson(req);
        await db.conn.execute(
          Sql.named('''
            INSERT INTO pengumuman_dibaca (id, pengumuman_id, penghuni_id)
            VALUES (@id::uuid, @aid::uuid, @tid::uuid)
            ON CONFLICT (pengumuman_id, penghuni_id) DO NOTHING
          '''),
          parameters: {
            'id': EstopaDatabase.ensureUuid(
              'READ-${body['announcementId']}-${body['tenantId']}',
            ),
            'aid': EstopaDatabase.ensureUuid(body['announcementId'] as String),
            'tid': EstopaDatabase.ensureUuid(body['tenantId'] as String),
          },
        );
        req.response.write(jsonEncode({'status': 'marked_read'}));
      } else {
        req.response.statusCode = HttpStatus.notFound;
        req.response.write(
          jsonEncode({'error': 'Endpoint tidak ditemukan: $method $path'}),
        );
      }
    } catch (e) {
      stderr.writeln('[API ERROR] $method $path -> $e');
      req.response.statusCode = HttpStatus.badRequest;
      req.response.write(jsonEncode({'error': e.toString()}));
    } finally {
      await req.response.close();
    }
  }
}

Future<Map<String, dynamic>> _readJson(HttpRequest req) async {
  final raw = await utf8.decoder.bind(req).join();
  if (raw.trim().isEmpty) return {};
  return jsonDecode(raw) as Map<String, dynamic>;
}

String _iso(Object? dt) {
  if (dt is DateTime) return dt.toLocal().toIso8601String();
  return DateTime.now().toIso8601String();
}

DateTime _dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

List<String> _decodeStringList(Object? raw) {
  if (raw == null) return [];
  if (raw is List) return raw.map((e) => e.toString()).toList();
  if (raw is String && raw.trim().isNotEmpty) {
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded.map((e) => e.toString()).toList();
  }
  return [];
}

Future<Map<String, dynamic>> _loadBootstrap(Connection conn) async {
  final roomsRes = await conn.execute('''
    SELECT k.*, pg.id AS active_penghuni_id
    FROM kamar k
    LEFT JOIN penghuni pg
      ON pg.kamar_id = k.id AND pg.status = 'aktif'
    ORDER BY k.lantai ASC,
      (NULLIF(regexp_replace(k.nomor_kamar, '[^0-9]', '', 'g'), ''))::int ASC NULLS LAST,
      k.nomor_kamar ASC
  ''');

  final tenantsRes = await conn.execute('''
    SELECT pg.*, a.email, a.no_hp, a.password_hash, a.aktif AS akun_aktif,
           k.nomor_kamar AS nomor_kamar_aktif
    FROM penghuni pg
    JOIN akun a ON a.id = pg.akun_id
    LEFT JOIN kamar k ON k.id = pg.kamar_id
    WHERE pg.status IN ('aktif', 'nonaktif')
    ORDER BY (pg.status = 'aktif') DESC, pg.dibuat_pada ASC
  ''');

  final holdsRes = await conn.execute('''
    SELECT pm.*, k.nomor_kamar, k.harga_per_bulan,
           pg.nama_lengkap, pg.alamat_asal, pg.nama_orang_tua, pg.no_hp_orang_tua,
           pg.nomor_ktp, pg.url_ktp, pg.ktp_data, pg.persetujuan_ktp,
           a.email, a.no_hp, a.password_hash,
           pb.qr_code_url
    FROM pemesanan pm
    JOIN kamar k ON k.id = pm.kamar_id
    JOIN penghuni pg ON pg.id = pm.penghuni_id
    JOIN akun a ON a.id = pg.akun_id
    LEFT JOIN pembayaran pb ON pb.pemesanan_id = pm.id AND pb.status = 'menunggu'
    WHERE pm.status = 'menunggu'
    ORDER BY pm.dibuat_pada DESC
  ''');

  final invoicesRes = await conn.execute('''
    SELECT t.*, pb.qr_code_url AS active_qr_code
    FROM tagihan t
    LEFT JOIN pembayaran pb ON pb.tagihan_id = t.id AND pb.status = 'menunggu'
    ORDER BY t.jatuh_tempo ASC
  ''');

  final paymentsRes = await conn.execute('''
    SELECT pb.*,
           t.periode_bulan AS t_bulan, t.biaya_kamar AS t_kamar, t.biaya_air AS t_air,
           t.biaya_admin AS t_admin, t.denda AS t_denda,
           pm.durasi_bulan AS pm_bulan
    FROM pembayaran pb
    LEFT JOIN tagihan t ON t.id = pb.tagihan_id
    LEFT JOIN pemesanan pm ON pm.id = pb.pemesanan_id
    WHERE pb.status = 'berhasil'
    ORDER BY COALESCE(pb.dibayar_pada, pb.dibuat_pada) DESC
  ''');

  final complaintsRes = await conn.execute('''
    SELECT kl.*, pg.nama_lengkap, COALESCE(k.nomor_kamar, pg.riwayat_nomor_kamar, '-') AS nomor_kamar
    FROM keluhan kl
    JOIN penghuni pg ON pg.id = kl.penghuni_id
    LEFT JOIN kamar k ON k.id = kl.kamar_id
    ORDER BY kl.dibuat_pada DESC
  ''');

  final annRes = await conn.execute(
    'SELECT * FROM pengumuman ORDER BY dibuat_pada DESC',
  );
  final readsRes = await conn.execute(
    'SELECT pengumuman_id, penghuni_id FROM pengumuman_dibaca',
  );
  final notifRes = await conn.execute('''
    SELECT n.*, pg.id AS penghuni_id
    FROM notifikasi n
    LEFT JOIN penghuni pg ON pg.akun_id = n.akun_id
    ORDER BY n.dibuat_pada DESC
    LIMIT 100
  ''');

  final readsByAnn = <String, List<String>>{};
  for (final r in readsRes) {
    final aid = r[0].toString();
    final tid = r[1].toString();
    readsByAnn.putIfAbsent(aid, () => []).add(tid);
  }

  return {
    'rooms': roomsRes.map((r) {
      final m = r.toColumnMap();
      final dbStatus = m['status'] as String;
      final appStatus = dbStatus == 'terisi'
          ? 'occupied'
          : (dbStatus == 'ditahan' ? 'held' : 'available');
      return {
        'id': m['id'].toString(),
        'number': m['nomor_kamar'],
        'floor': m['lantai'],
        'pricePerMonth': m['harga_per_bulan'],
        'facilities': _decodeStringList(m['fasilitas']),
        'gender': m['tipe'],
        'photoUrl': m['url_foto'],
        'status': appStatus,
        'currentTenantId': m['active_penghuni_id']?.toString(),
        'holdExpiresAt':
            m['ditahan_sampai'] != null ? _iso(m['ditahan_sampai']) : null,
      };
    }).toList(),
    'tenants': tenantsRes.map((r) {
      final m = r.toColumnMap();
      final isActive =
          (m['status'] == 'aktif') && (m['akun_aktif'] as bool? ?? true);
      return {
        'id': m['id'].toString(),
        'fullName': m['nama_lengkap'],
        'phone': m['no_hp'],
        'email': m['email'],
        'originAddress': m['alamat_asal'],
        'parentName': m['nama_orang_tua'],
        'parentPhone': m['no_hp_orang_tua'],
        'password': m['password_hash'],
        'ktpNumber': m['nomor_ktp'],
        'ktpFileName': m['url_ktp'],
        'ktpImageBase64': m['ktp_data'],
        'ktpConsentAccepted': m['persetujuan_ktp'] ?? true,
        'roomId': m['kamar_id']?.toString(),
        'roomNumberSnapshot':
            m['nomor_kamar_aktif'] ?? m['riwayat_nomor_kamar'] ?? '-',
        'isActive': isActive,
        'leaseStartDate': _iso(m['tanggal_masuk'] ?? m['dibuat_pada']),
        'leaseEndDate': _iso(m['dibayar_sampai'] ?? m['dibuat_pada']),
      };
    }).toList(),
    'bookingHolds': holdsRes.map((r) {
      final m = r.toColumnMap();
      return {
        'id': m['id'].toString(),
        'roomId': m['kamar_id'].toString(),
        'roomNumber': m['nomor_kamar'],
        'roomPricePerMonth': m['harga_per_bulan'],
        'months': m['durasi_bulan'],
        'fullName': m['nama_lengkap'],
        'phone': m['no_hp'],
        'email': m['email'],
        'originAddress': m['alamat_asal'],
        'parentName': m['nama_orang_tua'],
        'parentPhone': m['no_hp_orang_tua'],
        'password': m['password_hash'],
        'ktpNumber': m['nomor_ktp'],
        'ktpFileName': m['url_ktp'],
        'ktpImageBase64': m['ktp_data'],
        'ktpConsent': m['persetujuan_ktp'] ?? true,
        'createdAt': _iso(m['dibuat_pada']),
        'expiresAt': _iso(m['kedaluwarsa_pada']),
        'qrPayload': m['qr_code_url'] ?? 'QRIS-BOOKING-ESTOPA',
        'isExpired': m['status'] == 'kedaluwarsa',
        'isPaid': m['status'] == 'dibayar',
      };
    }).toList(),
    'invoices': invoicesRes.map((r) {
      final m = r.toColumnMap();
      final dbSt = m['status'] as String;
      final appSt = dbSt == 'lunas'
          ? 'paid'
          : (dbSt == 'terlambat' ? 'overdue' : 'unpaid');
      final months = (m['periode_bulan'] as int?) ?? 1;
      final biayaKamar = (m['biaya_kamar'] as int?) ?? 0;
      final pricePerMonth = months > 0 ? (biayaKamar ~/ months) : biayaKamar;
      return {
        'id': m['id'].toString(),
        'tenantId': m['penghuni_id'].toString(),
        'tenantName': m['nama_penghuni_snapshot'],
        'roomNumber': m['nomor_kamar_snapshot'],
        'roomPricePerMonth': pricePerMonth,
        'selectedMonths': months,
        'dueDate': _iso(m['jatuh_tempo']),
        'status': appSt,
        'lateDays': m['jumlah_hari_terlambat'] ?? 0,
        'activeQrCode': m['active_qr_code'],
        'qrExpiresAt': m['qr_kedaluwarsa_pada'] != null
            ? _iso(m['qr_kedaluwarsa_pada'])
            : null,
        'paidAt': m['dibayar_pada'] != null ? _iso(m['dibayar_pada']) : null,
        'sentReminders': _decodeStringList(m['pengingat_terkirim']),
      };
    }).toList(),
    'payments': paymentsRes.map((r) {
      final m = r.toColumnMap();
      final jenis = m['jenis_pembayaran'] as String;
      final months =
          (m['t_bulan'] as int?) ?? (m['pm_bulan'] as int?) ?? 1;
      final total = m['jumlah'] as int;
      final txFee = (m['t_admin'] as int?) ?? 4000;
      final waterCost = (m['t_air'] as int?) ?? (35000 * months);
      final lateFee = (m['t_denda'] as int?) ?? 0;
      final roomCost =
          (m['t_kamar'] as int?) ?? (total - waterCost - txFee - lateFee);
      final typeLabel = jenis == 'pemesanan_awal'
          ? 'Pemesanan Awal ($months Bulan)'
          : 'Tagihan Sewa ($months Bulan)';
      return {
        'id': m['id'].toString(),
        'tenantId': (m['penghuni_id'] ?? '').toString(),
        'tenantName': m['nama_penghuni_snapshot'],
        'roomNumber': m['nomor_kamar_snapshot'],
        'type': typeLabel,
        'months': months,
        'roomCost': roomCost,
        'waterCost': waterCost,
        'transactionFee': txFee,
        'lateFee': lateFee,
        'totalAmount': total,
        'paidAt': _iso(m['dibayar_pada'] ?? m['dibuat_pada']),
        'gatewayReference': m['id_order_gateway'],
      };
    }).toList(),
    'complaints': complaintsRes.map((r) {
      final m = r.toColumnMap();
      final dbSt = m['status'] as String;
      final appSt = dbSt == 'selesai'
          ? 'resolved'
          : (dbSt == 'diproses' ? 'inProgress' : 'submitted');
      return {
        'id': m['id'].toString(),
        'tenantId': m['penghuni_id'].toString(),
        'tenantName': m['nama_lengkap'],
        'roomNumber': m['nomor_kamar'],
        'category': m['kategori'],
        'description': m['deskripsi'],
        'attachmentName': m['url_foto'],
        'createdAt': _iso(m['dibuat_pada']),
        'status': appSt,
        'adminNote': m['catatan_admin'],
      };
    }).toList(),
    'announcements': annRes.map((r) {
      final m = r.toColumnMap();
      final id = m['id'].toString();
      return {
        'id': id,
        'title': m['judul'],
        'content': m['isi'],
        'createdAt': _iso(m['dibuat_pada']),
        'readByTenantIds': readsByAnn[id] ?? [],
      };
    }).toList(),
    'notifications': notifRes.map((r) {
      final m = r.toColumnMap();
      final akunId = m['akun_id'].toString();
      final targetAudience = akunId == EstopaDatabase.adminAkunUuid
          ? 'ADMIN'
          : (m['penghuni_id']?.toString() ?? 'ALL_TENANTS');
      final kirimEmail = m['kirim_email'] as bool? ?? false;
      return {
        'id': m['id'].toString(),
        'targetAudience': targetAudience,
        'channel': kirimEmail ? 'SISTEM & EMAIL' : 'SISTEM',
        'title': m['judul'],
        'message': m['isi'],
        'createdAt': _iso(m['dibuat_pada']),
        'isRead': m['sudah_dibaca'] ?? false,
      };
    }).toList(),
  };
}

Future<Map<String, dynamic>> _createBookingHold(
  Connection conn,
  Map<String, dynamic> body,
) async {
  return conn.runTx((s) async {
    final rawRoomId = body['roomId'] as String;
    final roomUuid = EstopaDatabase.ensureUuid(rawRoomId);
    final roomNumber = (body['roomNumber'] as String?) ?? '';

    final roomCheck = await s.execute(
      Sql.named('''
        SELECT id, status, nomor_kamar, harga_per_bulan
        FROM kamar
        WHERE id = @id::uuid OR nomor_kamar = @num
        FOR UPDATE
      '''),
      parameters: {'id': roomUuid, 'num': roomNumber},
    );
    if (roomCheck.isEmpty) {
      throw StateError('Kamar tidak ditemukan.');
    }
    final actualKamarId = roomCheck.first[0].toString();
    final status = roomCheck.first[1] as String;
    final actualRoomNumber = roomCheck.first[2] as String;
    final price = roomCheck.first[3] as int;

    if (status != 'tersedia') {
      throw StateError(
        'Kamar sedang ditahan atau sudah terisi oleh pemesan lain.',
      );
    }

    // Bersihkan sisa akun & pemesanan belum dibayar jika email/no_hp sama
    final staleAkun = await s.execute(
      Sql.named('''
        SELECT a.id, pg.kamar_id
        FROM akun a
        LEFT JOIN penghuni pg ON pg.akun_id = a.id
        WHERE (LOWER(a.email) = LOWER(@email) OR a.no_hp = @phone)
          AND (a.aktif = FALSE AND (pg.id IS NULL OR pg.status = 'menunggu_pembayaran'))
      '''),
      parameters: {'email': body['email'], 'phone': body['phone']},
    );
    for (final row in staleAkun) {
      final staleAkunId = row[0].toString();
      final staleKamarId = row[1]?.toString();
      if (staleKamarId != null) {
        await s.execute(
          Sql.named('''
            UPDATE kamar
            SET status = 'tersedia', ditahan_sampai = NULL
            WHERE id = @kid::uuid AND status = 'ditahan'
          '''),
          parameters: {'kid': staleKamarId},
        );
      }
      await s.execute(
        Sql.named('DELETE FROM akun WHERE id = @aid::uuid'),
        parameters: {'aid': staleAkunId},
      );
    }

    final existingAkun = await s.execute(
      Sql.named('''
        SELECT 1 FROM akun
        WHERE LOWER(email) = LOWER(@email) OR no_hp = @phone
        LIMIT 1
      '''),
      parameters: {'email': body['email'], 'phone': body['phone']},
    );
    if (existingAkun.isNotEmpty) {
      throw StateError(
        'Email atau No. HP sudah terdaftar pada akun lain. Silakan gunakan email dan No. HP berbeda.',
      );
    }

    final expiresAt = DateTime.parse(body['expiresAt'] as String).toUtc();
    final months = (body['months'] as int?) ?? 1;
    final total = (price * months) + (35000 * months) + 4000;
    final holdUuid = EstopaDatabase.ensureUuid(body['id'] as String);
    final akunUuid = EstopaDatabase.ensureUuid('AKUN-HOLD-${body['id']}');
    final penghuniUuid = EstopaDatabase.ensureUuid('PG-HOLD-${body['id']}');
    final payUuid = EstopaDatabase.ensureUuid('PAY-HOLD-${body['id']}');

    await s.execute(
      Sql.named('''
        UPDATE kamar
        SET status = 'ditahan', ditahan_sampai = @exp
        WHERE id = @kid::uuid
      '''),
      parameters: {'kid': actualKamarId, 'exp': expiresAt},
    );

    await s.execute(
      Sql.named('''
        INSERT INTO akun (id, email, no_hp, password_hash, aktif)
        VALUES (@id::uuid, @email, @phone, @pwd, FALSE)
      '''),
      parameters: {
        'id': akunUuid,
        'email': body['email'],
        'phone': body['phone'],
        'pwd': body['password'],
      },
    );

    await s.execute(
      Sql.named('''
        INSERT INTO peran_akun (id, akun_id, peran)
        VALUES (@id::uuid, @aid::uuid, 'penghuni')
        ON CONFLICT (akun_id, peran) DO NOTHING
      '''),
      parameters: {
        'id': EstopaDatabase.ensureUuid('ROLE-HOLD-${body['id']}'),
        'aid': akunUuid,
      },
    );

    await s.execute(
      Sql.named('''
        INSERT INTO penghuni (
          id, akun_id, kamar_id, riwayat_nomor_kamar, nama_lengkap, alamat_asal,
          nama_orang_tua, no_hp_orang_tua, nomor_ktp, url_ktp, ktp_data, persetujuan_ktp,
          periode_bayar_bulan, status
        ) VALUES (
          @id::uuid, @aid::uuid, @kid::uuid, @rnum, @name, @addr,
          @pname, @pphone, @ktp, @ktpFile, @ktpData, @consent,
          @months, 'menunggu_pembayaran'
        )
      '''),
      parameters: {
        'id': penghuniUuid,
        'aid': akunUuid,
        'kid': actualKamarId,
        'rnum': actualRoomNumber,
        'name': body['fullName'],
        'addr': body['originAddress'],
        'pname': body['parentName'],
        'pphone': body['parentPhone'],
        'ktp': body['ktpNumber'],
        'ktpFile': body['ktpFileName'],
        'ktpData': body['ktpImageBase64'],
        'consent': body['ktpConsent'] ?? true,
        'months': months,
      },
    );

    await s.execute(
      Sql.named('''
        INSERT INTO pemesanan (
          id, kamar_id, penghuni_id, durasi_bulan, jumlah, status, kedaluwarsa_pada
        ) VALUES (
          @id::uuid, @kid::uuid, @pid::uuid, @months, @total, 'menunggu', @exp
        )
      '''),
      parameters: {
        'id': holdUuid,
        'kid': actualKamarId,
        'pid': penghuniUuid,
        'months': months,
        'total': total,
        'exp': expiresAt,
      },
    );

    await s.execute(
      Sql.named('''
        INSERT INTO pembayaran (
          id, pemesanan_id, tagihan_id, penghuni_id,
          nama_penghuni_snapshot, nomor_kamar_snapshot,
          jenis_pembayaran, jumlah, id_order_gateway, qr_code_url, status
        ) VALUES (
          @id::uuid, @pmid::uuid, NULL, @pid::uuid,
          @name, @rnum, 'pemesanan_awal', @total, @ord, @qr, 'menunggu'
        )
      '''),
      parameters: {
        'id': payUuid,
        'pmid': holdUuid,
        'pid': penghuniUuid,
        'name': body['fullName'],
        'rnum': actualRoomNumber,
        'total': total,
        'ord': 'ORD-BOOK-${DateTime.now().microsecondsSinceEpoch}',
        'qr': body['qrPayload'] ?? 'QRIS-BOOKING-ESTOPA',
      },
    );

    return {'status': 'held', 'id': holdUuid};
  });
}

Future<void> _expireBookingHold(Connection conn, String rawHoldId) async {
  await conn.runTx((s) async {
    final holdUuid = EstopaDatabase.ensureUuid(rawHoldId);
    final res = await s.execute(
      Sql.named('''
        SELECT pm.id, pm.kamar_id, pm.status, pg.akun_id
        FROM pemesanan pm
        JOIN penghuni pg ON pg.id = pm.penghuni_id
        WHERE pm.id = @id::uuid
        FOR UPDATE
      '''),
      parameters: {'id': holdUuid},
    );
    if (res.isEmpty) return;
    final kamarId = res.first[1].toString();
    final status = res.first[2] as String;
    final akunId = res.first[3].toString();
    if (status == 'dibayar') return;

    await s.execute(
      Sql.named('''
        UPDATE kamar
        SET status = 'tersedia', ditahan_sampai = NULL
        WHERE id = @kid::uuid AND status = 'ditahan'
      '''),
      parameters: {'kid': kamarId},
    );
    await s.execute(
      Sql.named('DELETE FROM pemesanan WHERE id = @id::uuid'),
      parameters: {'id': holdUuid},
    );
    await s.execute(
      Sql.named('DELETE FROM akun WHERE id = @aid::uuid'),
      parameters: {'aid': akunId},
    );
  });
}

Future<Map<String, dynamic>> _completeBookingPayment(
  Connection conn,
  EstopaEmailService emailService,
  String rawHoldId, {
  String? plainPassword,
  bool skipEmail = false,
}) async {
  final holdUuid = EstopaDatabase.ensureUuid(rawHoldId);
  Map<String, dynamic>? emailPayload;

  final txResult = await conn.runTx((s) async {
    final webhookKey = 'BOOKING:$holdUuid';
    final dup = await s.execute(
      Sql.named(
        'INSERT INTO webhook_terproses (kunci_webhook) VALUES (@k) ON CONFLICT DO NOTHING RETURNING kunci_webhook',
      ),
      parameters: {'k': webhookKey},
    );
    if (dup.isEmpty) {
      return {'status': 'ignored_duplicate'};
    }

    final holdRes = await s.execute(
      Sql.named('''
        SELECT pm.*, k.nomor_kamar, k.harga_per_bulan,
               pg.id AS penghuni_id, pg.akun_id, pg.nama_lengkap,
               a.email, a.no_hp
        FROM pemesanan pm
        JOIN kamar k ON k.id = pm.kamar_id
        JOIN penghuni pg ON pg.id = pm.penghuni_id
        JOIN akun a ON a.id = pg.akun_id
        WHERE pm.id = @id::uuid
        FOR UPDATE
      '''),
      parameters: {'id': holdUuid},
    );
    if (holdRes.isEmpty) {
      throw StateError('Pemesanan tidak ditemukan atau sudah kedaluwarsa.');
    }
    final h = holdRes.first.toColumnMap();
    final now = DateTime.now().toUtc();
    final today = _dateOnly(now);
    final months = h['durasi_bulan'] as int;
    final price = h['harga_per_bulan'] as int;
    final roomCost = price * months;
    final waterCost = 35000 * months;
    const txFee = 4000;
    final total = roomCost + waterCost + txFee;
    final leaseEnd = _dateOnly(now.add(Duration(days: 30 * months)));
    final nextEnd = _dateOnly(leaseEnd.add(const Duration(days: 30)));
    final penghuniId = h['penghuni_id'].toString();
    final akunId = h['akun_id'].toString();
    final kamarId = h['kamar_id'].toString();
    final roomNumber = h['nomor_kamar'] as String;
    final fullName = h['nama_lengkap'] as String;

    emailPayload = {
      'fullName': fullName,
      'email': h['email'] as String,
      'phone': h['no_hp'] as String,
      'roomNumber': roomNumber,
      'months': months,
      'roomCost': roomCost,
      'waterCost': waterCost,
      'transactionFee': txFee,
      'totalAmount': total,
    };

    await s.execute(
      Sql.named('UPDATE akun SET aktif = TRUE WHERE id = @aid::uuid'),
      parameters: {'aid': akunId},
    );

    await s.execute(
      Sql.named('''
        UPDATE penghuni
        SET status = 'aktif', tanggal_masuk = @masuk, dibayar_sampai = @sampai,
            periode_bayar_bulan = @months
        WHERE id = @pid::uuid
      '''),
      parameters: {
        'pid': penghuniId,
        'masuk': today,
        'sampai': leaseEnd,
        'months': months,
      },
    );

    await s.execute(
      Sql.named('''
        UPDATE kamar
        SET status = 'terisi', ditahan_sampai = NULL
        WHERE id = @kid::uuid
      '''),
      parameters: {'kid': kamarId},
    );

    await s.execute(
      Sql.named('''
        UPDATE pemesanan
        SET status = 'dibayar', dibayar_pada = @now
        WHERE id = @pmid::uuid
      '''),
      parameters: {'pmid': holdUuid, 'now': now},
    );

    await s.execute(
      Sql.named('''
        UPDATE pembayaran
        SET status = 'berhasil', dibayar_pada = @now
        WHERE pemesanan_id = @pmid::uuid
      '''),
      parameters: {'pmid': holdUuid, 'now': now},
    );

    // Jadwalkan tagihan periode berikutnya di akhir masa sewa
    await s.execute(
      Sql.named('''
        INSERT INTO tagihan (
          id, penghuni_id, nama_penghuni_snapshot, nomor_kamar_snapshot,
          periode_bulan, periode_mulai, periode_selesai, jatuh_tempo,
          biaya_kamar, biaya_air, biaya_admin, denda, jumlah_hari_terlambat,
          total_tagihan, status
        ) VALUES (
          @id::uuid, @pid::uuid, @name, @rnum,
          1, @mulai, @selesai, @tempo,
          @bKamar, 35000, 4000, 0, 0,
          @totalTagihan, 'belum_dibayar'
        )
        ON CONFLICT (penghuni_id, periode_mulai) DO NOTHING
      '''),
      parameters: {
        'id': EstopaDatabase.ensureUuid(
          'INV-${now.microsecondsSinceEpoch}',
        ),
        'pid': penghuniId,
        'name': fullName,
        'rnum': roomNumber,
        'mulai': leaseEnd,
        'selesai': nextEnd,
        'tempo': leaseEnd,
        'bKamar': price,
        'totalTagihan': price + 35000 + 4000,
      },
    );

    await s.execute(
      Sql.named('''
        INSERT INTO notifikasi (id, akun_id, judul, isi, tipe, kirim_email)
        VALUES
          (@n1::uuid, @aid::uuid, 'Pembayaran Berhasil & Akun Estopa Kos Aktif', @m1, 'pembayaran', TRUE),
          (@n2::uuid, @adm::uuid, @t2, @m2, 'pembayaran', TRUE)
      '''),
      parameters: {
        'n1': EstopaDatabase.ensureUuid('NTF-EML-${now.microsecondsSinceEpoch}'),
        'aid': akunId,
        'm1':
            'Selamat datang di Estopa Kos! Pembayaran Kamar $roomNumber telah lunas. Akun Anda aktif.',
        'n2': EstopaDatabase.ensureUuid('NTF-ADM-${now.microsecondsSinceEpoch}'),
        'adm': EstopaDatabase.adminAkunUuid,
        't2': 'Dana Masuk Pemesanan Kamar Baru (Kamar $roomNumber)',
        'm2':
            '$fullName telah memesan dan melunasi Kamar $roomNumber ($months bulan).',
      },
    );

    return {'status': 'paid', 'tenantId': penghuniId};
  });

  if (!skipEmail && emailPayload != null) {
    final delivery = await emailService.sendWelcomeBookingEmail(
      fullName: emailPayload!['fullName'] as String,
      email: emailPayload!['email'] as String,
      phone: emailPayload!['phone'] as String,
      roomNumber: emailPayload!['roomNumber'] as String,
      months: emailPayload!['months'] as int,
      roomCost: emailPayload!['roomCost'] as int,
      waterCost: emailPayload!['waterCost'] as int,
      transactionFee: emailPayload!['transactionFee'] as int,
      totalAmount: emailPayload!['totalAmount'] as int,
      plainPassword: plainPassword,
    );
    return {
      ...txResult,
      'emailDelivery': delivery.toJson(),
    };
  }
  return txResult;
}

Future<Map<String, dynamic>?> _findOpenInvoiceForAction(
  TxSession s,
  String rawInvoiceId, {
  String? roomNumber,
}) async {
  final invUuid = EstopaDatabase.ensureUuid(rawInvoiceId);
  final byId = await s.execute(
    Sql.named('''
      SELECT t.*, pg.akun_id
      FROM tagihan t
      JOIN penghuni pg ON pg.id = t.penghuni_id
      WHERE t.id = @id::uuid
      FOR UPDATE OF t
    '''),
    parameters: {'id': invUuid},
  );
  if (byId.isNotEmpty) {
    return byId.first.toColumnMap();
  }
  if (roomNumber != null && roomNumber.trim().isNotEmpty) {
    final byRoom = await s.execute(
      Sql.named('''
        SELECT t.*, pg.akun_id
        FROM tagihan t
        JOIN penghuni pg ON pg.id = t.penghuni_id
        WHERE t.nomor_kamar_snapshot = @rnum
          AND t.status <> 'lunas'
        ORDER BY t.dibuat_pada DESC
        LIMIT 1
        FOR UPDATE OF t
      '''),
      parameters: {'rnum': roomNumber.trim()},
    );
    if (byRoom.isNotEmpty) {
      return byRoom.first.toColumnMap();
    }
  }
  return null;
}

Future<void> _updateInvoiceMonths(
  Connection conn,
  String rawInvoiceId,
  int months, {
  String? roomNumber,
}) async {
  await conn.runTx((s) async {
    final m = await _findOpenInvoiceForAction(
      s,
      rawInvoiceId,
      roomNumber: roomNumber,
    );
    if (m == null) return;
    final invUuid = m['id'].toString();
    final oldMonths = (m['periode_bulan'] as int?) ?? 1;
    final oldRoomCost = (m['biaya_kamar'] as int?) ?? 0;
    final pricePerMonth =
        oldMonths > 0 ? (oldRoomCost ~/ oldMonths) : oldRoomCost;
    final newRoomCost = pricePerMonth * months;
    final newWater = 35000 * months;
    final adminFee = (m['biaya_admin'] as int?) ?? 4000;
    final denda = (m['denda'] as int?) ?? 0;
    final newTotal = newRoomCost + newWater + adminFee + denda;
    final mulai = m['periode_mulai'] as DateTime;
    final selesai = _dateOnly(mulai.add(Duration(days: 30 * months)));

    await s.execute(
      Sql.named('''
        UPDATE tagihan
        SET periode_bulan = @m, periode_selesai = @selesai,
            biaya_kamar = @bk, biaya_air = @ba, total_tagihan = @tot
        WHERE id = @id::uuid
      '''),
      parameters: {
        'id': invUuid,
        'm': months,
        'selesai': selesai,
        'bk': newRoomCost,
        'ba': newWater,
        'tot': newTotal,
      },
    );
  });
}

Future<void> _generateInvoiceQr(
  Connection conn, {
  required String invoiceId,
  required String qrCode,
  required DateTime expiresAt,
  String? roomNumber,
}) async {
  await conn.runTx((s) async {
    final inv = await _findOpenInvoiceForAction(
      s,
      invoiceId,
      roomNumber: roomNumber,
    );
    if (inv == null) return;
    final invUuid = inv['id'].toString();

    await s.execute(
      Sql.named(
        'UPDATE tagihan SET qr_kedaluwarsa_pada = @exp WHERE id = @id::uuid',
      ),
      parameters: {'id': invUuid, 'exp': expiresAt},
    );

    await s.execute(
      Sql.named('''
        DELETE FROM pembayaran
        WHERE tagihan_id = @id::uuid AND status = 'menunggu'
      '''),
      parameters: {'id': invUuid},
    );

    await s.execute(
      Sql.named('''
        INSERT INTO pembayaran (
          id, pemesanan_id, tagihan_id, penghuni_id,
          nama_penghuni_snapshot, nomor_kamar_snapshot,
          jenis_pembayaran, jumlah, id_order_gateway, qr_code_url, status
        ) VALUES (
          @id::uuid, NULL, @tid::uuid, @pid::uuid,
          @name, @rnum, 'tagihan_rutin', @tot, @ord, @qr, 'menunggu'
        )
      '''),
      parameters: {
        'id': EstopaDatabase.ensureUuid(
          'PAY-WAIT-${DateTime.now().microsecondsSinceEpoch}',
        ),
        'tid': invUuid,
        'pid': inv['penghuni_id'].toString(),
        'name': inv['nama_penghuni_snapshot'],
        'rnum': inv['nomor_kamar_snapshot'],
        'tot': inv['total_tagihan'],
        'ord': 'ORD-INV-${DateTime.now().microsecondsSinceEpoch}',
        'qr': qrCode,
      },
    );
  });
}

Future<void> _simulateLateDay(
  Connection conn,
  String rawInvoiceId, {
  String? roomNumber,
}) async {
  await conn.runTx((s) async {
    final inv = await _findOpenInvoiceForAction(
      s,
      rawInvoiceId,
      roomNumber: roomNumber,
    );
    if (inv == null) return;
    final invUuid = inv['id'].toString();
    if (inv['status'] == 'lunas') return;

    final newLateDays = ((inv['jumlah_hari_terlambat'] as int?) ?? 0) + 1;
    final newDenda = newLateDays * 50000;
    final biayaKamar = inv['biaya_kamar'] as int;
    final biayaAir = inv['biaya_air'] as int;
    final biayaAdmin = inv['biaya_admin'] as int;
    final newTotal = biayaKamar + biayaAir + biayaAdmin + newDenda;
    final newDue =
        _dateOnly(DateTime.now().toUtc().subtract(Duration(days: newLateDays)));

    await s.execute(
      Sql.named('''
        UPDATE tagihan
        SET status = 'terlambat', jumlah_hari_terlambat = @ld,
            denda = @denda, total_tagihan = @tot,
            jatuh_tempo = @due, qr_kedaluwarsa_pada = NULL
        WHERE id = @id::uuid
      '''),
      parameters: {
        'id': invUuid,
        'ld': newLateDays,
        'denda': newDenda,
        'tot': newTotal,
        'due': newDue,
      },
    );

    await s.execute(
      Sql.named('''
        DELETE FROM pembayaran
        WHERE tagihan_id = @id::uuid AND status = 'menunggu'
      '''),
      parameters: {'id': invUuid},
    );

    await s.execute(
      Sql.named('''
        INSERT INTO notifikasi (id, akun_id, judul, isi, tipe, kirim_email)
        VALUES (@id::uuid, @aid::uuid, @title, @msg, 'tagihan', TRUE)
      '''),
      parameters: {
        'id': EstopaDatabase.ensureUuid(
          'NTF-LATE-${DateTime.now().microsecondsSinceEpoch}',
        ),
        'aid': inv['akun_id'].toString(),
        'title':
            'Peringatan Keterlambatan Hari ke-$newLateDays (+Rp50.000/hari)',
        'msg':
            'Tagihan Kamar ${inv['nomor_kamar_snapshot']} terlambat $newLateDays hari. Denda Rp$newDenda.',
      },
    );
  });
}

Future<void> _payInvoice(
  Connection conn,
  String rawInvoiceId, {
  String? roomNumber,
}) async {
  await conn.runTx((s) async {
    final inv = await _findOpenInvoiceForAction(
      s,
      rawInvoiceId,
      roomNumber: roomNumber,
    );
    if (inv == null) return;
    final invUuid = inv['id'].toString();
    final webhookKey = 'INVOICE:$invUuid';
    final dup = await s.execute(
      Sql.named(
        'INSERT INTO webhook_terproses (kunci_webhook) VALUES (@k) ON CONFLICT DO NOTHING RETURNING kunci_webhook',
      ),
      parameters: {'k': webhookKey},
    );
    if (dup.isEmpty) return;
    if (inv['status'] == 'lunas') return;

    final now = DateTime.now().toUtc();
    final months = inv['periode_bulan'] as int;
    final biayaKamar = inv['biaya_kamar'] as int;
    final pricePerMonth = months > 0 ? (biayaKamar ~/ months) : biayaKamar;
    final total = inv['total_tagihan'] as int;
    final penghuniId = inv['penghuni_id'].toString();

    await s.execute(
      Sql.named('''
        UPDATE tagihan
        SET status = 'lunas', dibayar_pada = @now, qr_kedaluwarsa_pada = NULL
        WHERE id = @id::uuid
      '''),
      parameters: {'id': invUuid, 'now': now},
    );

    final existingWait = await s.execute(
      Sql.named('''
        UPDATE pembayaran
        SET status = 'berhasil', jumlah = @tot, dibayar_pada = @now
        WHERE tagihan_id = @id::uuid AND status = 'menunggu'
        RETURNING id
      '''),
      parameters: {'id': invUuid, 'tot': total, 'now': now},
    );

    if (existingWait.isEmpty) {
      await s.execute(
        Sql.named('''
          INSERT INTO pembayaran (
            id, pemesanan_id, tagihan_id, penghuni_id,
            nama_penghuni_snapshot, nomor_kamar_snapshot,
            jenis_pembayaran, jumlah, id_order_gateway, qr_code_url, status, dibayar_pada
          ) VALUES (
            @id::uuid, NULL, @tid::uuid, @pid::uuid,
            @name, @rnum, 'tagihan_rutin', @tot, @ord, 'QRIS-INV-PAID', 'berhasil', @now
          )
        '''),
        parameters: {
          'id': EstopaDatabase.ensureUuid(
            'PAY-${now.microsecondsSinceEpoch}',
          ),
          'tid': invUuid,
          'pid': penghuniId,
          'name': inv['nama_penghuni_snapshot'],
          'rnum': inv['nomor_kamar_snapshot'],
          'tot': total,
          'ord': 'GW-QRIS-${now.microsecondsSinceEpoch.toString().substring(7)}',
          'now': now,
        },
      );
    }

    final oldSelesai = inv['periode_selesai'] as DateTime;
    final nextMulai = _dateOnly(oldSelesai);
    final nextSelesai = _dateOnly(nextMulai.add(const Duration(days: 30)));

    await s.execute(
      Sql.named('''
        UPDATE penghuni SET dibayar_sampai = @next WHERE id = @pid::uuid
      '''),
      parameters: {'next': nextMulai, 'pid': penghuniId},
    );

    await s.execute(
      Sql.named('''
        INSERT INTO tagihan (
          id, penghuni_id, nama_penghuni_snapshot, nomor_kamar_snapshot,
          periode_bulan, periode_mulai, periode_selesai, jatuh_tempo,
          biaya_kamar, biaya_air, biaya_admin, denda, jumlah_hari_terlambat,
          total_tagihan, status
        ) VALUES (
          @id::uuid, @pid::uuid, @name, @rnum,
          1, @mulai, @selesai, @tempo,
          @bk, 35000, 4000, 0, 0,
          @tot, 'belum_dibayar'
        )
        ON CONFLICT (penghuni_id, periode_mulai) DO NOTHING
      '''),
      parameters: {
        'id': EstopaDatabase.ensureUuid(
          'INV-NEXT-${now.microsecondsSinceEpoch}',
        ),
        'pid': penghuniId,
        'name': inv['nama_penghuni_snapshot'],
        'rnum': inv['nomor_kamar_snapshot'],
        'mulai': nextMulai,
        'selesai': nextSelesai,
        'tempo': nextMulai,
        'bk': pricePerMonth,
        'tot': pricePerMonth + 35000 + 4000,
      },
    );
  });
}

Future<int> _triggerReminders(Connection conn) async {
  int sent = 0;
  final res = await conn.execute('''
    SELECT t.*, pg.akun_id
    FROM tagihan t
    JOIN penghuni pg ON pg.id = t.penghuni_id
    WHERE t.status IN ('belum_dibayar', 'terlambat')
  ''');
  for (final r in res) {
    final inv = r.toColumnMap();
    final reminders = _decodeStringList(inv['pengingat_terkirim']);
    final label = inv['status'] == 'terlambat'
        ? 'Denda Hari ke-${inv['jumlah_hari_terlambat']}'
        : 'Pengingat H-1';
    if (!reminders.contains(label)) {
      reminders.add(label);
      sent++;
      await conn.execute(
        Sql.named(
          'UPDATE tagihan SET pengingat_terkirim = @rem::jsonb WHERE id = @id::uuid',
        ),
        parameters: {
          'id': inv['id'].toString(),
          'rem': jsonEncode(reminders),
        },
      );
      await conn.execute(
        Sql.named('''
          INSERT INTO notifikasi (id, akun_id, judul, isi, tipe, kirim_email)
          VALUES (@id::uuid, @aid::uuid, @title, @msg, 'tagihan', TRUE)
        '''),
        parameters: {
          'id': EstopaDatabase.ensureUuid(
            'NTF-REM-${DateTime.now().microsecondsSinceEpoch}-$sent',
          ),
          'aid': inv['akun_id'].toString(),
          'title': 'Pengingat Tagihan Otomatis ($label)',
          'msg':
              'Halo ${inv['nama_penghuni_snapshot']}, mohon segera menyelesaikan tagihan Kamar ${inv['nomor_kamar_snapshot']}.',
        },
      );
    }
  }
  return sent;
}

Future<void> _vacateRoom(Connection conn, String rawRoomId) async {
  final roomUuid = EstopaDatabase.ensureUuid(rawRoomId);
  await conn.runTx((s) async {
    final res = await s.execute(
      Sql.named('''
        SELECT k.id, k.nomor_kamar, pg.id AS penghuni_id, pg.akun_id
        FROM kamar k
        LEFT JOIN penghuni pg ON pg.kamar_id = k.id AND pg.status = 'aktif'
        WHERE k.id = @id::uuid
        FOR UPDATE OF k
      '''),
      parameters: {'id': roomUuid},
    );
    if (res.isEmpty) return;
    final kamarId = res.first[0].toString();
    final roomNum = res.first[1] as String;
    final penghuniId = res.first[2]?.toString();
    final akunId = res.first[3]?.toString();
    final today = _dateOnly(DateTime.now().toUtc());

    if (penghuniId != null && akunId != null) {
      await s.execute(
        Sql.named('UPDATE akun SET aktif = FALSE WHERE id = @aid::uuid'),
        parameters: {'aid': akunId},
      );
      await s.execute(
        Sql.named('''
          UPDATE penghuni
          SET status = 'nonaktif', kamar_id = NULL,
              riwayat_nomor_kamar = @snap, tanggal_keluar = @keluar
          WHERE id = @pid::uuid
        '''),
        parameters: {
          'pid': penghuniId,
          'snap': '$roomNum (Sudah Keluar)',
          'keluar': today,
        },
      );
      await s.execute(
        Sql.named('''
          DELETE FROM tagihan
          WHERE penghuni_id = @pid::uuid AND status <> 'lunas'
        '''),
        parameters: {'pid': penghuniId},
      );
    }

    await s.execute(
      Sql.named('''
        UPDATE kamar
        SET status = 'tersedia', ditahan_sampai = NULL
        WHERE id = @kid::uuid
      '''),
      parameters: {'kid': kamarId},
    );
  });
}

Future<void> _addTenantByAdmin(
  Connection conn,
  Map<String, dynamic> body,
) async {
  await conn.runTx((s) async {
    final now = DateTime.now().toUtc();
    final today = _dateOnly(now);
    final leaseEnd = _dateOnly(DateTime.parse(body['leaseEndDate'] as String));
    final nextEnd = _dateOnly(leaseEnd.add(const Duration(days: 30)));
    final penghuniUuid = EstopaDatabase.ensureUuid(body['id'] as String);
    final akunUuid = EstopaDatabase.ensureUuid('AKUN-${body['id']}');
    final roomUuid = EstopaDatabase.ensureUuid(body['roomId'] as String);
    final months = (body['months'] as int?) ?? 1;
    final price = (body['roomPricePerMonth'] as int?) ?? 950000;

    await s.execute(
      Sql.named('''
        INSERT INTO akun (id, email, no_hp, password_hash, aktif)
        VALUES (@id::uuid, @email, @phone, @pwd, TRUE)
      '''),
      parameters: {
        'id': akunUuid,
        'email': body['email'],
        'phone': body['phone'],
        'pwd': body['passwordHash'],
      },
    );

    await s.execute(
      Sql.named('''
        INSERT INTO peran_akun (id, akun_id, peran)
        VALUES (@id::uuid, @aid::uuid, 'penghuni')
        ON CONFLICT (akun_id, peran) DO NOTHING
      '''),
      parameters: {
        'id': EstopaDatabase.ensureUuid('ROLE-${body['id']}'),
        'aid': akunUuid,
      },
    );

    await s.execute(
      Sql.named('''
        INSERT INTO penghuni (
          id, akun_id, kamar_id, riwayat_nomor_kamar, nama_lengkap, alamat_asal,
          nama_orang_tua, no_hp_orang_tua, nomor_ktp, url_ktp, ktp_data, persetujuan_ktp,
          tanggal_masuk, periode_bayar_bulan, dibayar_sampai, status
        ) VALUES (
          @id::uuid, @aid::uuid, @kid::uuid, @rnum, @name, @addr,
          @pname, @pphone, @ktp, @ktpFile, @ktpData, TRUE,
          @masuk, @months, @sampai, 'aktif'
        )
      '''),
      parameters: {
        'id': penghuniUuid,
        'aid': akunUuid,
        'kid': roomUuid,
        'rnum': body['roomNumber'],
        'name': body['fullName'],
        'addr': body['originAddress'],
        'pname': body['parentName'],
        'pphone': body['parentPhone'],
        'ktp': body['ktpNumber'],
        'ktpFile': body['ktpFileName'],
        'ktpData': body['ktpImageBase64'],
        'masuk': today,
        'months': months,
        'sampai': leaseEnd,
      },
    );

    await s.execute(
      Sql.named('''
        UPDATE kamar
        SET status = 'terisi', ditahan_sampai = NULL
        WHERE id = @kid::uuid
      '''),
      parameters: {'kid': roomUuid},
    );

    await s.execute(
      Sql.named('''
        INSERT INTO tagihan (
          id, penghuni_id, nama_penghuni_snapshot, nomor_kamar_snapshot,
          periode_bulan, periode_mulai, periode_selesai, jatuh_tempo,
          biaya_kamar, biaya_air, biaya_admin, denda, jumlah_hari_terlambat,
          total_tagihan, status
        ) VALUES (
          @id::uuid, @pid::uuid, @name, @rnum,
          @months, @mulai, @selesai, @tempo,
          @bk, @ba, 4000, 0, 0,
          @tot, 'belum_dibayar'
        )
        ON CONFLICT (penghuni_id, periode_mulai) DO NOTHING
      '''),
      parameters: {
        'id': EstopaDatabase.ensureUuid(
          'INV-ADM-${now.microsecondsSinceEpoch}',
        ),
        'pid': penghuniUuid,
        'name': body['fullName'],
        'rnum': body['roomNumber'],
        'months': months,
        'mulai': leaseEnd,
        'selesai': nextEnd,
        'tempo': leaseEnd,
        'bk': price * months,
        'ba': 35000 * months,
        'tot': (price * months) + (35000 * months) + 4000,
      },
    );
  });
}

Future<void> _updateTenantByAdmin(
  Connection conn,
  Map<String, dynamic> body,
) async {
  final penghuniUuid = EstopaDatabase.ensureUuid(body['id'] as String);
  await conn.runTx((s) async {
    final res = await s.execute(
      Sql.named('SELECT akun_id FROM penghuni WHERE id = @id::uuid'),
      parameters: {'id': penghuniUuid},
    );
    if (res.isEmpty) return;
    final akunId = res.first[0].toString();

    await s.execute(
      Sql.named('''
        UPDATE akun
        SET email = @email, no_hp = @phone
        WHERE id = @aid::uuid
      '''),
      parameters: {
        'aid': akunId,
        'email': body['email'],
        'phone': body['phone'],
      },
    );

    await s.execute(
      Sql.named('''
        UPDATE penghuni
        SET nama_lengkap = @name, alamat_asal = @addr,
            nama_orang_tua = @pname, no_hp_orang_tua = @pphone,
            nomor_ktp = @ktp
        WHERE id = @pid::uuid
      '''),
      parameters: {
        'pid': penghuniUuid,
        'name': body['fullName'],
        'addr': body['originAddress'],
        'pname': body['parentName'],
        'pphone': body['parentPhone'],
        'ktp': body['ktpNumber'],
      },
    );
  });
}

Future<void> _resetTenantPassword(
  Connection conn, {
  required String tenantId,
  required String passwordHash,
}) async {
  final penghuniUuid = EstopaDatabase.ensureUuid(tenantId);
  await conn.runTx((s) async {
    final res = await s.execute(
      Sql.named('''
        SELECT a.id, a.email
        FROM penghuni pg
        JOIN akun a ON a.id = pg.akun_id
        WHERE pg.id = @pid::uuid
      '''),
      parameters: {'pid': penghuniUuid},
    );
    if (res.isEmpty) return;
    final akunId = res.first[0].toString();
    final email = res.first[1] as String;

    await s.execute(
      Sql.named(
        'UPDATE akun SET password_hash = @pwd WHERE id = @aid::uuid',
      ),
      parameters: {'aid': akunId, 'pwd': passwordHash},
    );

    await s.execute(
      Sql.named('''
        INSERT INTO riwayat_reset_sandi (id, akun_id, email_akun_snapshot, direset_oleh)
        VALUES (@id::uuid, @aid::uuid, @email, @adm::uuid)
      '''),
      parameters: {
        'id': EstopaDatabase.ensureUuid(
          'RST-${DateTime.now().microsecondsSinceEpoch}',
        ),
        'aid': akunId,
        'email': email,
        'adm': EstopaDatabase.adminAkunUuid,
      },
    );

    await s.execute(
      Sql.named('''
        INSERT INTO notifikasi (id, akun_id, judul, isi, tipe, kirim_email)
        VALUES (@id::uuid, @aid::uuid, 'Kata Sandi Direset oleh Admin',
          'Kata sandi akun Estopa Kos Anda telah direset oleh Admin sesuai permintaan.',
          'sistem', TRUE)
      '''),
      parameters: {
        'id': EstopaDatabase.ensureUuid(
          'NTF-PWD-${DateTime.now().microsecondsSinceEpoch}',
        ),
        'aid': akunId,
      },
    );
  });
}

Future<void> _createComplaint(
  Connection conn,
  Map<String, dynamic> body,
) async {
  final penghuniUuid = EstopaDatabase.ensureUuid(body['tenantId'] as String);
  await conn.runTx((s) async {
    final pgRes = await s.execute(
      Sql.named('SELECT kamar_id FROM penghuni WHERE id = @pid::uuid'),
      parameters: {'pid': penghuniUuid},
    );
    final kamarId = pgRes.isNotEmpty ? pgRes.first[0]?.toString() : null;

    await s.execute(
      Sql.named('''
        INSERT INTO keluhan (
          id, penghuni_id, kamar_id, kategori, deskripsi, url_foto, status, dibuat_pada
        ) VALUES (
          @id::uuid, @pid::uuid, @kid::uuid, @cat, @desc, @att, 'diajukan', @dt
        )
      '''),
      parameters: {
        'id': EstopaDatabase.ensureUuid(body['id'] as String),
        'pid': penghuniUuid,
        'kid': kamarId,
        'cat': body['category'],
        'desc': body['description'],
        'att': body['attachmentName'],
        'dt': DateTime.parse(body['createdAt'] as String).toUtc(),
      },
    );

    await s.execute(
      Sql.named('''
        INSERT INTO notifikasi (id, akun_id, judul, isi, tipe, kirim_email)
        VALUES (@id::uuid, @adm::uuid, @title, @msg, 'keluhan', TRUE)
      '''),
      parameters: {
        'id': EstopaDatabase.ensureUuid(
          'NTF-CMP-${DateTime.now().microsecondsSinceEpoch}',
        ),
        'adm': EstopaDatabase.adminAkunUuid,
        'title':
            'Keluhan Baru Kamar ${body['roomNumber']} (${body['category']})',
        'msg': '${body['tenantName']}: ${body['description']}',
      },
    );
  });
}

Future<void> _updateComplaintStatus(
  Connection conn,
  Map<String, dynamic> body,
) async {
  final cmpUuid = EstopaDatabase.ensureUuid(body['complaintId'] as String);
  final appSt = body['status'] as String;
  final dbSt = appSt == 'resolved'
      ? 'selesai'
      : (appSt == 'inProgress' ? 'diproses' : 'diajukan');

  await conn.runTx((s) async {
    await s.execute(
      Sql.named('''
        UPDATE keluhan
        SET status = @st,
            catatan_admin = COALESCE(@note, catatan_admin),
            diselesaikan_pada = CASE WHEN @st = 'selesai' THEN NOW() ELSE diselesaikan_pada END
        WHERE id = @id::uuid
      '''),
      parameters: {
        'id': cmpUuid,
        'st': dbSt,
        'note': body['adminNote'],
      },
    );

    if (body['tenantId'] != null) {
      final penghuniUuid =
          EstopaDatabase.ensureUuid(body['tenantId'] as String);
      final akRes = await s.execute(
        Sql.named('SELECT akun_id FROM penghuni WHERE id = @pid::uuid'),
        parameters: {'pid': penghuniUuid},
      );
      if (akRes.isNotEmpty) {
        await s.execute(
          Sql.named('''
            INSERT INTO notifikasi (id, akun_id, judul, isi, tipe, kirim_email)
            VALUES (@id::uuid, @aid::uuid, @title, @msg, 'keluhan', TRUE)
          '''),
          parameters: {
            'id': EstopaDatabase.ensureUuid(
              'NTF-CMPU-${DateTime.now().microsecondsSinceEpoch}',
            ),
            'aid': akRes.first[0].toString(),
            'title': 'Update Status Keluhan (${body['category'] ?? ''})',
            'msg': body['message'] ?? 'Status keluhan telah diperbarui.',
          },
        );
      }
    }
  });
}

Future<void> _createAnnouncement(
  Connection conn,
  Map<String, dynamic> body,
) async {
  final createdAt = DateTime.parse(body['createdAt'] as String).toUtc();
  await conn.runTx((s) async {
    await s.execute(
      Sql.named('''
        INSERT INTO pengumuman (id, judul, isi, tanggal_pengumuman, dibuat_oleh, dibuat_pada)
        VALUES (@id::uuid, @title, @content, @tgl, @adm::uuid, @dt)
      '''),
      parameters: {
        'id': EstopaDatabase.ensureUuid(body['id'] as String),
        'title': body['title'],
        'content': body['content'],
        'tgl': _dateOnly(createdAt),
        'adm': EstopaDatabase.adminAkunUuid,
        'dt': createdAt,
      },
    );

    final activeAkuns = await s.execute('''
      SELECT a.id FROM akun a
      JOIN penghuni pg ON pg.akun_id = a.id
      WHERE pg.status = 'aktif'
    ''');
    for (var i = 0; i < activeAkuns.length; i++) {
      await s.execute(
        Sql.named('''
          INSERT INTO notifikasi (id, akun_id, judul, isi, tipe, kirim_email)
          VALUES (@id::uuid, @aid::uuid, @title, @msg, 'pengumuman', TRUE)
        '''),
        parameters: {
          'id': EstopaDatabase.ensureUuid(
            'NTF-ANN-${DateTime.now().microsecondsSinceEpoch}-$i',
          ),
          'aid': activeAkuns[i][0].toString(),
          'title': 'Pengumuman Baru: ${body['title']}',
          'msg': body['content'],
        },
      );
    }
  });
}
