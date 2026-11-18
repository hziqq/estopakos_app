import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/estopa_store.dart';
import '../utils/formatters.dart';
import '../widgets/qris_box.dart';
import '../widgets/receipt_dialog.dart';

class TenantDashboardScreen extends StatefulWidget {
  final EstopaStore store;

  const TenantDashboardScreen({super.key, required this.store});

  @override
  State<TenantDashboardScreen> createState() => _TenantDashboardScreenState();
}

class _TenantDashboardScreenState extends State<TenantDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final tenant = widget.store.currentTenant;
        if (tenant == null || !tenant.isActive) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Sesi berakhir atau akun telah dinonaktifkan.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      widget.store.logout();
                      Navigator.popUntil(context, (r) => r.isFirst);
                    },
                    child: const Text('Kembali ke Beranda'),
                  ),
                ],
              ),
            ),
          );
        }

        final pages = [
          _TenantInvoicesAndPaymentsTab(store: widget.store, tenant: tenant),
          _TenantComplaintsTab(store: widget.store, tenant: tenant),
          _TenantAnnouncementsTab(store: widget.store, tenant: tenant),
          _TenantProfileAndNotifTab(store: widget.store, tenant: tenant),
        ];

        final unreadAnnCount = widget.store.announcements
            .where((a) => !a.readByTenantIds.contains(tenant.id))
            .length;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tenant.fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Penghuni Kamar ${tenant.roomNumberSnapshot} • Estopa Kos',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Keluar',
                onPressed: () {
                  widget.store.logout();
                  Navigator.popUntil(context, (route) => route.isFirst);
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
              const NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Tagihan',
              ),
              const NavigationDestination(
                icon: Icon(Icons.build_outlined),
                selectedIcon: Icon(Icons.build),
                label: 'Keluhan',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: unreadAnnCount > 0,
                  label: Text('$unreadAnnCount'),
                  child: const Icon(Icons.campaign_outlined),
                ),
                selectedIcon: const Icon(Icons.campaign),
                label: 'Pengumuman',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profil & Notif',
              ),
            ],
          ),
        );
      },
    );
  }
}

// ==================== TAB 1: TAGIHAN, QR 24 JAM & RIWAYAT (FR-01 s.d. FR-09) ====================
class _TenantInvoicesAndPaymentsTab extends StatelessWidget {
  final EstopaStore store;
  final Tenant tenant;

  const _TenantInvoicesAndPaymentsTab({
    required this.store,
    required this.tenant,
  });

  @override
  Widget build(BuildContext context) {
    final myInvoices =
        store.invoices.where((i) => i.tenantId == tenant.id).toList();
    final myPayments =
        store.payments.where((p) => p.tenantId == tenant.id).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Tagihan Sewa Kamar (FR-01 s.d. FR-06)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (myInvoices.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Belum ada tagihan.'),
            ),
          ),
        for (final inv in myInvoices)
          _TenantInvoiceCard(store: store, invoice: inv),
        const SizedBox(height: 20),
        const Text(
          'Riwayat Pembayaran Saya (FR-09)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (myPayments.isEmpty)
          const Text('Belum ada riwayat pembayaran.')
        else
          for (final pay in myPayments)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: ListTile(
                onTap: () => PaymentReceiptDialog.show(context, pay),
                leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  child: Icon(Icons.check, size: 18),
                ),
                trailing: const Icon(Icons.receipt_outlined, size: 18),
                title: Text(
                  '${pay.type} • ${AppFormatters.currency(pay.totalAmount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  'Kamar ${pay.roomNumber} • ${AppFormatters.dateTime(pay.paidAt)}\n'
                  'Sewa: ${AppFormatters.currency(pay.roomCost)} | Air: ${AppFormatters.currency(pay.waterCost)} | Admin: ${AppFormatters.currency(pay.transactionFee)}'
                  '${pay.lateFee > 0 ? " | Denda: ${AppFormatters.currency(pay.lateFee)}" : ""}\n'
                  'Ref Gateway: ${pay.gatewayReference}',
                  style: const TextStyle(fontSize: 11),
                ),
                isThreeLine: true,
              ),
            ),
      ],
    );
  }
}

class _TenantInvoiceCard extends StatelessWidget {
  final EstopaStore store;
  final Invoice invoice;

  const _TenantInvoiceCard({
    required this.store,
    required this.invoice,
  });

  Future<void> _confirmAddLateDay(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Denda Keterlambatan'),
        content: const Text(
          'Apakah anda ingin menambahkan 1 hari denda? (+Rp50.000/hari)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Tambahkan'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      store.simulateAddLateDay(invoice.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = invoice.status == InvoiceStatus.paid;
    final isOverdue = invoice.status == InvoiceStatus.overdue;

    Color statusColor;
    if (isPaid) {
      statusColor = Colors.green.shade700;
    } else if (isOverdue) {
      statusColor = Colors.red.shade700;
    } else {
      statusColor = Colors.orange.shade800;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: statusColor.withValues(alpha: 0.5), width: 1.4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Tagihan #${invoice.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    invoice.statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Jatuh Tempo: ${AppFormatters.date(invoice.dueDate)}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            if (invoice.sentReminders.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Pengingat Terkirim (FR-05): ${invoice.sentReminders.join(", ")}',
                style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
              ),
            ],
            const Divider(height: 20),

            if (!isPaid) ...[
              const Text(
                'Pilih Jumlah Bulan Sewa (FR-01):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [1, 3, 6, 12].map((m) {
                  return ChoiceChip(
                    label: Text('$m Bulan'),
                    selected: invoice.selectedMonths == m,
                    onSelected: (_) =>
                        store.updateInvoiceMonths(invoice.id, m),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
            ],

            // Rincian Rumus FR-02 & FR-04
            _RowItem(
              'Harga Kamar (${AppFormatters.currency(invoice.roomPricePerMonth)} × ${invoice.selectedMonths} bln)',
              AppFormatters.currency(invoice.roomSubtotal),
            ),
            _RowItem(
              'Biaya Air (Rp35.000 × ${invoice.selectedMonths} bln)',
              AppFormatters.currency(invoice.waterSubtotal),
            ),
            _RowItem(
              'Biaya Transaksi Gateway',
              AppFormatters.currency(invoice.transactionFee),
            ),
            if (invoice.lateFeeSubtotal > 0)
              _RowItem(
                'Denda Terlambat (${invoice.lateDays} hari × Rp50.000)',
                AppFormatters.currency(invoice.lateFeeSubtotal),
                isHighlight: true,
              ),
            const Divider(),
            _RowItem(
              'Total Tagihan',
              AppFormatters.currency(invoice.totalAmount),
              isBold: true,
            ),

            if (!isPaid) ...[
              const SizedBox(height: 12),
              if (invoice.activeQrCode == null)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => store.generateInvoiceQr(invoice.id),
                        icon: const Icon(Icons.qr_code_2),
                        label: const Text('Buat QR Tagihan (Berlaku 24 Jam)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message:
                          'Simulasi +1 Hari Terlambat (Uji Denda Rp50rb/hr)',
                      child: OutlinedButton(
                        onPressed: () => _confirmAddLateDay(context),
                        child: const Text('+1 Hr Telat'),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    QrisPaymentCard(
                      title: 'Estopa Kos • Tagihan Kamar ${invoice.roomNumber}',
                      subtitle:
                          '${invoice.tenantName} (${invoice.selectedMonths} Bulan)',
                      qrPayload: invoice.activeQrCode!,
                      totalAmount: invoice.totalAmount,
                      expiryLabel:
                          'Berlaku 24 Jam s.d. ${AppFormatters.dateTime(invoice.qrExpiresAt!)} (FR-03)',
                      isBookingQr: false,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                            ),
                            onPressed: () {
                              store.payInvoice(invoice.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Pembayaran berhasil! Status otomatis Lunas & tagihan periode berikutnya terjadwal (FR-01, FR-08).',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text(
                              'Simulasi Bayar Lunas (Webhook)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => _confirmAddLateDay(context),
                          child: const Text('+1 Hr Telat'),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool isHighlight;

  const _RowItem(
    this.label,
    this.value, {
    this.isBold = false,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isHighlight ? Colors.red.shade700 : Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isBold ? 14 : 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 15 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== TAB 2: LAPORAN KELUHAN (FR-23 s.d. FR-25) ====================
class _TenantComplaintsTab extends StatefulWidget {
  final EstopaStore store;
  final Tenant tenant;

  const _TenantComplaintsTab({
    required this.store,
    required this.tenant,
  });

  @override
  State<_TenantComplaintsTab> createState() => _TenantComplaintsTabState();
}

class _TenantComplaintsTabState extends State<_TenantComplaintsTab> {
  String _selectedCategory = 'Air / Kamar Mandi';
  final _descCtrl = TextEditingController();
  String? _photoName;

  final _categories = const [
    'Air / Kamar Mandi',
    'Listrik / Lampu',
    'AC / Kipas Angin',
    'Wi-Fi / Internet',
    'Kunci / Pintu / Jendela',
    'Kebersihan',
    'Lainnya',
  ];

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  void _submitComplaint() {
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap tulis deskripsi keluhan.')),
      );
      return;
    }
    widget.store.createComplaint(
      tenant: widget.tenant,
      category: _selectedCategory,
      description: _descCtrl.text,
      attachmentName: _photoName,
    );
    _descCtrl.clear();
    setState(() => _photoName = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Keluhan berhasil dikirim ke Admin Estopa Kos (FR-23).'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myComplaints = widget.store.complaints
        .where((c) => c.tenantId == widget.tenant.id)
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
                  'Buat Laporan Keluhan Baru (FR-23)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Kategori Keluhan',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedCategory = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi Kerusakan / Keluhan',
                    hintText: 'Contoh: Lampu kamar mandi putus atau kran bocor...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _photoName =
                              'keluhan_kamar_${widget.tenant.roomNumberSnapshot}.jpg';
                        });
                      },
                      icon: const Icon(Icons.camera_alt_outlined, size: 16),
                      label: Text(
                        _photoName == null
                            ? 'Lampirkan Foto (Opsional)'
                            : _photoName!,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _submitComplaint,
                      icon: const Icon(Icons.send, size: 16),
                      label: const Text('Kirim Keluhan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Status Keluhan Saya (FR-25)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        if (myComplaints.isEmpty)
          const Text('Belum ada laporan keluhan.')
        else
          for (final cmp in myComplaints)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        cmp.category,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(
                        cmp.statusLabel,
                        style: const TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(cmp.description),
                    if (cmp.attachmentName != null)
                      Text(
                        'Lampiran: ${cmp.attachmentName}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.blueGrey,
                        ),
                      ),
                    if (cmp.adminNote != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Tanggapan Admin: ${cmp.adminNote}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      AppFormatters.dateTime(cmp.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

// ==================== TAB 3: PENGUMUMAN & STATUS DIBACA (FR-26 s.d. FR-28) ====================
class _TenantAnnouncementsTab extends StatelessWidget {
  final EstopaStore store;
  final Tenant tenant;

  const _TenantAnnouncementsTab({
    required this.store,
    required this.tenant,
  });

  @override
  Widget build(BuildContext context) {
    final list = store.announcements;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final ann = list[index];
        final isRead = ann.readByTenantIds.contains(tenant.id);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isRead ? Colors.grey.shade300 : Colors.blue.shade400,
              width: isRead ? 1 : 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isRead ? Icons.drafts_outlined : Icons.mark_email_unread,
                      size: 18,
                      color: isRead ? Colors.grey : Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ann.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isRead
                            ? Colors.green.shade50
                            : Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isRead ? 'Sudah Dibaca' : 'Belum Dibaca',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isRead
                              ? Colors.green.shade800
                              : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  AppFormatters.dateTime(ann.createdAt),
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 10),
                Text(ann.content),
                if (!isRead) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: () =>
                          store.markAnnouncementRead(ann.id, tenant.id),
                      icon: const Icon(Icons.done_all, size: 16),
                      label: const Text('Tandai Sudah Dibaca (FR-28)'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==================== TAB 4: PROFIL READ-ONLY & NOTIFIKASI (FR-19, NFR-03) ====================
class _TenantProfileAndNotifTab extends StatelessWidget {
  final EstopaStore store;
  final Tenant tenant;

  const _TenantProfileAndNotifTab({
    required this.store,
    required this.tenant,
  });

  @override
  Widget build(BuildContext context) {
    final myNotifs = store.notifications
        .where((n) => n.targetAudience == tenant.id)
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
                const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Biodata Penghuni (Read-Only - FR-19)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sesuai FR-19 & NFR-03, perubahan biodata atau reset password hanya dapat dilakukan melalui Admin Estopa Kos.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const Divider(height: 20),
                _RowItem('Nama Lengkap', tenant.fullName),
                _RowItem('Kamar', 'Kamar ${tenant.roomNumberSnapshot}'),
                _RowItem('Nomor HP', tenant.phone),
                _RowItem('Email', tenant.email),
                _RowItem('Alamat Asal', tenant.originAddress),
                _RowItem(
                  'Kontak Orang Tua',
                  '${tenant.parentName} (${tenant.parentPhone})',
                ),
                _RowItem(
                  'Masa Sewa Aktif s.d.',
                  AppFormatters.date(tenant.leaseEndDate),
                  isBold: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Kotak Masuk Notifikasi Sistem & Email',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        if (myNotifs.isEmpty)
          const Text('Belum ada notifikasi.')
        else
          for (final n in myNotifs)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: Text(
                  n.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  '${n.message}\n[${n.channel} • ${AppFormatters.dateTime(n.createdAt)}]',
                  style: const TextStyle(fontSize: 12),
                ),
                isThreeLine: true,
              ),
            ),
      ],
    );
  }
}
