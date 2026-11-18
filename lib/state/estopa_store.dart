import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../utils/formatters.dart';
import '../utils/security.dart';

class LoginResult {
  final bool success;
  final String message;
  final UserRole? role;

  const LoginResult({
    required this.success,
    required this.message,
    this.role,
  });
}

class EstopaStore extends ChangeNotifier {
  // Admin credentials
  static const String adminEmail = 'haziqalfareza06@gmail.com';
  static const String adminPhone = '08116001234';
  static const String adminPassword = 'admin123';
  static final String _adminPasswordHash =
      PasswordSecurity.hashPassword(adminPassword);

  UserRole? _currentUserRole;
  Tenant? _currentTenant;

  final List<Room> _rooms = [];
  final List<Tenant> _tenants = [];
  final List<BookingHold> _bookingHolds = [];
  final List<Invoice> _invoices = [];
  final List<PaymentRecord> _payments = [];
  final List<ExpenseRecord> _expenses = [];
  final List<Complaint> _complaints = [];
  final List<Announcement> _announcements = [];
  final List<AppNotification> _notifications = [];
  final Set<String> _processedWebhookKeys = {};
  final Map<String, String> _pendingPlainPasswords = {};
  final EstopaApiClient apiClient = EstopaApiClient();

  String? pendingPlainPasswordFor({String? holdId, String? email}) {
    if (holdId != null && _pendingPlainPasswords.containsKey(holdId)) {
      return _pendingPlainPasswords[holdId];
    }
    if (email != null) {
      final clean = email.trim().toLowerCase();
      if (_pendingPlainPasswords.containsKey(clean)) {
        return _pendingPlainPasswords[clean];
      }
    }
    return null;
  }

  bool _isBackendConnected = false;
  String? _lastSyncError;

  EstopaStore() {
    _seedInitialData();
  }

  bool get isBackendConnected => _isBackendConnected;
  String? get lastSyncError => _lastSyncError;
  String get backendUrl => apiClient.baseUrl;

  Future<bool> syncFromBackend([String? customBaseUrl]) async {
    if (customBaseUrl != null && customBaseUrl.trim().isNotEmpty) {
      apiClient.baseUrl = customBaseUrl.trim();
    }
    try {
      final data = await apiClient.getJson('/bootstrap');
      _applyBootstrapPayload(data);
      _isBackendConnected = true;
      _lastSyncError = null;
      notifyListeners();
      return true;
    } catch (e) {
      _isBackendConnected = false;
      _lastSyncError = e.toString();
      notifyListeners();
      return false;
    }
  }

  void _applyBootstrapPayload(Map<String, dynamic> data) {
    final roomsJson = (data['rooms'] as List?) ?? [];
    if (roomsJson.isEmpty) return;

    _rooms
      ..clear()
      ..addAll(roomsJson.map((e) {
        final m = e as Map<String, dynamic>;
        return Room(
          id: m['id'] as String,
          number: m['number'] as String,
          floor: m['floor'] as int,
          pricePerMonth: m['pricePerMonth'] as int,
          facilities: (m['facilities'] as List).cast<String>(),
          gender: m['gender'] == 'putri' ? RoomGender.putri : RoomGender.putra,
          photoUrl: m['photoUrl'] as String?,
          status: RoomStatus.values.firstWhere(
            (s) => s.name == m['status'],
            orElse: () => RoomStatus.available,
          ),
          currentTenantId: m['currentTenantId'] as String?,
          holdExpiresAt: m['holdExpiresAt'] != null
              ? DateTime.parse(m['holdExpiresAt'] as String)
              : null,
        );
      }));

    _tenants
      ..clear()
      ..addAll(((data['tenants'] as List?) ?? []).map((e) {
        final m = e as Map<String, dynamic>;
        return Tenant(
          id: m['id'] as String,
          fullName: m['fullName'] as String,
          phone: m['phone'] as String,
          email: m['email'] as String,
          originAddress: m['originAddress'] as String,
          parentName: m['parentName'] as String,
          parentPhone: m['parentPhone'] as String,
          password: m['password'] as String,
          ktpNumber: m['ktpNumber'] as String,
          ktpFileName: m['ktpFileName'] as String,
          ktpImageBase64: m['ktpImageBase64'] as String?,
          ktpConsentAccepted: m['ktpConsentAccepted'] as bool? ?? true,
          roomId: m['roomId'] as String?,
          roomNumberSnapshot: m['roomNumberSnapshot'] as String,
          isActive: m['isActive'] as bool? ?? true,
          leaseStartDate: DateTime.parse(m['leaseStartDate'] as String),
          leaseEndDate: DateTime.parse(m['leaseEndDate'] as String),
        );
      }));

    if (_currentTenant != null) {
      final prev = _currentTenant!;
      final refreshedById = _tenants.where((t) => t.id == prev.id);
      if (refreshedById.isNotEmpty) {
        _currentTenant = refreshedById.first;
      } else {
        final refreshedByContact = _tenants.where(
          (t) =>
              t.email.toLowerCase() == prev.email.toLowerCase() ||
              t.phone == prev.phone,
        );
        if (refreshedByContact.isNotEmpty) {
          _currentTenant = refreshedByContact.first;
        }
      }
    }

    _bookingHolds
      ..clear()
      ..addAll(((data['bookingHolds'] as List?) ?? []).map((e) {
        final m = e as Map<String, dynamic>;
        return BookingHold(
          id: m['id'] as String,
          roomId: m['roomId'] as String,
          roomNumber: m['roomNumber'] as String,
          roomPricePerMonth: m['roomPricePerMonth'] as int,
          months: m['months'] as int,
          fullName: m['fullName'] as String,
          phone: m['phone'] as String,
          email: m['email'] as String,
          originAddress: m['originAddress'] as String,
          parentName: m['parentName'] as String,
          parentPhone: m['parentPhone'] as String,
          password: m['password'] as String,
          ktpNumber: m['ktpNumber'] as String,
          ktpFileName: m['ktpFileName'] as String,
          ktpImageBase64: m['ktpImageBase64'] as String?,
          ktpConsent: m['ktpConsent'] as bool? ?? true,
          createdAt: DateTime.parse(m['createdAt'] as String),
          expiresAt: DateTime.parse(m['expiresAt'] as String),
          qrPayload: m['qrPayload'] as String,
          isExpired: m['isExpired'] as bool? ?? false,
          isPaid: m['isPaid'] as bool? ?? false,
        );
      }));

    _invoices
      ..clear()
      ..addAll(((data['invoices'] as List?) ?? []).map((e) {
        final m = e as Map<String, dynamic>;
        return Invoice(
          id: m['id'] as String,
          tenantId: m['tenantId'] as String,
          tenantName: m['tenantName'] as String,
          roomNumber: m['roomNumber'] as String,
          roomPricePerMonth: m['roomPricePerMonth'] as int,
          selectedMonths: m['selectedMonths'] as int,
          dueDate: DateTime.parse(m['dueDate'] as String),
          status: InvoiceStatus.values.firstWhere(
            (s) => s.name == m['status'],
            orElse: () => InvoiceStatus.unpaid,
          ),
          lateDays: m['lateDays'] as int? ?? 0,
          activeQrCode: m['activeQrCode'] as String?,
          qrExpiresAt: m['qrExpiresAt'] != null
              ? DateTime.parse(m['qrExpiresAt'] as String)
              : null,
          paidAt: m['paidAt'] != null
              ? DateTime.parse(m['paidAt'] as String)
              : null,
          sentReminders: (m['sentReminders'] as List?)?.cast<String>(),
        );
      }));

    _payments
      ..clear()
      ..addAll(((data['payments'] as List?) ?? []).map((e) {
        final m = e as Map<String, dynamic>;
        return PaymentRecord(
          id: m['id'] as String,
          tenantId: m['tenantId'] as String,
          tenantName: m['tenantName'] as String,
          roomNumber: m['roomNumber'] as String,
          type: m['type'] as String,
          months: m['months'] as int,
          roomCost: m['roomCost'] as int,
          waterCost: m['waterCost'] as int,
          transactionFee: m['transactionFee'] as int,
          lateFee: m['lateFee'] as int? ?? 0,
          totalAmount: m['totalAmount'] as int,
          paidAt: DateTime.parse(m['paidAt'] as String),
          gatewayReference: m['gatewayReference'] as String,
        );
      }));

    _expenses
      ..clear()
      ..addAll(((data['expenses'] as List?) ?? []).map((e) {
        final m = e as Map<String, dynamic>;
        return ExpenseRecord(
          id: m['id'] as String,
          title: m['title'] as String,
          category: m['category'] as String,
          amount: m['amount'] as int,
          date: DateTime.parse(m['date'] as String),
          notes: m['notes'] as String? ?? '',
        );
      }));

    _complaints
      ..clear()
      ..addAll(((data['complaints'] as List?) ?? []).map((e) {
        final m = e as Map<String, dynamic>;
        return Complaint(
          id: m['id'] as String,
          tenantId: m['tenantId'] as String,
          tenantName: m['tenantName'] as String,
          roomNumber: m['roomNumber'] as String,
          category: m['category'] as String,
          description: m['description'] as String,
          attachmentName: m['attachmentName'] as String?,
          createdAt: DateTime.parse(m['createdAt'] as String),
          status: ComplaintStatus.values.firstWhere(
            (s) => s.name == m['status'],
            orElse: () => ComplaintStatus.submitted,
          ),
          adminNote: m['adminNote'] as String?,
        );
      }));

    _announcements
      ..clear()
      ..addAll(((data['announcements'] as List?) ?? []).map((e) {
        final m = e as Map<String, dynamic>;
        return Announcement(
          id: m['id'] as String,
          title: m['title'] as String,
          content: m['content'] as String,
          createdAt: DateTime.parse(m['createdAt'] as String),
          readByTenantIds: (m['readByTenantIds'] as List?)?.cast<String>(),
        );
      }));

    _notifications
      ..clear()
      ..addAll(((data['notifications'] as List?) ?? []).map((e) {
        final m = e as Map<String, dynamic>;
        return AppNotification(
          id: m['id'] as String,
          targetAudience: m['targetAudience'] as String,
          channel: m['channel'] as String,
          title: m['title'] as String,
          message: m['message'] as String,
          createdAt: DateTime.parse(m['createdAt'] as String),
          isRead: m['isRead'] as bool? ?? false,
        );
      }));
  }

  void _syncRemote(Future<void> Function() action) {
    if (!_isBackendConnected) return;
    unawaited(
      action().then((_) => syncFromBackend()).catchError((Object e) {
        _lastSyncError = e.toString();
        return false;
      }),
    );
  }

  UserRole? get currentUserRole => _currentUserRole;
  Tenant? get currentTenant => _currentTenant;

  List<Room> get rooms => List.unmodifiable(_rooms);
  List<Tenant> get tenants => List.unmodifiable(_tenants);
  List<BookingHold> get bookingHolds => List.unmodifiable(_bookingHolds);
  List<Invoice> get invoices => List.unmodifiable(_invoices);
  List<PaymentRecord> get payments => List.unmodifiable(_payments);
  List<ExpenseRecord> get expenses => List.unmodifiable(_expenses);
  List<Complaint> get complaints => List.unmodifiable(_complaints);
  List<Announcement> get announcements => List.unmodifiable(_announcements);
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  List<Room> get availableRooms =>
      _rooms.where((r) => r.status == RoomStatus.available).toList();

  int get totalIncome =>
      _payments.fold(0, (sum, item) => sum + item.totalAmount);

  int get totalExpense =>
      _expenses.fold(0, (sum, item) => sum + item.amount);

  int get netBalance => totalIncome - totalExpense;

  List<Invoice> get unpaidOrOverdueInvoices => _invoices
      .where((i) =>
          i.status == InvoiceStatus.unpaid || i.status == InvoiceStatus.overdue)
      .toList();

  void _seedInitialData() {
    // 39 Kamar di 4 Lantai (Nomor 1 s.d. 39):
    // - Lantai 1 (Putri) : Kamar 1–10
    // - Lantai 2 (Putri) : Kamar 11–22
    // - Lantai 3 (Putra) : Kamar 23–34
    // - Lantai 4 (Putra) : Kamar 35–39
    //
    // Tipe & Harga:
    // - Kamar Besar AC (11,17,23,29,35,36,37,38,39) : Rp1.500.000/bln
    // - Kamar Kecil AC (15 kamar acak)                : Rp1.300.000/bln
    // - Kamar Kecil Kipas (15 kamar sisanya)          : Rp900.000/bln
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
      final isPutri = floor <= 2;
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

      _rooms.add(
        Room(
          id: 'RM-$roomNumber',
          number: roomNumber,
          floor: floor,
          pricePerMonth: price,
          facilities: facilities,
          gender: isPutri ? RoomGender.putri : RoomGender.putra,
          photoUrl: isLarge
              ? 'assets/images/kamar_besar_ac.jpg'
              : 'assets/images/kamar_kecil.jpg',
          status: RoomStatus.available,
        ),
      );
    }

    final now = DateTime.now();
    final defaultHash = PasswordSecurity.hashPassword('password123');

    // Seed 3 penghuni aktif + 1 penghuni lama nonaktif untuk simulasi semua skenario PRD
    final t1 = Tenant(
      id: 'TNT-001',
      fullName: 'Nadia Salsabila Siregar',
      phone: '081260001111',
      email: 'nadia@gmail.com',
      originAddress: 'Jl. Sisingamangaraja No. 45, Rantauprapat',
      parentName: 'H. Ahmad Siregar',
      parentPhone: '081361112222',
      password: defaultHash,
      ktpNumber: '1209015504040001',
      ktpFileName: 'ktp_nadia_siregar.jpg',
      ktpConsentAccepted: true,
      roomId: 'RM-2',
      roomNumberSnapshot: '2',
      isActive: true,
      leaseStartDate: now.subtract(const Duration(days: 28)),
      leaseEndDate: now.add(const Duration(days: 2)),
    );

    final t2 = Tenant(
      id: 'TNT-002',
      fullName: 'Rizky Pratama Ginting',
      phone: '081260002222',
      email: 'rizky@gmail.com',
      originAddress: 'Jl. Veteran No. 12, Kabanjahe, Karo',
      parentName: 'Bapak Darmawan Ginting',
      parentPhone: '081362223333',
      password: defaultHash,
      ktpNumber: '1206011208030002',
      ktpFileName: 'ktp_rizky_ginting.jpg',
      ktpConsentAccepted: true,
      roomId: 'RM-23',
      roomNumberSnapshot: '23',
      isActive: true,
      leaseStartDate: now.subtract(const Duration(days: 33)),
      leaseEndDate: now.subtract(const Duration(days: 3)),
    );

    final t3 = Tenant(
      id: 'TNT-003',
      fullName: 'Kevin Immanuel Simanjuntak',
      phone: '081260003333',
      email: 'kevin@gmail.com',
      originAddress: 'Jl. Diponegoro No. 88, Balige, Toba',
      parentName: 'Bapak Poltak Simanjuntak',
      parentPhone: '081363334444',
      password: defaultHash,
      ktpNumber: '1212012101040003',
      ktpFileName: 'ktp_kevin_simanjuntak.jpg',
      ktpConsentAccepted: true,
      roomId: 'RM-24',
      roomNumberSnapshot: '24',
      isActive: true,
      leaseStartDate: now.subtract(const Duration(days: 5)),
      leaseEndDate: now.add(const Duration(days: 85)),
    );

    final t4Inactive = Tenant(
      id: 'TNT-004',
      fullName: 'Dinda Maharani Nasution (Alumni)',
      phone: '081260004444',
      email: 'dinda@gmail.com',
      originAddress: 'Jl. Sudirman No. 19, Padangsidimpuan',
      parentName: 'Bapak Syahrul Nasution',
      parentPhone: '081364445555',
      password: defaultHash,
      ktpNumber: '1277014402020004',
      ktpFileName: 'ktp_dinda_nasution.jpg',
      ktpConsentAccepted: true,
      roomId: null,
      roomNumberSnapshot: '12 (Sudah Keluar)',
      isActive: false,
      leaseStartDate: now.subtract(const Duration(days: 120)),
      leaseEndDate: now.subtract(const Duration(days: 30)),
    );

    _tenants.addAll([t1, t2, t3, t4Inactive]);

    // Tandai kamar yang sudah terisi (12 kamar terisi dari 39 kamar)
    _occupyRoom('RM-2', t1.id);
    _occupyRoom('RM-23', t2.id);
    _occupyRoom('RM-24', t3.id);

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
      final room = _rooms.firstWhere((r) => r.number == numStr);
      final tenantId = 'TNT-10$idx';
      final tenant = Tenant(
        id: tenantId,
        fullName: 'Penghuni Kamar $numStr',
        phone: '08126999000$idx',
        email: 'kamar$numStr@gmail.com',
        originAddress: 'Sumatera Utara',
        parentName: 'Orang Tua Kamar $numStr',
        parentPhone: '08136999000$idx',
        password: defaultHash,
        ktpNumber: '127101000000000$idx',
        ktpFileName: 'ktp_kamar_$numStr.jpg',
        ktpConsentAccepted: true,
        roomId: room.id,
        roomNumberSnapshot: room.number,
        isActive: true,
        leaseStartDate: now.subtract(const Duration(days: 15)),
        leaseEndDate: now.add(const Duration(days: 15)),
      );
      _tenants.add(tenant);
      _occupyRoom(room.id, tenant.id);
    }

    // Seed Tagihan (Invoices)
    _invoices.add(
      Invoice(
        id: 'INV-2026-001',
        tenantId: t1.id,
        tenantName: t1.fullName,
        roomNumber: '2',
        roomPricePerMonth: 1300000,
        selectedMonths: 1,
        dueDate: now.add(const Duration(days: 2)),
        status: InvoiceStatus.unpaid,
        lateDays: 0,
        sentReminders: ['H-3', 'H-2'],
      ),
    );

    _invoices.add(
      Invoice(
        id: 'INV-2026-002',
        tenantId: t2.id,
        tenantName: t2.fullName,
        roomNumber: '23',
        roomPricePerMonth: 1500000,
        selectedMonths: 1,
        dueDate: now.subtract(const Duration(days: 3)),
        status: InvoiceStatus.overdue,
        lateDays: 3,
        sentReminders: ['H-3', 'H-2', 'H-1', 'Jatuh Tempo', 'Terlambat'],
      ),
    );

    _invoices.add(
      Invoice(
        id: 'INV-2026-003',
        tenantId: t3.id,
        tenantName: t3.fullName,
        roomNumber: '24',
        roomPricePerMonth: 900000,
        selectedMonths: 3,
        dueDate: now.subtract(const Duration(days: 5)),
        status: InvoiceStatus.paid,
        lateDays: 0,
        paidAt: now.subtract(const Duration(days: 5)),
      ),
    );

    // Seed Riwayat Pembayaran (FR-09, FR-10)
    _payments.addAll([
      PaymentRecord(
        id: 'PAY-001',
        tenantId: t1.id,
        tenantName: t1.fullName,
        roomNumber: '2',
        type: 'Pemesanan Awal',
        months: 1,
        roomCost: 1300000,
        waterCost: 35000,
        transactionFee: 4000,
        lateFee: 0,
        totalAmount: 1339000,
        paidAt: now.subtract(const Duration(days: 28)),
        gatewayReference: 'GW-SANDBOX-98211',
      ),
      PaymentRecord(
        id: 'PAY-002',
        tenantId: t3.id,
        tenantName: t3.fullName,
        roomNumber: '24',
        type: 'Tagihan Sewa (3 Bulan)',
        months: 3,
        roomCost: 900000 * 3,
        waterCost: 35000 * 3,
        transactionFee: 4000,
        lateFee: 0,
        totalAmount: CostConstants.calculateTotal(
          roomPricePerMonth: 900000,
          months: 3,
        ),
        paidAt: now.subtract(const Duration(days: 5)),
        gatewayReference: 'GW-SANDBOX-98450',
      ),
      PaymentRecord(
        id: 'PAY-003',
        tenantId: t4Inactive.id,
        tenantName: t4Inactive.fullName,
        roomNumber: '12',
        type: 'Tagihan Sewa',
        months: 1,
        roomCost: 900000,
        waterCost: 35000,
        transactionFee: 4000,
        lateFee: 0,
        totalAmount: 939000,
        paidAt: now.subtract(const Duration(days: 60)),
        gatewayReference: 'GW-SANDBOX-97102',
      ),
    ]);

    // Seed Pengeluaran Kos (FR-11)
    _expenses.addAll([
      ExpenseRecord(
        id: 'EXP-001',
        title: 'Tagihan Air PDAM Tirtanadi & Pompa',
        category: 'Air & Utilitas',
        amount: 420000,
        date: now.subtract(const Duration(days: 10)),
        notes: 'Pembayaran PDAM bulanan gedung 4 lantai',
      ),
      ExpenseRecord(
        id: 'EXP-002',
        title: 'Token Listrik Area Koridor & Parkir',
        category: 'Listrik',
        amount: 350000,
        date: now.subtract(const Duration(days: 7)),
        notes: 'Lampu lorong lantai 1-4 dan pompa air',
      ),
      ExpenseRecord(
        id: 'EXP-003',
        title: 'Langganan Internet Wi-Fi Bisnis',
        category: 'Internet',
        amount: 550000,
        date: now.subtract(const Duration(days: 4)),
        notes: 'IndiHome + router lantai 1 s.d. 4',
      ),
    ]);

    // Seed Keluhan (FR-23 s.d. FR-25)
    _complaints.addAll([
      Complaint(
        id: 'CMP-001',
        tenantId: t1.id,
        tenantName: t1.fullName,
        roomNumber: '2',
        category: 'Air / Kamar Mandi',
        description:
            'Kran wastafel kamar mandi agak menetes sejak kemarin sore.',
        attachmentName: 'foto_kran_2.jpg',
        createdAt: now.subtract(const Duration(days: 1)),
        status: ComplaintStatus.inProgress,
        adminNote:
            'Penjaga kos (Bang Hendra) dijadwalkan ganti seal sore ini.',
      ),
      Complaint(
        id: 'CMP-002',
        tenantId: t2.id,
        tenantName: t2.fullName,
        roomNumber: '23',
        category: 'Wi-Fi / Internet',
        description: 'Sinyal Wi-Fi lantai 3 agak lambat saat malam hari.',
        createdAt: now.subtract(const Duration(days: 3)),
        status: ComplaintStatus.resolved,
        adminNote: 'Access point lantai 3 sudah di-restart dan ganti channel.',
      ),
    ]);

    // Seed Pengumuman (FR-26 s.d. FR-28)
    _announcements.addAll([
      Announcement(
        id: 'ANN-001',
        title: 'Pembersihan Tandon Air Utama Lantai 4',
        content:
            'Diberitahukan kepada seluruh penghuni Estopa Kos bahwa pada hari Sabtu pukul 09.00 - 11.00 WIB akan dilakukan pengurasan tandon air utama. Mohon menampung air secukupnya.',
        createdAt: now.subtract(const Duration(days: 2)),
        readByTenantIds: [t1.id, t3.id],
      ),
      Announcement(
        id: 'ANN-002',
        title: 'Ketertiban Jam Tamu & Kunci Gerbang Malam',
        content:
            'Batas jam berkunjung tamu adalah pukul 22.00 WIB. Gerbang utama dikunci pukul 23.00 WIB demi keamanan bersama.',
        createdAt: now.subtract(const Duration(days: 6)),
        readByTenantIds: [t1.id, t2.id, t3.id],
      ),
    ]);

    // Seed Notifikasi Sistem & Email
    _notifications.addAll([
      AppNotification(
        id: 'NTF-001',
        targetAudience: t1.id,
        channel: 'SISTEM & EMAIL',
        title: 'Pengingat Tagihan H-2 (Kamar 2)',
        message:
            'Halo Nadia, tagihan sewa Kamar 2 akan jatuh tempo dalam 2 hari (${AppFormatters.date(now.add(const Duration(days: 2)))}).',
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      AppNotification(
        id: 'NTF-002',
        targetAudience: t2.id,
        channel: 'SISTEM & EMAIL',
        title: 'Tagihan Terlambat 3 Hari (Kamar 23)',
        message:
            'Tagihan Kamar 23 telah melewati jatuh tempo 3 hari. Denda berjalan Rp50.000/hari. Segera lakukan pembayaran via QRIS.',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      AppNotification(
        id: 'NTF-003',
        targetAudience: 'ADMIN',
        channel: 'SISTEM',
        title: 'Peringatan Keterlambatan Tagihan',
        message:
            'Penghuni Rizky Pratama Ginting (Kamar 23) terlambat membayar 3 hari.',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
    ]);
  }

  void _occupyRoom(String roomId, String tenantId) {
    final idx = _rooms.indexWhere((r) => r.id == roomId);
    if (idx != -1) {
      _rooms[idx].status = RoomStatus.occupied;
      _rooms[idx].currentTenantId = tenantId;
      _rooms[idx].holdExpiresAt = null;
    }
  }

  // ==================== AUTH (FR-29, FR-21, NFR-02) ====================
  LoginResult login(String identifier, String password) {
    final cleanId = identifier.trim().toLowerCase();

    if ((cleanId == adminEmail.toLowerCase() ||
            cleanId == 'admin@estopakos.id' ||
            cleanId == adminPhone) &&
        PasswordSecurity.verifyPassword(password, _adminPasswordHash)) {
      _currentUserRole = UserRole.admin;
      _currentTenant = null;
      notifyListeners();
      return const LoginResult(
        success: true,
        message: 'Berhasil masuk sebagai Admin Estopa Kos.',
        role: UserRole.admin,
      );
    }

    for (final tenant in _tenants) {
      final matchEmail = tenant.email.toLowerCase() == cleanId;
      final matchPhone = tenant.phone.trim() == cleanId;
      if (matchEmail || matchPhone) {
        if (!tenant.isActive) {
          return const LoginResult(
            success: false,
            message:
                'Akun Anda sudah tidak aktif karena masa sewa/kamar telah dikosongkan oleh Admin (FR-21).',
          );
        }
        final isPwdMatch =
            PasswordSecurity.verifyPassword(password, tenant.password) ||
            tenant.password == password;
        if (!isPwdMatch) {
          return const LoginResult(
            success: false,
            message:
                'Kata sandi salah. Hubungi Admin Estopa Kos jika memerlukan reset kata sandi (FR-22).',
          );
        }
        _currentUserRole = UserRole.tenant;
        _currentTenant = tenant;
        notifyListeners();
        return LoginResult(
          success: true,
          message: 'Selamat datang kembali, ${tenant.fullName}!',
          role: UserRole.tenant,
        );
      }
    }

    return const LoginResult(
      success: false,
      message: 'Email atau Nomor HP tidak ditemukan.',
    );
  }

  void logout() {
    _currentUserRole = null;
    _currentTenant = null;
    notifyListeners();
  }

  // ==================== PEMESANAN KAMAR & QR 20 MENIT (FR-12 s.d. FR-17) ====================
  BookingHold createBookingHold({
    required Room room,
    required int months,
    required String fullName,
    required String phone,
    required String email,
    required String originAddress,
    required String parentName,
    required String parentPhone,
    required String password,
    required String ktpNumber,
    required String ktpFileName,
    String? ktpImageBase64,
    required bool ktpConsent,
  }) {
    // Mitigasi Risiko PRD Bagian 10: Kunci status kamar agar tidak dipesan dua orang bersamaan
    if (room.status != RoomStatus.available) {
      throw StateError(
        'Kamar ${room.number} sedang ditahan atau sudah terisi oleh pemesan lain.',
      );
    }

    final now = DateTime.now();
    final expiresAt =
        now.add(const Duration(minutes: CostConstants.bookingHoldMinutes));

    // Kunci kamar selama 20 menit (FR-14)
    room.status = RoomStatus.held;
    room.holdExpiresAt = expiresAt;

    final holdId = 'BKG-${now.microsecondsSinceEpoch.toString().substring(8)}';
    final total = CostConstants.calculateTotal(
      roomPricePerMonth: room.pricePerMonth,
      months: months,
    );

    final hold = BookingHold(
      id: holdId,
      roomId: room.id,
      roomNumber: room.number,
      roomPricePerMonth: room.pricePerMonth,
      months: months,
      fullName: fullName.trim(),
      phone: phone.trim(),
      email: email.trim(),
      originAddress: originAddress.trim(),
      parentName: parentName.trim(),
      parentPhone: parentPhone.trim(),
      password: PasswordSecurity.hashPassword(password),
      ktpNumber: ktpNumber.trim(),
      ktpFileName: ktpFileName,
      ktpImageBase64: ktpImageBase64,
      ktpConsent: ktpConsent,
      createdAt: now,
      expiresAt: expiresAt,
      qrPayload:
          'QRIS-BOOKING-ESTOPA-$holdId-RM${room.number}-RP$total-EXP20M',
    );

    _pendingPlainPasswords[holdId] = password;
    _pendingPlainPasswords[hold.email.toLowerCase()] = password;
    _bookingHolds.insert(0, hold);
    notifyListeners();
    _syncRemote(() async {
      await apiClient.postJson('/bookings', {
        'id': hold.id,
        'roomId': hold.roomId,
        'roomNumber': hold.roomNumber,
        'roomPricePerMonth': hold.roomPricePerMonth,
        'months': hold.months,
        'fullName': hold.fullName,
        'phone': hold.phone,
        'email': hold.email,
        'originAddress': hold.originAddress,
        'parentName': hold.parentName,
        'parentPhone': hold.parentPhone,
        'password': hold.password,
        'ktpNumber': hold.ktpNumber,
        'ktpFileName': hold.ktpFileName,
        'ktpImageBase64': hold.ktpImageBase64,
        'ktpConsent': hold.ktpConsent,
        'createdAt': hold.createdAt.toIso8601String(),
        'expiresAt': hold.expiresAt.toIso8601String(),
        'qrPayload': hold.qrPayload,
      });
    });
    return hold;
  }

  /// FR-15 & NFR-04: Jika waktu 20 menit habis, QR hangus, kamar kembali kosong, data sementara & KTP dihapus.
  void expireBookingHold(String holdId, [BookingHold? fallbackHold]) {
    int idx = _bookingHolds.indexWhere((b) => b.id == holdId);
    if (idx == -1 && fallbackHold != null) {
      idx = _bookingHolds.indexWhere(
        (b) =>
            b.roomNumber == fallbackHold.roomNumber &&
            b.email.toLowerCase() == fallbackHold.email.toLowerCase(),
      );
    }
    if (idx == -1 && fallbackHold == null) return;
    final hold = idx != -1 ? _bookingHolds[idx] : fallbackHold!;
    if (hold.isPaid) return;

    hold.isExpired = true;
    final roomIdx = _rooms.indexWhere(
      (r) => r.id == hold.roomId || r.number == hold.roomNumber,
    );
    if (roomIdx != -1 && _rooms[roomIdx].status == RoomStatus.held) {
      _rooms[roomIdx].status = RoomStatus.available;
      _rooms[roomIdx].holdExpiresAt = null;
    }

    // Hapus data sementara & KTP sesuai FR-15 / NFR-04
    _bookingHolds.removeWhere(
      (b) =>
          b.id == holdId ||
          b.id == hold.id ||
          (b.roomNumber == hold.roomNumber &&
              b.email.toLowerCase() == hold.email.toLowerCase()),
    );
    notifyListeners();
    _syncRemote(
      () => apiClient.postJson('/bookings/expire', {'holdId': hold.id}),
    );
  }

  /// FR-16, FR-17, FR-18: Webhook pembayaran pemesanan berhasil -> kamar terisi, akun aktif, email terkirim, notif admin.
  /// Mendukung idempotensi terhadap webhook ganda (Rencana Pengujian Bagian 7).
  Tenant completeBookingPayment(String holdId, [BookingHold? fallbackHold]) {
    final fallbackEmailKey = fallbackHold == null
        ? null
        : 'BOOKING:${fallbackHold.roomNumber}:${fallbackHold.email.toLowerCase()}';
    if (_processedWebhookKeys.contains('BOOKING:$holdId') ||
        (fallbackEmailKey != null &&
            _processedWebhookKeys.contains(fallbackEmailKey))) {
      return _tenants.firstWhere(
        (t) =>
            fallbackHold != null &&
            (t.email.toLowerCase() == fallbackHold.email.toLowerCase() ||
                t.roomNumberSnapshot == fallbackHold.roomNumber),
        orElse: () => _tenants.first,
      );
    }

    BookingHold? matchedHold;
    for (final b in _bookingHolds) {
      if (b.id == holdId) {
        matchedHold = b;
        break;
      }
    }
    if (matchedHold == null && fallbackHold != null) {
      for (final b in _bookingHolds) {
        if (b.roomNumber == fallbackHold.roomNumber &&
            b.email.toLowerCase() == fallbackHold.email.toLowerCase()) {
          matchedHold = b;
          break;
        }
      }
    }
    final hold = matchedHold ?? fallbackHold;
    if (hold == null) {
      throw StateError('Data pemesanan ($holdId) tidak ditemukan.');
    }

    _processedWebhookKeys.add('BOOKING:$holdId');
    _processedWebhookKeys.add('BOOKING:${hold.id}');
    _processedWebhookKeys.add(
      'BOOKING:${hold.roomNumber}:${hold.email.toLowerCase()}',
    );
    hold.isPaid = true;

    final now = DateTime.now();
    final room = _rooms.firstWhere(
      (r) => r.id == hold.roomId,
      orElse: () => _rooms.firstWhere((r) => r.number == hold.roomNumber),
    );
    final newTenantId =
        'TNT-${now.microsecondsSinceEpoch.toString().substring(9)}';

    final newTenant = Tenant(
      id: newTenantId,
      fullName: hold.fullName,
      phone: hold.phone,
      email: hold.email,
      originAddress: hold.originAddress,
      parentName: hold.parentName,
      parentPhone: hold.parentPhone,
      password: hold.password,
      ktpNumber: hold.ktpNumber,
      ktpFileName: hold.ktpFileName,
      ktpImageBase64: hold.ktpImageBase64,
      ktpConsentAccepted: hold.ktpConsent,
      roomId: room.id,
      roomNumberSnapshot: room.number,
      isActive: true,
      leaseStartDate: now,
      leaseEndDate: now.add(Duration(days: 30 * hold.months)),
    );

    _tenants.insert(0, newTenant);
    _occupyRoom(room.id, newTenant.id);

    // Catat pembayaran ke riwayat & rekap pemasukan (FR-09, FR-10)
    _payments.insert(
      0,
      PaymentRecord(
        id: 'PAY-${now.microsecondsSinceEpoch.toString().substring(8)}',
        tenantId: newTenant.id,
        tenantName: newTenant.fullName,
        roomNumber: room.number,
        type: 'Pemesanan Awal (${hold.months} Bulan)',
        months: hold.months,
        roomCost: hold.roomSubtotal,
        waterCost: hold.waterSubtotal,
        transactionFee: hold.transactionFee,
        lateFee: 0,
        totalAmount: hold.totalAmount,
        paidAt: now,
        gatewayReference:
            'GW-QRBOOK-${now.microsecondsSinceEpoch.toString().substring(7)}',
      ),
    );

    // Jadwalkan tagihan periode berikutnya otomatis di akhir masa sewa (FR-01)
    _invoices.insert(
      0,
      Invoice(
        id: 'INV-${now.microsecondsSinceEpoch.toString().substring(8)}',
        tenantId: newTenant.id,
        tenantName: newTenant.fullName,
        roomNumber: room.number,
        roomPricePerMonth: room.pricePerMonth,
        selectedMonths: 1,
        dueDate: newTenant.leaseEndDate,
        status: InvoiceStatus.unpaid,
      ),
    );

    // Kirim email konfirmasi info pembayaran & akun ke penghuni baru (FR-16)
    _notifications.insert(
      0,
      AppNotification(
        id: 'NTF-EML-${now.microsecondsSinceEpoch}',
        targetAudience: newTenant.id,
        channel: 'SISTEM & EMAIL',
        title: 'Pembayaran Berhasil & Akun Estopa Kos Aktif',
        message:
            'Selamat datang di Estopa Kos! Pembayaran Kamar ${room.number} sebesar ${AppFormatters.currency(hold.totalAmount)} telah lunas. Gunakan email (${newTenant.email}) atau HP (${newTenant.phone}) beserta password Anda untuk login.',
        createdAt: now,
      ),
    );

    // Kirim notifikasi pemesanan baru ke Admin (FR-17)
    _notifications.insert(
      0,
      AppNotification(
        id: 'NTF-ADM-${now.microsecondsSinceEpoch}',
        targetAudience: 'ADMIN',
        channel: 'SISTEM & EMAIL',
        title: 'Pemesanan Kamar Baru Lunas (Kamar ${room.number})',
        message:
            '${newTenant.fullName} telah memesan dan melunasi Kamar ${room.number} selama ${hold.months} bulan (${AppFormatters.currency(hold.totalAmount)}). Akun penghuni otomatis aktif.',
        createdAt: now,
      ),
    );

    _bookingHolds.removeWhere(
      (b) =>
          b.id == holdId ||
          b.id == hold.id ||
          (b.roomNumber == hold.roomNumber &&
              b.email.toLowerCase() == hold.email.toLowerCase()),
    );
    final plainPwd = pendingPlainPasswordFor(
      holdId: hold.id,
      email: hold.email,
    );
    notifyListeners();
    _syncRemote(
      () => apiClient.postJson('/bookings/pay', {
        'holdId': hold.id,
        'plainPassword': plainPwd,
        'skipEmail': true,
      }),
    );
    return newTenant;
  }

  /// Kirim email konfirmasi otomatis ke email penghuni melalui Backend SMTP (FR-16).
  Future<Map<String, dynamic>?> triggerWelcomeEmail({
    required String fullName,
    required String email,
    required String phone,
    required String roomNumber,
    required int months,
    required int roomCost,
    required int waterCost,
    required int transactionFee,
    required int totalAmount,
    String? plainPassword,
  }) async {
    return apiClient.postJson('/email/welcome', {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'roomNumber': roomNumber,
      'months': months,
      'roomCost': roomCost,
      'waterCost': waterCost,
      'transactionFee': transactionFee,
      'totalAmount': totalAmount,
      'plainPassword': plainPassword ?? pendingPlainPasswordFor(email: email),
    });
  }

  Future<Map<String, dynamic>?> getSmtpConfig() async {
    return apiClient.getJson('/email/config');
  }

  Future<Map<String, dynamic>?> updateSmtpConfig({
    required String smtpUser,
    required String smtpPass,
    String smtpHost = 'smtp.gmail.com',
    int smtpPort = 587,
  }) async {
    return apiClient.postJson('/email/config', {
      'smtpHost': smtpHost,
      'smtpPort': smtpPort,
      'smtpUser': smtpUser,
      'smtpPass': smtpPass,
    });
  }

  // ==================== TAGIHAN, QR 24 JAM, DENDA & PENGINGAT (FR-01 s.d. FR-08) ====================
  void updateInvoiceMonths(String invoiceId, int months) {
    final inv = _invoices.firstWhere((i) => i.id == invoiceId);
    inv.selectedMonths = months;
    _syncRemote(() => apiClient.postJson('/invoices/months', {
          'invoiceId': invoiceId,
          'roomNumber': inv.roomNumber,
          'months': months,
        }));
    if (inv.activeQrCode != null) {
      generateInvoiceQr(invoiceId);
    } else {
      notifyListeners();
    }
  }

  /// FR-03 & FR-04: Buat QR Tagihan berlaku 24 jam (terpisah dari QR pemesanan) dengan denda terbaru.
  void generateInvoiceQr(String invoiceId) {
    final inv = _invoices.firstWhere((i) => i.id == invoiceId);
    final now = DateTime.now();
    inv.qrExpiresAt =
        now.add(const Duration(hours: CostConstants.invoiceQrValidHours));
    inv.activeQrCode =
        'QRIS-TAGIHAN-ESTOPA-${inv.id}-RM${inv.roomNumber}-M${inv.selectedMonths}-DENDA${inv.lateFeeSubtotal}-TOTAL${inv.totalAmount}-EXP24H';
    notifyListeners();
    _syncRemote(() => apiClient.postJson('/invoices/qr', {
          'invoiceId': invoiceId,
          'roomNumber': inv.roomNumber,
          'qrCode': inv.activeQrCode,
          'expiresAt': inv.qrExpiresAt!.toIso8601String(),
        }));
  }

  /// Simulasi keterlambatan +1 hari untuk demo FR-04 (Denda Rp50.000 / hari)
  void simulateAddLateDay(String invoiceId) {
    final inv = _invoices.firstWhere((i) => i.id == invoiceId);
    if (inv.status == InvoiceStatus.paid) return;
    inv.status = InvoiceStatus.overdue;
    inv.lateDays += 1;
    inv.dueDate = DateTime.now().subtract(Duration(days: inv.lateDays));
    inv.activeQrCode = null;
    inv.qrExpiresAt = null;

    _notifications.insert(
      0,
      AppNotification(
        id: 'NTF-LATE-${DateTime.now().microsecondsSinceEpoch}',
        targetAudience: inv.tenantId,
        channel: 'SISTEM & EMAIL',
        title: 'Status Tagihan Terlambat (${inv.lateDays} Hari)',
        message:
            'Tagihan Kamar ${inv.roomNumber} terlambat ${inv.lateDays} hari. Denda akumulasi: ${AppFormatters.currency(inv.lateFeeSubtotal)} (Rp50.000/hari). Buat QR baru untuk membayar.',
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    _syncRemote(
      () => apiClient.postJson('/invoices/simulate-late', {
        'invoiceId': invoiceId,
        'roomNumber': inv.roomNumber,
      }),
    );
  }

  /// FR-08: Pembayaran tagihan via webhook gateway berhasil -> status otomatis Lunas & terbitkan tagihan masa sewa berikutnya (FR-01).
  /// Aman terhadap webhook ganda (Idempotent).
  void payInvoice(String invoiceId) {
    if (_processedWebhookKeys.contains('INVOICE:$invoiceId')) return;
    final inv = _invoices.firstWhere((i) => i.id == invoiceId);
    if (inv.status == InvoiceStatus.paid) return;
    _processedWebhookKeys.add('INVOICE:$invoiceId');

    final now = DateTime.now();
    inv.status = InvoiceStatus.paid;
    inv.paidAt = now;

    // Simpan ke riwayat pembayaran (FR-09)
    _payments.insert(
      0,
      PaymentRecord(
        id: 'PAY-${now.microsecondsSinceEpoch.toString().substring(8)}',
        tenantId: inv.tenantId,
        tenantName: inv.tenantName,
        roomNumber: inv.roomNumber,
        type: 'Tagihan Sewa (${inv.selectedMonths} Bulan)',
        months: inv.selectedMonths,
        roomCost: inv.roomSubtotal,
        waterCost: inv.waterSubtotal,
        transactionFee: inv.transactionFee,
        lateFee: inv.lateFeeSubtotal,
        totalAmount: inv.totalAmount,
        paidAt: now,
        gatewayReference:
            'GW-QRINV-${now.microsecondsSinceEpoch.toString().substring(7)}',
      ),
    );

    // Perpanjang masa sewa penghuni & jadwalkan tagihan berikutnya di akhir masa sewa (FR-01)
    final tenantIdx = _tenants.indexWhere((t) => t.id == inv.tenantId);
    DateTime nextDueDate = now.add(Duration(days: 30 * inv.selectedMonths));
    if (tenantIdx != -1) {
      final baseDate = _tenants[tenantIdx].leaseEndDate.isAfter(now)
          ? _tenants[tenantIdx].leaseEndDate
          : now;
      nextDueDate = baseDate.add(Duration(days: 30 * inv.selectedMonths));
      _tenants[tenantIdx].leaseEndDate = nextDueDate;
    }

    _invoices.insert(
      0,
      Invoice(
        id: 'INV-NEXT-${now.microsecondsSinceEpoch.toString().substring(9)}',
        tenantId: inv.tenantId,
        tenantName: inv.tenantName,
        roomNumber: inv.roomNumber,
        roomPricePerMonth: inv.roomPricePerMonth,
        selectedMonths: 1,
        dueDate: nextDueDate,
        status: InvoiceStatus.unpaid,
      ),
    );

    _notifications.insert(
      0,
      AppNotification(
        id: 'NTF-PAID-${now.microsecondsSinceEpoch}',
        targetAudience: inv.tenantId,
        channel: 'SISTEM & EMAIL',
        title: 'Pembayaran Tagihan Lunas',
        message:
            'Terima kasih! Pembayaran tagihan Kamar ${inv.roomNumber} (${inv.selectedMonths} bulan) sebesar ${AppFormatters.currency(inv.totalAmount)} telah diterima. Tagihan berikutnya jatuh tempo pada ${AppFormatters.date(nextDueDate)}.',
        createdAt: now,
      ),
    );

    notifyListeners();
    _syncRemote(
      () => apiClient.postJson('/invoices/pay', {
        'invoiceId': invoiceId,
        'roomNumber': inv.roomNumber,
      }),
    );
  }

  /// FR-05: Pengingat H-3, H-2, H-1, saat jatuh tempo, dan saat terlambat lewat notifikasi sistem & email.
  int triggerScheduledReminders() {
    int count = 0;
    final now = DateTime.now();
    for (final inv in unpaidOrOverdueInvoices) {
      final diffDays = inv.dueDate.difference(now).inDays;
      String tag;
      if (inv.status == InvoiceStatus.overdue || diffDays < 0) {
        tag = 'Terlambat (${inv.lateDays} hari)';
      } else if (diffDays == 0) {
        tag = 'Hari Jatuh Tempo (H-0)';
      } else if (diffDays == 1) {
        tag = 'H-1';
      } else if (diffDays == 2) {
        tag = 'H-2';
      } else {
        tag = 'H-3';
      }

      if (!inv.sentReminders.contains(tag)) {
        inv.sentReminders.add(tag);
      }

      _notifications.insert(
        0,
        AppNotification(
          id: 'NTF-REM-${now.microsecondsSinceEpoch}-$count',
          targetAudience: inv.tenantId,
          channel: 'SISTEM & EMAIL',
          title: 'Pengingat Tagihan [$tag] - Kamar ${inv.roomNumber}',
          message:
              'Halo ${inv.tenantName}, pengingat pembayaran sewa Kamar ${inv.roomNumber} dengan total sementara ${AppFormatters.currency(inv.totalAmount)}. Mohon bayar tepat waktu melalui QRIS aplikasi.',
          createdAt: now,
        ),
      );
      count++;
    }
    notifyListeners();
    _syncRemote(() => apiClient.postJson('/reminders/trigger', {}));
    return count;
  }

  // ==================== KEUANGAN: PENGELUARAN (FR-11) ====================
  void addExpense({
    required String title,
    required String category,
    required int amount,
    required String notes,
  }) {
    final exp = ExpenseRecord(
      id: 'EXP-${DateTime.now().microsecondsSinceEpoch.toString().substring(8)}',
      title: title.trim(),
      category: category,
      amount: amount,
      date: DateTime.now(),
      notes: notes.trim(),
    );
    _expenses.insert(0, exp);
    notifyListeners();
    _syncRemote(() => apiClient.postJson('/expenses', {
          'id': exp.id,
          'title': exp.title,
          'category': exp.category,
          'amount': exp.amount,
          'date': exp.date.toIso8601String(),
          'notes': exp.notes,
        }));
  }

  // ==================== KELOLA KAMAR & PENGHUNI (FR-18 s.d. FR-22) ====================
  void updateRoom({
    required String roomId,
    required String number,
    required int floor,
    required int pricePerMonth,
    required RoomGender gender,
    required List<String> facilities,
  }) {
    final room = _rooms.firstWhere((r) => r.id == roomId);
    room.number = number.trim();
    room.floor = floor;
    room.pricePerMonth = pricePerMonth;
    room.gender = gender;
    room.facilities = facilities;
    notifyListeners();
    _syncRemote(() => apiClient.putJson('/rooms', {
          'id': room.id,
          'number': room.number,
          'floor': room.floor,
          'pricePerMonth': room.pricePerMonth,
          'gender': room.gender.name,
          'facilities': room.facilities,
        }));
  }

  /// FR-19: Admin menambah penghuni secara manual (mis. untuk penghuni lama sebelum aplikasi ada)
  void addTenantByAdmin({
    required String fullName,
    required String phone,
    required String email,
    required String originAddress,
    required String parentName,
    required String parentPhone,
    required String password,
    required String ktpNumber,
    required String roomId,
    required int monthsPaid,
  }) {
    final now = DateTime.now();
    final room = _rooms.firstWhere((r) => r.id == roomId);
    final tenantId =
        'TNT-${now.microsecondsSinceEpoch.toString().substring(9)}';

    final tenant = Tenant(
      id: tenantId,
      fullName: fullName.trim(),
      phone: phone.trim(),
      email: email.trim(),
      originAddress: originAddress.trim(),
      parentName: parentName.trim(),
      parentPhone: parentPhone.trim(),
      password: PasswordSecurity.hashPassword(password),
      ktpNumber: ktpNumber.trim(),
      ktpFileName:
          'ktp_${fullName.trim().toLowerCase().replaceAll(" ", "_")}.jpg',
      ktpConsentAccepted: true,
      roomId: room.id,
      roomNumberSnapshot: room.number,
      isActive: true,
      leaseStartDate: now,
      leaseEndDate: now.add(Duration(days: 30 * monthsPaid)),
    );

    _tenants.insert(0, tenant);
    _occupyRoom(room.id, tenant.id);

    // Buat jadwal tagihan berikutnya
    _invoices.insert(
      0,
      Invoice(
        id: 'INV-${now.microsecondsSinceEpoch.toString().substring(8)}',
        tenantId: tenant.id,
        tenantName: tenant.fullName,
        roomNumber: room.number,
        roomPricePerMonth: room.pricePerMonth,
        selectedMonths: 1,
        dueDate: tenant.leaseEndDate,
        status: InvoiceStatus.unpaid,
      ),
    );

    notifyListeners();
    _syncRemote(() => apiClient.postJson('/tenants', {
          'id': tenant.id,
          'fullName': tenant.fullName,
          'phone': tenant.phone,
          'email': tenant.email,
          'originAddress': tenant.originAddress,
          'parentName': tenant.parentName,
          'parentPhone': tenant.parentPhone,
          'passwordHash': tenant.password,
          'ktpNumber': tenant.ktpNumber,
          'ktpFileName': tenant.ktpFileName,
          'roomId': roomId,
          'monthsPaid': monthsPaid,
        }));
  }

  /// FR-19: Admin mengubah data penghuni (penghuni tidak bisa mengubah sendiri)
  void updateTenantByAdmin({
    required String tenantId,
    required String fullName,
    required String phone,
    required String email,
    required String originAddress,
    required String parentName,
    required String parentPhone,
    required String ktpNumber,
  }) {
    final tenant = _tenants.firstWhere((t) => t.id == tenantId);
    tenant.fullName = fullName.trim();
    tenant.phone = phone.trim();
    tenant.email = email.trim();
    tenant.originAddress = originAddress.trim();
    tenant.parentName = parentName.trim();
    tenant.parentPhone = parentPhone.trim();
    tenant.ktpNumber = ktpNumber.trim();
    notifyListeners();
    _syncRemote(() => apiClient.putJson('/tenants', {
          'id': tenant.id,
          'fullName': tenant.fullName,
          'phone': tenant.phone,
          'email': tenant.email,
          'originAddress': tenant.originAddress,
          'parentName': tenant.parentName,
          'parentPhone': tenant.parentPhone,
          'ktpNumber': tenant.ktpNumber,
        }));
  }

  /// FR-22: Admin mereset kata sandi penghuni (disimpan ter-hash NFR-02)
  void resetTenantPassword(String tenantId, String newPassword) {
    final tenant = _tenants.firstWhere((t) => t.id == tenantId);
    tenant.password = PasswordSecurity.hashPassword(newPassword);
    _notifications.insert(
      0,
      AppNotification(
        id: 'NTF-PWD-${DateTime.now().microsecondsSinceEpoch}',
        targetAudience: tenant.id,
        channel: 'SISTEM & EMAIL',
        title: 'Kata Sandi Direset oleh Admin',
        message:
            'Kata sandi akun Estopa Kos Anda telah direset oleh Admin sesuai permintaan.',
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    _syncRemote(() => apiClient.postJson('/tenants/reset-password', {
          'tenantId': tenantId,
          'passwordHash': tenant.password,
        }));
  }

  /// FR-21 & NFR-07: Saat admin mengosongkan kamar, akun penghuni sebelumnya nonaktif & tidak bisa login,
  /// namun riwayat pembayaran dan keluhan tetap tersimpan.
  void vacateRoom(String roomId) {
    final room = _rooms.firstWhere((r) => r.id == roomId);
    final oldTenantId = room.currentTenantId;

    room.status = RoomStatus.available;
    room.currentTenantId = null;
    room.holdExpiresAt = null;

    if (oldTenantId != null) {
      final tenantIdx = _tenants.indexWhere((t) => t.id == oldTenantId);
      if (tenantIdx != -1) {
        _tenants[tenantIdx].isActive = false;
        _tenants[tenantIdx].roomId = null;
        _tenants[tenantIdx].roomNumberSnapshot =
            '${room.number} (Sudah Keluar)';
      }
      _invoices.removeWhere(
        (inv) =>
            inv.tenantId == oldTenantId && inv.status != InvoiceStatus.paid,
      );
    }

    notifyListeners();
    _syncRemote(() => apiClient.postJson('/rooms/vacate', {'roomId': roomId}));
  }

  // ==================== LAPORAN KELUHAN (FR-23 s.d. FR-25) ====================
  void createComplaint({
    required Tenant tenant,
    required String category,
    required String description,
    String? attachmentName,
  }) {
    final now = DateTime.now();
    final cmp = Complaint(
      id: 'CMP-${now.microsecondsSinceEpoch.toString().substring(8)}',
      tenantId: tenant.id,
      tenantName: tenant.fullName,
      roomNumber: tenant.roomNumberSnapshot,
      category: category,
      description: description.trim(),
      attachmentName: attachmentName,
      createdAt: now,
      status: ComplaintStatus.submitted,
    );
    _complaints.insert(0, cmp);

    // Notifikasi ke Admin (FR-24)
    _notifications.insert(
      0,
      AppNotification(
        id: 'NTF-CMP-${now.microsecondsSinceEpoch}',
        targetAudience: 'ADMIN',
        channel: 'SISTEM',
        title: 'Keluhan Baru Kamar ${tenant.roomNumberSnapshot} ($category)',
        message: '${tenant.fullName}: "${description.trim()}"',
        createdAt: now,
      ),
    );
    notifyListeners();
    _syncRemote(() => apiClient.postJson('/complaints', {
          'id': cmp.id,
          'tenantId': cmp.tenantId,
          'tenantName': cmp.tenantName,
          'roomNumber': cmp.roomNumber,
          'category': cmp.category,
          'description': cmp.description,
          'attachmentName': cmp.attachmentName,
          'createdAt': cmp.createdAt.toIso8601String(),
        }));
  }

  void updateComplaintStatus({
    required String complaintId,
    required ComplaintStatus newStatus,
    String? adminNote,
  }) {
    final cmp = _complaints.firstWhere((c) => c.id == complaintId);
    cmp.status = newStatus;
    if (adminNote != null && adminNote.trim().isNotEmpty) {
      cmp.adminNote = adminNote.trim();
    }

    // FR-25: Penghuni menerima notifikasi saat status keluhan berubah
    _notifications.insert(
      0,
      AppNotification(
        id: 'NTF-CMPUPD-${DateTime.now().microsecondsSinceEpoch}',
        targetAudience: cmp.tenantId,
        channel: 'SISTEM & EMAIL',
        title: 'Status Keluhan Diperbarui: ${cmp.statusLabel}',
        message:
            'Keluhan "${cmp.category}" Anda kini berstatus ${cmp.statusLabel}.${cmp.adminNote != null ? " Catatan Admin: ${cmp.adminNote}" : ""}',
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    _syncRemote(() => apiClient.patchJson('/complaints/status', {
          'complaintId': cmp.id,
          'tenantId': cmp.tenantId,
          'category': cmp.category,
          'status': cmp.status.name,
          'statusLabel': cmp.statusLabel,
          'adminNote': cmp.adminNote,
        }));
  }

  // ==================== PENGUMUMAN (FR-26 s.d. FR-28) ====================
  void createAnnouncement({
    required String title,
    required String content,
  }) {
    final now = DateTime.now();
    final ann = Announcement(
      id: 'ANN-${now.microsecondsSinceEpoch.toString().substring(8)}',
      title: title.trim(),
      content: content.trim(),
      createdAt: now,
    );
    _announcements.insert(0, ann);

    // FR-27: Kirim notifikasi ke seluruh penghuni aktif
    for (final t in _tenants.where((t) => t.isActive)) {
      _notifications.insert(
        0,
        AppNotification(
          id: 'NTF-ANN-${now.microsecondsSinceEpoch}-${t.id}',
          targetAudience: t.id,
          channel: 'SISTEM & EMAIL',
          title: 'Pengumuman Baru: ${ann.title}',
          message: ann.content,
          createdAt: now,
        ),
      );
    }
    notifyListeners();
    _syncRemote(() => apiClient.postJson('/announcements', {
          'id': ann.id,
          'title': ann.title,
          'content': ann.content,
          'createdAt': ann.createdAt.toIso8601String(),
        }));
  }

  /// FR-28: Penghuni membaca pengumuman dan status "Sudah dibaca" tercatat
  void markAnnouncementRead(String announcementId, String tenantId) {
    final ann = _announcements.firstWhere((a) => a.id == announcementId);
    if (!ann.readByTenantIds.contains(tenantId)) {
      ann.readByTenantIds.add(tenantId);
      notifyListeners();
      _syncRemote(() => apiClient.postJson('/announcements/read', {
            'announcementId': announcementId,
            'tenantId': tenantId,
          }));
    }
  }
}
