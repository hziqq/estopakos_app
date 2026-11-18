enum UserRole { admin, tenant }

enum RoomGender { putra, putri }

enum RoomStatus { available, held, occupied }

enum InvoiceStatus { unpaid, overdue, paid }

enum ComplaintStatus { submitted, inProgress, resolved }

class CostConstants {
  static const int waterFeePerMonth = 35000;
  static const int transactionFee = 4000;
  static const int lateFeePerDay = 50000;
  static const int bookingHoldMinutes = 20;
  static const int invoiceQrValidHours = 24;

  static int calculateTotal({
    required int roomPricePerMonth,
    required int months,
    int lateDays = 0,
  }) {
    final roomCost = roomPricePerMonth * months;
    final waterCost = waterFeePerMonth * months;
    final fineCost = lateDays > 0 ? lateFeePerDay * lateDays : 0;
    return roomCost + waterCost + transactionFee + fineCost;
  }
}

class Room {
  final String id;
  String number;
  int floor;
  int pricePerMonth;
  List<String> facilities;
  RoomGender gender;
  String? photoUrl;
  RoomStatus status;
  String? currentTenantId;
  DateTime? holdExpiresAt;

  Room({
    required this.id,
    required this.number,
    required this.floor,
    required this.pricePerMonth,
    required this.facilities,
    required this.gender,
    this.photoUrl,
    this.status = RoomStatus.available,
    this.currentTenantId,
    this.holdExpiresAt,
  });

  bool get isLargeRoom =>
      facilities.contains('Kamar Besar') || pricePerMonth >= 1500000;

  String get effectivePhotoAsset =>
      (photoUrl != null && photoUrl!.isNotEmpty)
          ? photoUrl!
          : (isLargeRoom
              ? 'assets/images/kamar_besar_ac.jpg'
              : 'assets/images/kamar_kecil.jpg');

  String get genderLabel => gender == RoomGender.putra ? 'Putra' : 'Putri';

  String get statusLabel {
    switch (status) {
      case RoomStatus.available:
        return 'Kosong';
      case RoomStatus.held:
        return 'Ditahan (20m)';
      case RoomStatus.occupied:
        return 'Terisi';
    }
  }
}

class Tenant {
  final String id;
  String fullName;
  String phone;
  String email;
  String originAddress;
  String parentName;
  String parentPhone;
  String password;
  String ktpNumber;
  String ktpFileName;
  String? ktpImageBase64;
  bool ktpConsentAccepted;
  String? roomId;
  String roomNumberSnapshot;
  bool isActive;
  DateTime leaseStartDate;
  DateTime leaseEndDate;

  Tenant({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.originAddress,
    required this.parentName,
    required this.parentPhone,
    required this.password,
    required this.ktpNumber,
    required this.ktpFileName,
    this.ktpImageBase64,
    required this.ktpConsentAccepted,
    required this.roomId,
    required this.roomNumberSnapshot,
    required this.isActive,
    required this.leaseStartDate,
    required this.leaseEndDate,
  });
}

class BookingHold {
  final String id;
  final String roomId;
  final String roomNumber;
  final int roomPricePerMonth;
  final int months;
  final String fullName;
  final String phone;
  final String email;
  final String originAddress;
  final String parentName;
  final String parentPhone;
  final String password;
  final String ktpNumber;
  final String ktpFileName;
  final String? ktpImageBase64;
  final bool ktpConsent;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String qrPayload;
  bool isExpired;
  bool isPaid;

  BookingHold({
    required this.id,
    required this.roomId,
    required this.roomNumber,
    required this.roomPricePerMonth,
    required this.months,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.originAddress,
    required this.parentName,
    required this.parentPhone,
    required this.password,
    required this.ktpNumber,
    required this.ktpFileName,
    this.ktpImageBase64,
    required this.ktpConsent,
    required this.createdAt,
    required this.expiresAt,
    required this.qrPayload,
    this.isExpired = false,
    this.isPaid = false,
  });

  int get roomSubtotal => roomPricePerMonth * months;
  int get waterSubtotal => CostConstants.waterFeePerMonth * months;
  int get transactionFee => CostConstants.transactionFee;
  int get totalAmount => CostConstants.calculateTotal(
        roomPricePerMonth: roomPricePerMonth,
        months: months,
      );
}

class Invoice {
  final String id;
  final String tenantId;
  final String tenantName;
  final String roomNumber;
  final int roomPricePerMonth;
  int selectedMonths;
  DateTime dueDate;
  InvoiceStatus status;
  int lateDays;
  String? activeQrCode;
  DateTime? qrExpiresAt;
  DateTime? paidAt;
  List<String> sentReminders;

  Invoice({
    required this.id,
    required this.tenantId,
    required this.tenantName,
    required this.roomNumber,
    required this.roomPricePerMonth,
    this.selectedMonths = 1,
    required this.dueDate,
    this.status = InvoiceStatus.unpaid,
    this.lateDays = 0,
    this.activeQrCode,
    this.qrExpiresAt,
    this.paidAt,
    List<String>? sentReminders,
  }) : sentReminders = sentReminders ?? [];

  int get roomSubtotal => roomPricePerMonth * selectedMonths;
  int get waterSubtotal => CostConstants.waterFeePerMonth * selectedMonths;
  int get transactionFee => CostConstants.transactionFee;
  int get lateFeeSubtotal =>
      status == InvoiceStatus.overdue && lateDays > 0
          ? CostConstants.lateFeePerDay * lateDays
          : 0;

  int get totalAmount => CostConstants.calculateTotal(
        roomPricePerMonth: roomPricePerMonth,
        months: selectedMonths,
        lateDays: status == InvoiceStatus.overdue ? lateDays : 0,
      );

  String get statusLabel {
    switch (status) {
      case InvoiceStatus.unpaid:
        return 'Belum Bayar';
      case InvoiceStatus.overdue:
        return 'Terlambat ($lateDays hari)';
      case InvoiceStatus.paid:
        return 'Lunas';
    }
  }
}

class PaymentRecord {
  final String id;
  final String tenantId;
  final String tenantName;
  final String roomNumber;
  final String type; // 'Pemesanan Awal' atau 'Tagihan Sewa'
  final int months;
  final int roomCost;
  final int waterCost;
  final int transactionFee;
  final int lateFee;
  final int totalAmount;
  final DateTime paidAt;
  final String gatewayReference;

  PaymentRecord({
    required this.id,
    required this.tenantId,
    required this.tenantName,
    required this.roomNumber,
    required this.type,
    required this.months,
    required this.roomCost,
    required this.waterCost,
    required this.transactionFee,
    required this.lateFee,
    required this.totalAmount,
    required this.paidAt,
    required this.gatewayReference,
  });
}

class ExpenseRecord {
  final String id;
  final String title;
  final String category;
  final int amount;
  final DateTime date;
  final String notes;

  ExpenseRecord({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.notes,
  });
}

class Complaint {
  final String id;
  final String tenantId;
  final String tenantName;
  final String roomNumber;
  final String category;
  final String description;
  final String? attachmentName;
  final DateTime createdAt;
  ComplaintStatus status;
  String? adminNote;

  Complaint({
    required this.id,
    required this.tenantId,
    required this.tenantName,
    required this.roomNumber,
    required this.category,
    required this.description,
    this.attachmentName,
    required this.createdAt,
    this.status = ComplaintStatus.submitted,
    this.adminNote,
  });

  String get statusLabel {
    switch (status) {
      case ComplaintStatus.submitted:
        return 'Masuk';
      case ComplaintStatus.inProgress:
        return 'Diproses';
      case ComplaintStatus.resolved:
        return 'Selesai';
    }
  }
}

class Announcement {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final List<String> readByTenantIds;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    List<String>? readByTenantIds,
  }) : readByTenantIds = readByTenantIds ?? [];
}

class AppNotification {
  final String id;
  final String targetAudience; // 'ADMIN', atau tenantId
  final String channel; // 'SISTEM', 'EMAIL', 'SISTEM & EMAIL'
  final String title;
  final String message;
  final DateTime createdAt;
  bool isRead;

  AppNotification({
    required this.id,
    required this.targetAudience,
    required this.channel,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });
}
