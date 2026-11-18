import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cntohaplikasi/main.dart';
import 'package:cntohaplikasi/models/models.dart';
import 'package:cntohaplikasi/screens/admin_dashboard_screen.dart';
import 'package:cntohaplikasi/screens/tenant_dashboard_screen.dart';
import 'package:cntohaplikasi/state/estopa_store.dart';
import 'package:cntohaplikasi/utils/security.dart';

void main() {
  group('Estopa Kos PRD Unit & Edge-Case Tests (B-20)', () {
    test('FR-02 & FR-04: Rumus total tagihan & denda keterlambatan akurat', () {
      // Total = harga kamar x bulan + Rp35.000 x bulan + Rp4.000 per transaksi
      final normalTotal = CostConstants.calculateTotal(
        roomPricePerMonth: 1250000,
        months: 3,
      );
      expect(normalTotal, (1250000 * 3) + (35000 * 3) + 4000);

      // Dengan denda keterlambatan 3 hari (3 x Rp50.000 = Rp150.000)
      final overdueTotal = CostConstants.calculateTotal(
        roomPricePerMonth: 1250000,
        months: 1,
        lateDays: 3,
      );
      expect(overdueTotal, 1250000 + 35000 + 4000 + (50000 * 3));
    });

    test('NFR-02: Password disimpan dalam bentuk ter-hash dan terverifikasi', () {
      final hash = PasswordSecurity.hashPassword('rahasia123');
      expect(hash, isNot('rahasia123'));
      expect(hash.startsWith('sha256\$'), isTrue);
      expect(PasswordSecurity.verifyPassword('rahasia123', hash), isTrue);
      expect(PasswordSecurity.verifyPassword('salah', hash), isFalse);
    });

    test('FR-12 s.d. FR-16 + Uji Kasus Batas: Tahan 20m, Pemesanan Ganda, Webhook Ganda', () {
      final store = EstopaStore();
      expect(store.rooms.length, 39);

      final targetRoom = store.availableRooms.first;
      final hold = store.createBookingHold(
        room: targetRoom,
        months: 1,
        fullName: 'Budi Pratama',
        phone: '081234567890',
        email: 'budi@polmed.ac.id',
        originAddress: 'Medan',
        parentName: 'Ayah Budi',
        parentPhone: '081299998888',
        password: 'password123',
        ktpNumber: '1271010101010001',
        ktpFileName: 'ktp_budi.jpg',
        ktpConsent: true,
      );

      // Kamar ditahan (held)
      expect(targetRoom.status, RoomStatus.held);

      // Kasus Batas 1: Pemesanan ganda pada kamar yang sedang ditahan harus ditolak
      expect(
        () => store.createBookingHold(
          room: targetRoom,
          months: 1,
          fullName: 'Pemesan Kedua',
          phone: '081200000000',
          email: 'kedua@polmed.ac.id',
          originAddress: 'Medan',
          parentName: 'Ortu',
          parentPhone: '081211111111',
          password: 'password123',
          ktpNumber: '1271000000000000',
          ktpFileName: 'ktp2.jpg',
          ktpConsent: true,
        ),
        throwsStateError,
      );

      // Kasus Batas 2: Jika kedaluwarsa (FR-15): kamar kembali kosong & data sementara dihapus
      store.expireBookingHold(hold.id);
      expect(targetRoom.status, RoomStatus.available);
      expect(store.bookingHolds.where((h) => h.id == hold.id), isEmpty);

      // Buat pemesanan baru lalu selesaikan pembayaran (FR-16)
      final hold2 = store.createBookingHold(
        room: targetRoom,
        months: 3,
        fullName: 'Siti Rahma',
        phone: '081234560000',
        email: 'siti@polmed.ac.id',
        originAddress: 'Binjai',
        parentName: 'Ayah Siti',
        parentPhone: '081277776666',
        password: 'sitiPassword',
        ktpNumber: '1271020202020002',
        ktpFileName: 'ktp_siti.jpg',
        ktpConsent: true,
      );
      final paymentsCountBefore = store.payments.length;
      final newTenant = store.completeBookingPayment(hold2.id);

      // Kasus Batas 3: Webhook ganda tidak boleh mencatat pembayaran dua kali
      store.completeBookingPayment(hold2.id);
      expect(store.payments.length, paymentsCountBefore + 1);

      expect(targetRoom.status, RoomStatus.occupied);
      expect(newTenant.isActive, isTrue);

      // Akun otomatis bisa login dengan email maupun nomor HP (FR-29)
      final loginRes = store.login('siti@polmed.ac.id', 'sitiPassword');
      expect(loginRes.success, isTrue);
      expect(loginRes.role, UserRole.tenant);
    });

    test('FR-21 & NFR-07: Kosongkan kamar menonaktifkan akun tapi menjaga riwayat', () {
      final store = EstopaStore();
      final paymentsBefore = store.payments.length;

      // Kosongkan Kamar 2 milik Nadia
      store.vacateRoom('RM-2');

      final loginAttempt = store.login(
        'nadia@gmail.com',
        'password123',
      );
      expect(loginAttempt.success, isFalse);
      // Riwayat pembayaran tetap utuh (NFR-07)
      expect(store.payments.length, paymentsBefore);
    });

    test('FR-23 s.d. FR-28: Alur keluhan dan status baca pengumuman berjalan', () {
      final store = EstopaStore();
      final tenant = store.tenants.firstWhere((t) => t.isActive);

      store.createComplaint(
        tenant: tenant,
        category: 'Listrik / Lampu',
        description: 'Saklar lampu kamar agak longgar',
      );
      final latestComplaint = store.complaints.first;
      expect(latestComplaint.status, ComplaintStatus.submitted);

      store.updateComplaintStatus(
        complaintId: latestComplaint.id,
        newStatus: ComplaintStatus.resolved,
        adminNote: 'Sudah diganti saklar baru oleh penjaga kos.',
      );
      expect(latestComplaint.status, ComplaintStatus.resolved);

      store.createAnnouncement(
        title: 'Uji Pengumuman',
        content: 'Isi pengumuman uji',
      );
      final latestAnn = store.announcements.first;
      expect(latestAnn.readByTenantIds.contains(tenant.id), isFalse);

      store.markAnnouncementRead(latestAnn.id, tenant.id);
      expect(latestAnn.readByTenantIds.contains(tenant.id), isTrue);
    });

    test(
      'FR-16: completeBookingPayment tetap berhasil dengan fallbackHold jika id hold berubah setelah sinkronisasi',
      () {
        final store = EstopaStore();
        final room = store.rooms.firstWhere(
          (r) => r.status == RoomStatus.available,
        );
        final hold = store.createBookingHold(
          room: room,
          months: 2,
          fullName: 'Dewi Anggraini',
          phone: '081299001122',
          email: 'dewi.anggraini@gmail.com',
          originAddress: 'Medan',
          parentName: 'Ibu Dewi',
          parentPhone: '081399001133',
          password: 'passwordDewi',
          ktpNumber: '1276014506050099',
          ktpFileName: 'ktp_dewi.jpg',
          ktpConsent: true,
        );

        // Simulasikan skenario saat sync backend / state menghilangkan id 'BKG-...'
        // dari _bookingHolds sementara layar QR masih memegang objek hold awal.
        store.expireBookingHold(hold.id);
        expect(store.bookingHolds.where((b) => b.id == hold.id), isEmpty);
        final paymentsBefore = store.payments.length;

        final tenant = store.completeBookingPayment(hold.id, hold);
        final duplicateTenant = store.completeBookingPayment(hold.id, hold);

        expect(tenant.email, 'dewi.anggraini@gmail.com');
        expect(duplicateTenant.id, tenant.id);
        expect(store.payments.length, paymentsBefore + 1);
        expect(room.status, RoomStatus.occupied);
      },
    );
  });

  testWidgets('Beranda Estopa Kos menampilkan daftar kamar kosong tanpa login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const EstopaKosApp());
    expect(find.text('Estopa Kos'), findsOneWidget);
    expect(find.textContaining('Kamar Kosong'), findsWidgets);

    // Pastikan seluruh halaman (termasuk banner atas) dapat di-scroll ke bawah
    expect(find.text('Cek Kamar Kosong & Pesan Langsung via QRIS'), findsOneWidget);
    await tester.drag(
      find.text('Cek Kamar Kosong & Pesan Langsung via QRIS'),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cek Kamar Kosong & Pesan Langsung via QRIS'), findsNothing);
  });

  testWidgets(
    'Dashboard Penghuni: konfirmasi +1 Hr Telat dan Buat QR tetap menampilkan tagihan',
    (WidgetTester tester) async {
      final store = EstopaStore();
      final room = store.rooms.firstWhere(
        (r) => r.status == RoomStatus.available,
      );
      final hold = store.createBookingHold(
        room: room,
        months: 1,
        fullName: 'Rina Marlina',
        phone: '081288990011',
        email: 'rina.marlina@gmail.com',
        originAddress: 'Medan',
        parentName: 'Ibu Rina',
        parentPhone: '081388990022',
        password: 'SandiRina123',
        ktpNumber: '1276014506050088',
        ktpFileName: 'ktp_rina.jpg',
        ktpConsent: true,
      );
      expect(
        store.pendingPlainPasswordFor(holdId: hold.id, email: hold.email),
        'SandiRina123',
      );
      final tenant = store.completeBookingPayment(hold.id, hold);
      store.login(tenant.email, 'SandiRina123');

      await tester.pumpWidget(
        MaterialApp(home: TenantDashboardScreen(store: store)),
      );
      await tester.pumpAndSettle();

      // Awalnya ada tagihan & riwayat pembayaran awal
      expect(find.text('Belum ada tagihan.'), findsNothing);
      expect(find.text('Belum ada riwayat pembayaran.'), findsNothing);

      // Tekan +1 Hr Telat -> dialog konfirmasi muncul
      await tester.tap(find.text('+1 Hr Telat'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Apakah anda ingin menambahkan 1 hari denda?'),
        findsOneWidget,
      );

      // Pilih Batal -> denda tidak bertambah
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      final myInv = store.invoices.firstWhere((i) => i.tenantId == tenant.id);
      expect(myInv.lateDays, 0);

      // Tekan +1 Hr Telat lagi lalu Ya, Tambahkan
      await tester.tap(find.text('+1 Hr Telat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ya, Tambahkan'));
      await tester.pumpAndSettle();
      expect(myInv.lateDays, 1);

      // Tekan Buat QR Tagihan -> tagihan & riwayat tetap tampil dan QR muncul
      await tester.tap(find.text('Buat QR Tagihan (Berlaku 24 Jam)'));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada tagihan.'), findsNothing);
      expect(find.text('Belum ada riwayat pembayaran.'), findsNothing);
      expect(find.text('Simulasi Bayar Lunas (Webhook)'), findsOneWidget);
    },
  );

  testWidgets(
    'Admin melihat foto kamar, data calon penghuni masuk, dan foto KTP penghuni',
    (WidgetTester tester) async {
      const samplePngBase64 =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

      final store = EstopaStore();
      final smallRoom = store.rooms.firstWhere((r) => r.number == '1');
      final largeRoom = store.rooms.firstWhere((r) => r.number == '11');
      expect(smallRoom.effectivePhotoAsset, 'assets/images/kamar_kecil.jpg');
      expect(largeRoom.effectivePhotoAsset, 'assets/images/kamar_besar_ac.jpg');

      // Buat pemesanan calon penghuni dengan foto KTP base64
      final hold = store.createBookingHold(
        room: smallRoom,
        months: 2,
        fullName: 'Citra Kirana',
        phone: '081255667788',
        email: 'citra.kirana@gmail.com',
        originAddress: 'Jl. Gatot Subroto No. 9, Medan',
        parentName: 'Bapak Agus',
        parentPhone: '081355667799',
        password: 'PasswordCitra123',
        ktpNumber: '1276014506050123',
        ktpFileName: 'ktp_citra.png',
        ktpImageBase64: samplePngBase64,
        ktpConsent: true,
      );
      expect(hold.ktpImageBase64, samplePngBase64);

      // Pump AdminDashboardScreen lalu buka tab Penghuni & Kamar
      await tester.pumpWidget(
        MaterialApp(home: AdminDashboardScreen(store: store)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Penghuni & Kamar'));
      await tester.pumpAndSettle();

      // Pastikan nomor kamar 1 digit ('2') tidak memicu RangeError dan calon penghuni tampil
      expect(find.text('Calon Penghuni Masuk (1)'), findsOneWidget);
      expect(find.text('Citra Kirana'), findsOneWidget);

      // Buka detail calon penghuni & pastikan seluruh data + foto KTP tampil
      await tester.tap(find.text('Citra Kirana'));
      await tester.pumpAndSettle();
      expect(find.text('Data Calon Penghuni: Citra Kirana'), findsOneWidget);
      expect(find.text('Jl. Gatot Subroto No. 9, Medan'), findsOneWidget);
      expect(find.text('Bapak Agus'), findsOneWidget);
      expect(find.text('Perbesar KTP'), findsOneWidget);
      expect(base64Decode(samplePngBase64), isNotEmpty);

      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();

      // Selesaikan pembayaran calon penghuni -> pindah ke penghuni aktif dengan ktpImageBase64 tetap ada
      final paidTenant = store.completeBookingPayment(hold.id, hold);
      expect(paidTenant.ktpImageBase64, samplePngBase64);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Citra Kirana'));
      await tester.pumpAndSettle();
      expect(find.text('Data Penghuni & KTP: Citra Kirana'), findsOneWidget);
      expect(find.text('Perbesar KTP'), findsOneWidget);
    },
  );
}
