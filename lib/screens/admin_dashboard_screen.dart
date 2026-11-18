import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/estopa_store.dart';
import '../utils/formatters.dart';
import '../widgets/receipt_dialog.dart';

class AdminDashboardScreen extends StatefulWidget {
  final EstopaStore store;

  const AdminDashboardScreen({super.key, required this.store});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final pages = [
          _AdminBillingAndFinanceTab(store: widget.store),
          _AdminTenantsAndRoomsTab(store: widget.store),
          _AdminComplaintsTab(store: widget.store),
          _AdminAnnouncementsAndNotifTab(store: widget.store),
        ];

        final unpaidCount = widget.store.unpaidOrOverdueInvoices.length;
        final openComplaints = widget.store.complaints
            .where((c) => c.status != ComplaintStatus.resolved)
            .length;

        return Scaffold(
          appBar: AppBar(
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Panel Admin Estopa Kos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Pemilik / Pengelola • 39 Kamar (4 Lantai)',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Keluar Admin',
                onPressed: () {
                  widget.store.logout();
                  Navigator.popUntil(context, (r) => r.isFirst);
                },
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: pages[_selectedIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (idx) =>
                setState(() => _selectedIndex = idx),
            destinations: [
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: unpaidCount > 0,
                  label: Text('$unpaidCount'),
                  child: const Icon(Icons.account_balance_wallet_outlined),
                ),
                selectedIcon: const Icon(Icons.account_balance_wallet),
                label: 'Tagihan & Dana Masuk',
              ),
              const NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: 'Penghuni & Kamar',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: openComplaints > 0,
                  label: Text('$openComplaints'),
                  child: const Icon(Icons.handyman_outlined),
                ),
                selectedIcon: const Icon(Icons.handyman),
                label: 'Keluhan',
              ),
              const NavigationDestination(
                icon: Icon(Icons.campaign_outlined),
                selectedIcon: Icon(Icons.campaign),
                label: 'Pengumuman',
              ),
            ],
          ),
        );
      },
    );
  }
}

// ==================== TAB 1: TAGIHAN, PENGINGAT & PENCATATAN DANA MASUK ====================
class _AdminBillingAndFinanceTab extends StatefulWidget {
  final EstopaStore store;

  const _AdminBillingAndFinanceTab({required this.store});

  @override
  State<_AdminBillingAndFinanceTab> createState() =>
      _AdminBillingAndFinanceTabState();
}

class _AdminBillingAndFinanceTabState
    extends State<_AdminBillingAndFinanceTab> {
  String _selectedSourceFilter = 'ALL'; // ALL, BOOKING, ROUTINE

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final unpaidList = store.unpaidOrOverdueInvoices;
    final totalWaterCollected =
        store.payments.fold(0, (sum, p) => sum + p.waterCost);
    final totalRoomCollected =
        store.payments.fold(0, (sum, p) => sum + p.roomCost);
    final totalLateFeeCollected =
        store.payments.fold(0, (sum, p) => sum + p.lateFee);

    final bookingPayments = store.payments
        .where((p) => p.type.toLowerCase().contains('pemesanan'))
        .toList();
    final routinePayments = store.payments
        .where((p) => !p.type.toLowerCase().contains('pemesanan'))
        .toList();

    final bookingIncome =
        bookingPayments.fold(0, (sum, p) => sum + p.totalAmount);
    final routineIncome =
        routinePayments.fold(0, (sum, p) => sum + p.totalAmount);

    final filteredPayments = store.payments.where((p) {
      final isBooking = p.type.toLowerCase().contains('pemesanan');
      if (_selectedSourceFilter == 'BOOKING') return isBooking;
      if (_selectedSourceFilter == 'ROUTINE') return !isBooking;
      return true;
    }).toList();

    final occupiedCount =
        store.rooms.where((r) => r.status == RoomStatus.occupied).length;
    final heldCount =
        store.rooms.where((r) => r.status == RoomStatus.held).length;
    final availCount = store.availableRooms.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Ringkasan Pencatatan Dana Masuk & Sumber Dana (FR-09 & FR-10)
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.primaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.trending_up, size: 20, color: Color(0xFF0F6B58)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Rekap Dana Masuk & Sumber Pemasukan Kos',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricBox(
                        label: 'Total Dana Masuk',
                        value: AppFormatters.currency(store.totalIncome),
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricBox(
                        label: 'Dari Pemesanan Baru',
                        value: AppFormatters.currency(bookingIncome),
                        color: Colors.teal.shade800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricBox(
                        label: 'Dari Tagihan Rutin',
                        value: AppFormatters.currency(routineIncome),
                        color: Colors.indigo.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _MetricBox(
                        label: 'Komponen Sewa Kamar',
                        value: AppFormatters.currency(totalRoomCollected),
                        color: Colors.teal.shade900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricBox(
                        label: 'Komponen Biaya Air',
                        value: AppFormatters.currency(totalWaterCollected),
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricBox(
                        label: 'Hunian (39 Kamar)',
                        value: '$occupiedCount Terisi • $availCount Kosong'
                            '${heldCount > 0 ? " ($heldCount Hold)" : ""}',
                        color: Colors.deepPurple.shade800,
                      ),
                    ),
                  ],
                ),
                if (totalLateFeeCollected > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Dana Masuk dari Denda Keterlambatan: ${AppFormatters.currency(totalLateFeeCollected)}',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Daftar Penghuni Belum Bayar / Terlambat (FR-07 & FR-05)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Daftar Belum Bayar & Terlambat (${unpaidList.length}) - FR-07',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                final sent = store.triggerScheduledReminders();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Pengingat terjadwal (H-3/H-2/H-1/Jatuh Tempo/Terlambat) dikirim via Sistem & Email ke $sent penghuni (FR-05).',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.notifications_active_outlined, size: 16),
              label: const Text('Kirim Pengingat'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (unpaidList.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Semua tagihan penghuni saat ini sudah Lunas!'),
            ),
          )
        else
          for (final inv in unpaidList)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Kamar ${inv.roomNumber} • ${inv.tenantName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: inv.status == InvoiceStatus.overdue
                            ? Colors.red.shade100
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        inv.statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: inv.status == InvoiceStatus.overdue
                              ? Colors.red.shade900
                              : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      'Jatuh Tempo: ${AppFormatters.date(inv.dueDate)} • Total: ${AppFormatters.currency(inv.totalAmount)}'
                      '${inv.lateFeeSubtotal > 0 ? " (Termasuk Denda ${AppFormatters.currency(inv.lateFeeSubtotal)})" : ""}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Pengingat terkirim: ${inv.sentReminders.isEmpty ? "-" : inv.sentReminders.join(", ")}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () => store.simulateAddLateDay(inv.id),
                          icon: const Icon(Icons.add_alarm, size: 16),
                          label: const Text('Simulasi +1 Hari Terlambat'),
                        ),
                        FilledButton.tonal(
                          onPressed: () => store.payInvoice(inv.id),
                          child: const Text('Simulasi Lunas Webhook'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

        const SizedBox(height: 18),
        const Text(
          'Pencatatan Dana Masuk & Informasi Asal Dana (FR-09 & FR-10)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text('Semua (${store.payments.length})'),
              selected: _selectedSourceFilter == 'ALL',
              onSelected: (_) => setState(() => _selectedSourceFilter = 'ALL'),
            ),
            ChoiceChip(
              label: Text('Pemesanan Awal (${bookingPayments.length})'),
              selected: _selectedSourceFilter == 'BOOKING',
              onSelected: (_) =>
                  setState(() => _selectedSourceFilter = 'BOOKING'),
            ),
            ChoiceChip(
              label: Text('Tagihan Rutin (${routinePayments.length})'),
              selected: _selectedSourceFilter == 'ROUTINE',
              onSelected: (_) =>
                  setState(() => _selectedSourceFilter = 'ROUTINE'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final p in filteredPayments)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => PaymentReceiptDialog.show(context, p),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.south_west,
                            color: Colors.green.shade700,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${p.tenantName} • Kamar ${p.roomNumber}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Sumber Dana: ${p.type}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.teal.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '+ ${AppFormatters.currency(p.totalAmount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.green.shade800,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: p.type
                                        .toLowerCase()
                                        .contains('pemesanan')
                                    ? Colors.teal.shade50
                                    : Colors.indigo.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                p.type.toLowerCase().contains('pemesanan')
                                    ? 'PEMESANAN AWAL'
                                    : 'TAGIHAN RUTIN',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: p.type
                                          .toLowerCase()
                                          .contains('pemesanan')
                                      ? Colors.teal.shade900
                                      : Colors.indigo.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Text(
                      'Rincian Asal Dana: Sewa Kamar (${p.months} bln) ${AppFormatters.currency(p.roomCost)} + Air ${AppFormatters.currency(p.waterCost)} + Biaya Transaksi ${AppFormatters.currency(p.transactionFee)}'
                      '${p.lateFee > 0 ? " + Denda ${AppFormatters.currency(p.lateFee)}" : ""}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Waktu Masuk: ${AppFormatters.dateTime(p.paidAt)} • Order ID: ${p.gatewayReference}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.receipt_long_outlined,
                          size: 16,
                          color: Colors.black45,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== TAB 2: KELOLA PENGHUNI & 39 KAMAR (FR-18 s.d. FR-22) ====================
class _AdminTenantsAndRoomsTab extends StatefulWidget {
  final EstopaStore store;

  const _AdminTenantsAndRoomsTab({required this.store});

  @override
  State<_AdminTenantsAndRoomsTab> createState() =>
      _AdminTenantsAndRoomsTabState();
}

class _AdminTenantsAndRoomsTabState extends State<_AdminTenantsAndRoomsTab> {
  String _searchQuery = '';
  bool _showRoomsView = false;

  void _showAddTenantModal(BuildContext context) {
    final availRooms = widget.store.availableRooms;
    if (availRooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada kamar kosong tersedia.')),
      );
      return;
    }

    String selectedRoomId = availRooms.first.id;
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final parentNameCtrl = TextEditingController();
    final parentPhoneCtrl = TextEditingController();
    final ktpCtrl = TextEditingController();
    final pwdCtrl = TextEditingController(text: 'password123');
    int monthsPaid = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Tambah Penghuni Baru / Lama (FR-19)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedRoomId,
                  decoration: const InputDecoration(labelText: 'Pilih Kamar Kosong'),
                  items: availRooms
                      .map(
                        (r) => DropdownMenuItem(
                          value: r.id,
                          child: Text(
                            'Kamar ${r.number} (${r.genderLabel} - ${AppFormatters.currency(r.pricePerMonth)})',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedRoomId = v);
                  },
                ),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                ),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Nomor HP'),
                ),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: ktpCtrl,
                  decoration: const InputDecoration(labelText: 'NIK KTP'),
                ),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Alamat Asal'),
                ),
                TextField(
                  controller: parentNameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Orang Tua'),
                ),
                TextField(
                  controller: parentPhoneCtrl,
                  decoration: const InputDecoration(labelText: 'HP Orang Tua'),
                ),
                TextField(
                  controller: pwdCtrl,
                  decoration: const InputDecoration(labelText: 'Password Awal'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty ||
                    phoneCtrl.text.trim().isEmpty) {
                  return;
                }
                widget.store.addTenantByAdmin(
                  fullName: nameCtrl.text,
                  phone: phoneCtrl.text,
                  email: emailCtrl.text.isEmpty
                      ? 'penghuni@estopakos.id'
                      : emailCtrl.text,
                  originAddress: addressCtrl.text,
                  parentName: parentNameCtrl.text,
                  parentPhone: parentPhoneCtrl.text,
                  password: pwdCtrl.text,
                  ktpNumber: ktpCtrl.text.isEmpty ? '1271000000000001' : ktpCtrl.text,
                  roomId: selectedRoomId,
                  monthsPaid: monthsPaid,
                );
                Navigator.pop(ctx);
              },
              child: const Text('Simpan & Aktifkan Akun'),
            ),
          ],
        ),
      ),
    );
  }

  Uint8List? _decodeKtpBytes(String? ktpImageBase64) {
    if (ktpImageBase64 == null || ktpImageBase64.trim().isEmpty) return null;
    try {
      var raw = ktpImageBase64.trim();
      final commaIdx = raw.indexOf(',');
      if (raw.startsWith('data:') && commaIdx != -1) {
        raw = raw.substring(commaIdx + 1);
      }
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  void _showFullScreenKtp(
    BuildContext context,
    Uint8List bytes,
    String ownerName,
    String ktpNumber,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(
                'KTP $ownerName ($ktpNumber)',
                style: const TextStyle(fontSize: 14),
              ),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKtpPreviewSection(
    BuildContext context, {
    required String ownerName,
    required String ktpNumber,
    required String ktpFileName,
    required bool consentAccepted,
    String? ktpImageBase64,
  }) {
    final bytes = _decodeKtpBytes(ktpImageBase64);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.badge, size: 18, color: Colors.indigo),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Dokumen KTP Tersimpan (Hanya Admin - NFR-03)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'NIK: $ktpNumber\nFile: $ktpFileName\nPersetujuan Privasi: ${consentAccepted ? "Disetujui" : "Belum disetujui"}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          if (bytes != null) ...[
            GestureDetector(
              onTap: () => _showFullScreenKtp(
                context,
                bytes,
                ownerName,
                ktpNumber,
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 170,
                      width: 280,
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.zoom_in, size: 13, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Perbesar KTP',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Text(
                'Foto KTP belum berupa gambar (berasal dari data awal atau pemesanan tanpa lampiran gambar).',
                style: TextStyle(fontSize: 11, color: Colors.black87),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _showBookingHoldDetailDialog(BuildContext context, BookingHold hold) {
    final statusLabel = hold.isPaid
        ? 'Sudah Dibayar'
        : (hold.isExpired
              ? 'Kedaluwarsa'
              : 'Menunggu Pembayaran QRIS (s.d. ${AppFormatters.dateTime(hold.expiresAt)})');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Data Calon Penghuni: ${hold.fullName}'),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildKtpPreviewSection(
                context,
                ownerName: hold.fullName,
                ktpNumber: hold.ktpNumber,
                ktpFileName: hold.ktpFileName,
                consentAccepted: hold.ktpConsent,
                ktpImageBase64: hold.ktpImageBase64,
              ),
              const SizedBox(height: 12),
              _buildDetailInfoRow('Status Pesanan', statusLabel),
              _buildDetailInfoRow('Kamar Pilihan', 'Kamar ${hold.roomNumber}'),
              _buildDetailInfoRow('Durasi Sewa', '${hold.months} Bulan'),
              _buildDetailInfoRow(
                'Total Tagihan',
                AppFormatters.currency(hold.totalAmount),
              ),
              const Divider(height: 16),
              _buildDetailInfoRow('Nama Lengkap', hold.fullName),
              _buildDetailInfoRow('Nomor HP / WA', hold.phone),
              _buildDetailInfoRow('Email', hold.email),
              _buildDetailInfoRow('Alamat Asal', hold.originAddress),
              _buildDetailInfoRow('Nama Orang Tua', hold.parentName),
              _buildDetailInfoRow('No. HP Orang Tua', hold.parentPhone),
              _buildDetailInfoRow('NIK KTP', hold.ktpNumber),
              _buildDetailInfoRow(
                'Waktu Masuk Data',
                AppFormatters.dateTime(hold.createdAt),
              ),
            ],
          ),
        ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showTenantDetailAndActions(BuildContext context, Tenant tenant) {
    final nameCtrl = TextEditingController(text: tenant.fullName);
    final phoneCtrl = TextEditingController(text: tenant.phone);
    final emailCtrl = TextEditingController(text: tenant.email);
    final addressCtrl = TextEditingController(text: tenant.originAddress);
    final parentNameCtrl = TextEditingController(text: tenant.parentName);
    final parentPhoneCtrl = TextEditingController(text: tenant.parentPhone);
    final ktpCtrl = TextEditingController(text: tenant.ktpNumber);
    final newPwdCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Data Penghuni & KTP: ${tenant.fullName}'),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Kartu KTP yang hanya bisa diakses Admin (NFR-03)
              _buildKtpPreviewSection(
                context,
                ownerName: tenant.fullName,
                ktpNumber: tenant.ktpNumber,
                ktpFileName: tenant.ktpFileName,
                consentAccepted: tenant.ktpConsentAccepted,
                ktpImageBase64: tenant.ktpImageBase64,
              ),
              const SizedBox(height: 8),
              _buildDetailInfoRow(
                'Kamar',
                'Kamar ${tenant.roomNumberSnapshot} (${tenant.isActive ? "Aktif" : "Nonaktif"})',
              ),
              _buildDetailInfoRow(
                'Periode Sewa',
                '${AppFormatters.date(tenant.leaseStartDate)} s.d. ${AppFormatters.date(tenant.leaseEndDate)}',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Lengkap'),
              ),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Nomor HP'),
              ),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: ktpCtrl,
                decoration: const InputDecoration(labelText: 'NIK KTP'),
              ),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'Alamat Asal'),
              ),
              TextField(
                controller: parentNameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Orang Tua'),
              ),
              TextField(
                controller: parentPhoneCtrl,
                decoration: const InputDecoration(labelText: 'HP Orang Tua'),
              ),
              const Divider(height: 24),
              const Text(
                'Reset Kata Sandi Penghuni (FR-22)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: newPwdCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Password baru...',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      if (newPwdCtrl.text.trim().length < 4) return;
                      widget.store.resetTenantPassword(
                        tenant.id,
                        newPwdCtrl.text.trim(),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password penghuni berhasil direset!'),
                        ),
                      );
                    },
                    child: const Text('Reset Password'),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
        actions: [
          if (tenant.isActive && tenant.roomId != null)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                widget.store.vacateRoom(tenant.roomId!);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Kamar dikosongkan & akun penghuni otomatis dinonaktifkan (FR-21). Riwayat tetap tersimpan (NFR-07).',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.meeting_room_outlined, size: 16),
              label: const Text('Kosongkan Kamar (FR-21)'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          FilledButton(
            onPressed: () {
              widget.store.updateTenantByAdmin(
                tenantId: tenant.id,
                fullName: nameCtrl.text,
                phone: phoneCtrl.text,
                email: emailCtrl.text,
                originAddress: addressCtrl.text,
                parentName: parentNameCtrl.text,
                parentPhone: parentPhoneCtrl.text,
                ktpNumber: ktpCtrl.text,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Simpan Perubahan'),
          ),
        ],
      ),
    );
  }

  void _showEditRoomDialog(BuildContext context, Room room) {
    final numCtrl = TextEditingController(text: room.number);
    final priceCtrl = TextEditingController(text: room.pricePerMonth.toString());
    final facCtrl = TextEditingController(text: room.facilities.join(', '));
    int floor = room.floor;
    RoomGender gender = room.gender;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Kelola Kamar ${room.number} (FR-20)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: numCtrl,
                  decoration: const InputDecoration(labelText: 'Nomor Kamar'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: floor,
                  decoration: const InputDecoration(labelText: 'Lantai'),
                  items: [1, 2, 3, 4]
                      .map(
                        (f) => DropdownMenuItem(
                          value: f,
                          child: Text('Lantai $f'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => floor = v);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<RoomGender>(
                  initialValue: gender,
                  decoration: const InputDecoration(labelText: 'Jenis Kamar'),
                  items: const [
                    DropdownMenuItem(
                      value: RoomGender.putri,
                      child: Text('Putri'),
                    ),
                    DropdownMenuItem(
                      value: RoomGender.putra,
                      child: Text('Putra'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => gender = v);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Harga per Bulan (Rp)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: facCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Fasilitas (pisahkan dengan koma)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (room.status == RoomStatus.occupied)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () {
                  widget.store.vacateRoom(room.id);
                  Navigator.pop(ctx);
                },
                child: const Text('Kosongkan Kamar (FR-21)'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                final price =
                    int.tryParse(priceCtrl.text.trim()) ?? room.pricePerMonth;
                final facilities = facCtrl.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                widget.store.updateRoom(
                  roomId: room.id,
                  number: numCtrl.text,
                  floor: floor,
                  pricePerMonth: price,
                  gender: gender,
                  facilities: facilities,
                );
                Navigator.pop(ctx);
              },
              child: const Text('Simpan Kamar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchQuery.trim().toLowerCase();
    final filteredHolds = widget.store.bookingHolds.where((b) {
      if (q.isEmpty) return true;
      return b.fullName.toLowerCase().contains(q) ||
          b.roomNumber.toLowerCase().contains(q) ||
          b.phone.contains(q) ||
          b.email.toLowerCase().contains(q) ||
          b.ktpNumber.contains(q);
    }).toList();

    final filteredTenants = widget.store.tenants.where((t) {
      if (q.isEmpty) return true;
      return t.fullName.toLowerCase().contains(q) ||
          t.roomNumberSnapshot.toLowerCase().contains(q) ||
          t.phone.contains(q) ||
          t.email.toLowerCase().contains(q) ||
          t.ktpNumber.contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.people, size: 16),
                      label: Text('Penghuni'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.meeting_room, size: 16),
                      label: Text('39 Kamar'),
                    ),
                  ],
                  selected: {_showRoomsView},
                  onSelectionChanged: (s) =>
                      setState(() => _showRoomsView = s.first),
                ),
              ),
              if (!_showRoomsView) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _showAddTenantModal(context),
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Tambah'),
                ),
              ],
            ],
          ),
        ),
        if (!_showRoomsView) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: const InputDecoration(
                hintText: 'Cari nama penghuni, nomor kamar, atau HP (FR-19)...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: (filteredHolds.isEmpty && filteredTenants.isEmpty)
                ? const Center(
                    child: Text('Tidak ada data calon penghuni / penghuni.'),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (filteredHolds.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.pending_actions_outlined,
                                size: 18,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Calon Penghuni Masuk (${filteredHolds.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...filteredHolds.map((h) {
                          final roomTag = h.roomNumber.split(' ').first;
                          final hasKtpImg =
                              _decodeKtpBytes(h.ktpImageBase64) != null;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: Colors.orange.shade50,
                            child: ListTile(
                              onTap: () =>
                                  _showBookingHoldDetailDialog(context, h),
                              leading: CircleAvatar(
                                backgroundColor: Colors.orange.shade200,
                                child: Text(roomTag),
                              ),
                              title: Text(
                                h.fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'Calon Kamar ${h.roomNumber} (${h.months} bln) • HP: ${h.phone}\nEmail: ${h.email}\nNIK: ${h.ktpNumber} • ${hasKtpImg ? "Foto KTP ada" : "KTP: ${h.ktpFileName}"}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              isThreeLine: true,
                              trailing: Chip(
                                backgroundColor: Colors.orange.shade100,
                                label: const Text(
                                  'Menunggu Bayar',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          );
                        }),
                        const Divider(height: 24),
                      ],
                      if (filteredTenants.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Penghuni Terdaftar & Alumni (${filteredTenants.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        ...filteredTenants.map((t) {
                          final roomTag =
                              t.roomNumberSnapshot.split(' ').first;
                          final hasKtpImg =
                              _decodeKtpBytes(t.ktpImageBase64) != null;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              onTap: () =>
                                  _showTenantDetailAndActions(context, t),
                              leading: CircleAvatar(
                                backgroundColor: t.isActive
                                    ? Colors.indigo.shade100
                                    : Colors.grey.shade300,
                                child: Text(roomTag),
                              ),
                              title: Text(
                                t.fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'Kamar ${t.roomNumberSnapshot} • HP: ${t.phone} • Email: ${t.email}\nOrtu: ${t.parentName} (${t.parentPhone})\nNIK: ${t.ktpNumber} • ${hasKtpImg ? "Foto KTP tersimpan" : "File: ${t.ktpFileName}"}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              isThreeLine: true,
                              trailing: Chip(
                                label: Text(
                                  t.isActive ? 'Aktif' : 'Nonaktif',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
          ),
        ] else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.store.rooms.length,
              itemBuilder: (context, idx) {
                final r = widget.store.rooms[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => _showEditRoomDialog(context, r),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        r.effectivePhotoAsset,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 56,
                          height: 56,
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Icon(Icons.bed_outlined),
                        ),
                      ),
                    ),
                    title: Text(
                      'Kamar ${r.number} (Lantai ${r.floor} • ${r.genderLabel})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${AppFormatters.currency(r.pricePerMonth)}/bln • ${r.facilities.join(", ")}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(
                            r.statusLabel,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        const Icon(Icons.edit_outlined, size: 18),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ==================== TAB 3: KELOLA KELUHAN (FR-24 & FR-25) ====================
class _AdminComplaintsTab extends StatelessWidget {
  final EstopaStore store;

  const _AdminComplaintsTab({required this.store});

  void _showUpdateStatusDialog(BuildContext context, Complaint cmp) {
    ComplaintStatus selected = cmp.status;
    final noteCtrl = TextEditingController(text: cmp.adminNote ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Tindak Lanjut Keluhan Kamar ${cmp.roomNumber}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ComplaintStatus>(
                initialValue: selected,
                decoration: const InputDecoration(labelText: 'Status Keluhan'),
                items: const [
                  DropdownMenuItem(
                    value: ComplaintStatus.submitted,
                    child: Text('Masuk'),
                  ),
                  DropdownMenuItem(
                    value: ComplaintStatus.inProgress,
                    child: Text('Diproses'),
                  ),
                  DropdownMenuItem(
                    value: ComplaintStatus.resolved,
                    child: Text('Selesai'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => selected = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Catatan Admin / Progres Perbaikan',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                store.updateComplaintStatus(
                  complaintId: cmp.id,
                  newStatus: selected,
                  adminNote: noteCtrl.text,
                );
                Navigator.pop(ctx);
              },
              child: const Text('Simpan & Kirim Notif'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = store.complaints;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, idx) {
        final cmp = list[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            onTap: () => _showUpdateStatusDialog(context, cmp),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Kamar ${cmp.roomNumber} • ${cmp.category}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    cmp.statusLabel,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pelapor: ${cmp.tenantName}'),
                const SizedBox(height: 4),
                Text(cmp.description),
                if (cmp.adminNote != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Tindak Lanjut: ${cmp.adminNote}',
                      style: TextStyle(
                        color: Colors.indigo.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                const Text(
                  'Ketuk untuk ubah status (Masuk / Diproses / Selesai)',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==================== TAB 4: PENGUMUMAN & NOTIFIKASI ADMIN (FR-26 s.d. FR-28) ====================
class _AdminAnnouncementsAndNotifTab extends StatefulWidget {
  final EstopaStore store;

  const _AdminAnnouncementsAndNotifTab({required this.store});

  @override
  State<_AdminAnnouncementsAndNotifTab> createState() =>
      _AdminAnnouncementsAndNotifTabState();
}

class _AdminAnnouncementsAndNotifTabState
    extends State<_AdminAnnouncementsAndNotifTab> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  void _publishAnnouncement() {
    if (_titleCtrl.text.trim().isEmpty || _contentCtrl.text.trim().isEmpty) {
      return;
    }
    widget.store.createAnnouncement(
      title: _titleCtrl.text,
      content: _contentCtrl.text,
    );
    _titleCtrl.clear();
    _contentCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Pengumuman diterbitkan & notifikasi dikirim ke seluruh penghuni aktif (FR-26, FR-27).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTenantsCount =
        widget.store.tenants.where((t) => t.isActive).length;
    final adminNotifs = widget.store.notifications
        .where((n) => n.targetAudience == 'ADMIN')
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Buat Pengumuman ke Seluruh Penghuni (FR-26 & FR-27)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Judul Pengumuman',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _contentCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Isi Pengumuman',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _publishAnnouncement,
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Kirim Pengumuman & Notifikasi'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Daftar Pengumuman & Status Dibaca Penghuni (FR-28)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        for (final ann in widget.store.announcements)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text(
                ann.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(ann.content),
                  const SizedBox(height: 6),
                  Text(
                    'Dibaca oleh ${ann.readByTenantIds.length} dari $activeTenantsCount penghuni aktif • ${AppFormatters.dateTime(ann.createdAt)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 18),
        const Text(
          'Notifikasi Sistem Masuk (Admin)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        for (final n in adminNotifs)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.notifications_outlined),
              title: Text(
                n.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('${n.message} (${AppFormatters.dateTime(n.createdAt)})'),
            ),
          ),
      ],
    );
  }
}
