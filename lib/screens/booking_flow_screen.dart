import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../state/estopa_store.dart';
import '../utils/formatters.dart';
import '../widgets/qris_box.dart';
import 'login_screen.dart';

class RoomDetailAndBookingScreen extends StatefulWidget {
  final EstopaStore store;
  final Room room;

  const RoomDetailAndBookingScreen({
    super.key,
    required this.store,
    required this.room,
  });

  @override
  State<RoomDetailAndBookingScreen> createState() =>
      _RoomDetailAndBookingScreenState();
}

class _RoomDetailAndBookingScreenState
    extends State<RoomDetailAndBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _parentNameCtrl = TextEditingController();
  final _parentPhoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _ktpNumberCtrl = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  int _selectedMonths = 1;
  String? _uploadedKtpFileName;
  Uint8List? _uploadedKtpBytes;
  bool _ktpConsent = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _parentNameCtrl.dispose();
    _parentPhoneCtrl.dispose();
    _passwordCtrl.dispose();
    _ktpNumberCtrl.dispose();
    super.dispose();
  }

  void _fillSampleApplicant() {
    var suffix = 0;
    bool isUsed(String email, String phone) {
      final lowerEmail = email.toLowerCase();
      return widget.store.tenants.any(
            (t) => t.email.toLowerCase() == lowerEmail || t.phone == phone,
          ) ||
          widget.store.bookingHolds.any(
            (b) => b.email.toLowerCase() == lowerEmail || b.phone == phone,
          );
    }

    var sampleEmail = 'putri.ayu@gmail.com';
    var samplePhone = '081277889900';
    while (isUsed(sampleEmail, samplePhone)) {
      suffix = suffix == 0 ? 2 : suffix + 1;
      sampleEmail = 'putri.ayu$suffix@gmail.com';
      final tail = (suffix % 90 + 10).toString().padLeft(2, '0');
      samplePhone = '0812778899$tail';
    }

    setState(() {
      _nameCtrl.text = suffix == 0
          ? 'Putri Ayu Lestari'
          : 'Putri Ayu Lestari $suffix';
      _phoneCtrl.text = samplePhone;
      _emailCtrl.text = sampleEmail;
      _addressCtrl.text = 'Jl. Merdeka No. 10, Tebing Tinggi';
      _parentNameCtrl.text = 'Bapak Hendra Wijaya';
      _parentPhoneCtrl.text = '081377889911';
      _passwordCtrl.text = 'rahasia123';
      _ktpNumberCtrl.text = '1276014506050002';
      _uploadedKtpFileName = 'ktp_putri_ayu_lestari.jpg';
      _uploadedKtpBytes = null;
      _ktpConsent = true;
    });
  }

  Future<void> _pickKtpImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1000,
        imageQuality: 75,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      final fileName = picked.name.trim().isNotEmpty
          ? picked.name.trim()
          : 'ktp_${DateTime.now().millisecondsSinceEpoch}.jpg';
      setState(() {
        _uploadedKtpFileName = fileName;
        _uploadedKtpBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal membuka ${source == ImageSource.camera ? 'kamera' : 'galeri'}: $e',
          ),
        ),
      );
    }
  }

  void _showKtpSourcePicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Pilih Sumber Foto KTP',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Ambil foto langsung menggunakan kamera atau pilih dari galeri HP Anda.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Buka Kamera (Foto Langsung)'),
              onTap: () {
                Navigator.pop(ctx);
                _pickKtpImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Buka Galeri (Pilih Gambar)'),
              onTap: () {
                Navigator.pop(ctx);
                _pickKtpImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _submitBooking() {
    if (!_formKey.currentState!.validate()) return;
    if (_uploadedKtpFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap unggah foto KTP terlebih dahulu (FR-13).'),
        ),
      );
      return;
    }
    if (!_ktpConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Harap centang persetujuan penyimpanan data KTP (NFR-04).',
          ),
        ),
      );
      return;
    }

    final hold = widget.store.createBookingHold(
      room: widget.room,
      months: _selectedMonths,
      fullName: _nameCtrl.text,
      phone: _phoneCtrl.text,
      email: _emailCtrl.text,
      originAddress: _addressCtrl.text,
      parentName: _parentNameCtrl.text,
      parentPhone: _parentPhoneCtrl.text,
      password: _passwordCtrl.text,
      ktpNumber: _ktpNumberCtrl.text,
      ktpFileName: _uploadedKtpFileName!,
      ktpImageBase64: _uploadedKtpBytes == null
          ? null
          : base64Encode(_uploadedKtpBytes!),
      ktpConsent: _ktpConsent,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BookingQrPaymentScreen(
          store: widget.store,
          hold: hold,
          plainPassword: _passwordCtrl.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final isAvailable = room.status == RoomStatus.available;
    final roomCost = room.pricePerMonth * _selectedMonths;
    final waterCost = CostConstants.waterFeePerMonth * _selectedMonths;
    final total = CostConstants.calculateTotal(
      roomPricePerMonth: room.pricePerMonth,
      months: _selectedMonths,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Kamar ${room.number} (Lantai ${room.floor})'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Kamar (FR-12)
            Card(
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => Dialog(
                          insetPadding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppBar(
                                title: Text(
                                  'Foto Kamar ${room.number} (${room.isLargeRoom ? "Kamar Besar" : "Kamar Kecil"})',
                                  style: const TextStyle(fontSize: 15),
                                ),
                                automaticallyImplyLeading: false,
                                actions: [
                                  IconButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                              InteractiveViewer(
                                child: Image.asset(
                                  room.effectivePhotoAsset,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Stack(
                      children: [
                        Image.asset(
                          room.effectivePhotoAsset,
                          height: 190,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            height: 140,
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Icon(Icons.bed_outlined, size: 42),
                          ),
                        ),
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.zoom_in,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Perbesar Foto',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Kamar ${room.number} • Kos ${room.genderLabel}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              label: Text(room.statusLabel),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Harga Sewa: ${AppFormatters.currency(room.pricePerMonth)} / bulan',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Fasilitas Kamar:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: room.facilities
                              .map(
                                (f) => Chip(
                                  label: Text(
                                    f,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (!isAvailable)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_clock, color: Colors.deepOrange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        room.status == RoomStatus.held
                            ? 'Kamar ini sedang ditahan selama 20 menit untuk proses pembayaran calon penghuni lain (FR-14).'
                            : 'Kamar ini sudah terisi. Silakan pilih kamar lain yang berstatus Kosong.',
                      ),
                    ),
                  ],
                ),
              )
            else
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Formulir Pemesanan Online (FR-13)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _fillSampleApplicant,
                          icon: const Icon(Icons.auto_fix_high, size: 16),
                          label: const Text('Isi Data Uji'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nama Lengkap Sesuai KTP',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Nomor HP (WhatsApp)',
                              prefixIcon: Icon(Icons.phone_android),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Wajib diisi'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email Aktif',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) =>
                                v == null || !v.contains('@')
                                    ? 'Email tidak valid'
                                    : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Alamat Asal',
                        prefixIcon: Icon(Icons.home_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _parentNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nama Orang Tua / Wali',
                              prefixIcon: Icon(Icons.family_restroom),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Wajib diisi'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _parentPhoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'No. HP Orang Tua (Darurat)',
                              prefixIcon: Icon(Icons.call_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Wajib diisi'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _ktpNumberCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'NIK KTP (16 Digit)',
                              prefixIcon: Icon(Icons.badge_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.trim().length < 8
                                ? 'Masukkan NIK KTP'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _passwordCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Buat Password Akun',
                              prefixIcon: Icon(Icons.lock_outline),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.length < 6
                                ? 'Minimal 6 karakter'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Pilihan Durasi Bulan Sewa (1, 3, 6, 12 Bulan)
                    const Text(
                      'Pilih Durasi Sewa Awal (Bulan):',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: [1, 3, 6, 12].map((m) {
                        return ChoiceChip(
                          label: Text('$m Bulan'),
                          selected: _selectedMonths == m,
                          onSelected: (_) =>
                              setState(() => _selectedMonths = m),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Unggah Foto KTP & Persetujuan Privasi (FR-13 & NFR-04)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.credit_card, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _uploadedKtpFileName == null
                                      ? 'Unggah Foto KTP (Wajib via Kamera / Galeri)'
                                      : 'File KTP: $_uploadedKtpFileName',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _showKtpSourcePicker,
                                icon: const Icon(
                                  Icons.add_a_photo_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  _uploadedKtpFileName == null
                                      ? 'Pilih Foto KTP'
                                      : 'Ganti Foto',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _pickKtpImage(ImageSource.camera),
                                  icon: const Icon(
                                    Icons.camera_alt_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Buka Kamera'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _pickKtpImage(ImageSource.gallery),
                                  icon: const Icon(
                                    Icons.photo_library_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Buka Galeri'),
                                ),
                              ),
                            ],
                          ),
                          if (_uploadedKtpBytes != null) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                _uploadedKtpBytes!,
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _ktpConsent,
                            onChanged: (v) =>
                                setState(() => _ktpConsent = v ?? false),
                            title: const Text(
                              'Saya menyetujui foto KTP & biodata saya disimpan untuk administrasi Estopa Kos. Data otomatis dihapus jika pembayaran kedaluwarsa (NFR-03, NFR-04).',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Rincian Perhitungan Biaya (FR-02)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rincian Pembayaran Pemesanan (FR-02)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          _PriceRow(
                            label:
                                'Harga Kamar (${AppFormatters.currency(room.pricePerMonth)} × $_selectedMonths bln)',
                            value: AppFormatters.currency(roomCost),
                          ),
                          _PriceRow(
                            label:
                                'Biaya Air (${AppFormatters.currency(CostConstants.waterFeePerMonth)} × $_selectedMonths bln)',
                            value: AppFormatters.currency(waterCost),
                          ),
                          _PriceRow(
                            label: 'Biaya Transaksi Payment Gateway',
                            value: AppFormatters.currency(
                              CostConstants.transactionFee,
                            ),
                          ),
                          const Divider(),
                          _PriceRow(
                            label: 'Total Bayar',
                            value: AppFormatters.currency(total),
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _submitBooking,
                        icon: const Icon(Icons.qr_code_2),
                        label: const Text(
                          'Pesan Kamar & Buat QRIS (Tahan 20 Menit)',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class BookingQrPaymentScreen extends StatefulWidget {
  final EstopaStore store;
  final BookingHold hold;
  final String? plainPassword;

  const BookingQrPaymentScreen({
    super.key,
    required this.store,
    required this.hold,
    this.plainPassword,
  });

  @override
  State<BookingQrPaymentScreen> createState() => _BookingQrPaymentScreenState();
}

class _BookingQrPaymentScreenState extends State<BookingQrPaymentScreen> {
  Timer? _timer;
  Duration _remaining = const Duration(minutes: 20);
  bool _isProcessingWebhook = false;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    final diff = widget.hold.expiresAt.difference(DateTime.now());
    if (diff.inSeconds <= 0) {
      _timer?.cancel();
      _handleExpired();
    } else {
      if (mounted) {
        setState(() => _remaining = diff);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handleExpired() {
    widget.store.expireBookingHold(widget.hold.id, widget.hold);
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.timer_off_outlined, color: Colors.red),
            SizedBox(width: 8),
            Expanded(child: Text('Waktu Pembayaran Habis (20 Menit)')),
          ],
        ),
        content: Text(
          'Sesuai kriteria FR-15 & NFR-04:\n'
          '• Kode QR Pemesanan (${widget.hold.id}) tidak berlaku lagi.\n'
          '• Kamar ${widget.hold.roomNumber} kembali berstatus Kosong.\n'
          '• Data biodata sementara dan file KTP (${widget.hold.ktpFileName}) telah dihapus otomatis dari sistem.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text('Kembali ke Daftar Kamar'),
          ),
        ],
      ),
    );
  }

  String? get _resolvedPlainPassword =>
      widget.plainPassword ??
      widget.store.pendingPlainPasswordFor(
        holdId: widget.hold.id,
        email: widget.hold.email,
      );

  Future<Map<String, dynamic>?> _dispatchWelcomeEmail(Tenant newTenant) async {
    final hold = widget.hold;
    try {
      return await widget.store.triggerWelcomeEmail(
        fullName: newTenant.fullName,
        email: newTenant.email,
        phone: newTenant.phone,
        roomNumber: newTenant.roomNumberSnapshot,
        months: hold.months,
        roomCost: hold.roomSubtotal,
        waterCost: hold.waterSubtotal,
        transactionFee: hold.transactionFee,
        totalAmount: hold.totalAmount,
        plainPassword: _resolvedPlainPassword,
      );
    } catch (e) {
      return {
        'sentViaSmtp': false,
        'statusMessage':
            'Mode lokal aktif (belum terhubung ke server): salinan email tercatat di aplikasi.',
      };
    }
  }

  void _showEmailPreviewDialog(BuildContext parentCtx, Tenant newTenant) {
    final hold = widget.hold;
    final visiblePwd = _resolvedPlainPassword ?? '-';
    showDialog(
      context: parentCtx,
      builder: (previewCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.mark_email_read_outlined, color: Color(0xFF0F6B58)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Isi Email Konfirmasi Otomatis',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Dari: Manajemen Estopa Kos\n'
                'Kepada: ${newTenant.email}\n'
                'Subjek: [Estopa Kos] Bukti Pembayaran Lunas & Aktivasi Akun Kamar ${newTenant.roomNumberSnapshot}',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
              const Divider(height: 20),
              Text(
                'Halo ${newTenant.fullName},\n\n'
                'Terima kasih! Pembayaran pemesanan Kamar ${newTenant.roomNumberSnapshot} telah kami terima secara lunas dan akun penghuni Anda kini aktif otomatis.\n\n'
                'INFORMASI LOGIN AKUN PENGHUNI:\n'
                '• Email Login: ${newTenant.email}\n'
                '• No. HP Login: ${newTenant.phone}\n'
                '• Kata Sandi: $visiblePwd\n'
                '• Status Kamar ${newTenant.roomNumberSnapshot}: TERISI (Aktif)\n\n'
                'RINCIAN PEMBAYARAN (${hold.months} Bulan):\n'
                '• Sewa Kamar: ${AppFormatters.currency(hold.roomSubtotal)}\n'
                '• Biaya Air: ${AppFormatters.currency(hold.waterSubtotal)}\n'
                '• Biaya Transaksi: ${AppFormatters.currency(hold.transactionFee)}\n'
                '• TOTAL LUNAS: ${AppFormatters.currency(hold.totalAmount)}',
                style: const TextStyle(fontSize: 12.5, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(previewCtx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _handleSuccessWebhook() {
    if (_isProcessingWebhook) return;
    _isProcessingWebhook = true;
    _timer?.cancel();
    final newTenant = widget.store.completeBookingPayment(
      widget.hold.id,
      widget.hold,
    );
    if (!mounted) return;

    String emailStatusText =
        'Mengirim email konfirmasi otomatis ke ${newTenant.email}...';
    bool emailSentViaSmtp = false;
    bool emailTriggered = false;

    // FR-16: Pop-up terima kasih tampil, akun aktif, email otomatis terkirim, admin dapat notifikasi
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (!emailTriggered) {
            emailTriggered = true;
            _dispatchWelcomeEmail(newTenant).then((res) {
              if (!ctx.mounted) return;
              setDialogState(() {
                emailSentViaSmtp = res?['sentViaSmtp'] == true;
                emailStatusText = (res?['statusMessage'] as String?) ??
                    'Email konfirmasi telah dikirim ke ${newTenant.email}.';
              });
            });
          }

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Expanded(child: Text('Terima Kasih! Pembayaran Berhasil')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selamat datang di Estopa Kos, ${newTenant.fullName}!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Kamar ${newTenant.roomNumberSnapshot} kini berstatus Terisi.',
                  ),
                  const Text('• Akun penghuni Anda otomatis aktif.'),
                  Text(
                    '• Email konfirmasi telah dikirim ke ${newTenant.email}.',
                  ),
                  const Text('• Admin Estopa Kos telah menerima notifikasi.'),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Info Login Anda:\n'
                      'Email / HP: ${newTenant.email} / ${newTenant.phone}\n'
                      'Kata Sandi: ${_resolvedPlainPassword ?? "-"}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: emailSentViaSmtp
                          ? Colors.teal.shade50
                          : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: emailSentViaSmtp
                            ? Colors.teal.shade300
                            : Colors.amber.shade300,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              emailSentViaSmtp
                                  ? Icons.mark_email_read
                                  : Icons.outgoing_mail,
                              size: 16,
                              color: emailSentViaSmtp
                                  ? Colors.teal.shade800
                                  : Colors.orange.shade900,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                emailSentViaSmtp
                                    ? 'Email Terkirim ke Inbox (SMTP Aktif)'
                                    : 'Status Pengiriman Email Otomatis',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          emailStatusText,
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        const SizedBox(height: 6),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                          ),
                          onPressed: () =>
                              _showEmailPreviewDialog(ctx, newTenant),
                          icon: const Icon(Icons.visibility, size: 14),
                          label: const Text(
                            'Lihat Isi Email Konfirmasi',
                            style: TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text('Ke Beranda'),
              ),
              FilledButton.icon(
                onPressed: () {
                  // Kirim email otomatis jika belum terkirim lewat popup
                  if (!emailSentViaSmtp) {
                    _dispatchWelcomeEmail(newTenant);
                  }
                  Navigator.pop(ctx);
                  widget.store.login(newTenant.email, newTenant.password);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF0F6B58),
                      content: Text(
                        'Email konfirmasi otomatis telah dikirim ke ${newTenant.email}!',
                      ),
                    ),
                  );
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LoginScreen(store: widget.store),
                    ),
                    (route) => route.isFirst,
                  );
                },
                icon: const Icon(Icons.login),
                label: const Text('Masuk ke Akun Saya'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hold = widget.hold;
    return Scaffold(
      appBar: AppBar(
        title: Text('Pembayaran QRIS Kamar ${hold.roomNumber}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Countdown Banner 20 Menit (FR-14)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade700),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer, color: Colors.deepOrange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kamar Ditahan Selama 20 Menit (FR-14)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Selesaikan pembayaran sebelum waktu habis agar kamar & data tidak hangus.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      AppFormatters.countdown(_remaining),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Kartu Simulasi QRIS Pemesanan (Berbeda dari QR Tagihan Bulanan - FR-03)
            QrisPaymentCard(
              title: 'Estopa Kos • Pemesanan Kamar ${hold.roomNumber}',
              subtitle: 'Pemesan: ${hold.fullName} (${hold.months} Bulan)',
              qrPayload: hold.qrPayload,
              totalAmount: hold.totalAmount,
              expiryLabel:
                  'Batas Waktu QR Pemesanan: ${AppFormatters.countdown(_remaining)} (20 Menit)',
              isBookingQr: true,
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _PriceRow(
                      label: 'Sewa Kamar (${hold.months} bln)',
                      value: AppFormatters.currency(hold.roomSubtotal),
                    ),
                    _PriceRow(
                      label: 'Biaya Air (Rp35.000 × ${hold.months})',
                      value: AppFormatters.currency(hold.waterSubtotal),
                    ),
                    _PriceRow(
                      label: 'Biaya Transaksi Gateway',
                      value: AppFormatters.currency(hold.transactionFee),
                    ),
                    const Divider(),
                    _PriceRow(
                      label: 'Total Tagihan QRIS',
                      value: AppFormatters.currency(hold.totalAmount),
                      isBold: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Panel Simulator Sandbox Payment Gateway untuk Demo Sprint 3
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueGrey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.science_outlined, size: 18),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Simulator Webhook Payment Gateway (Sandbox)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                      ),
                      onPressed: _handleSuccessWebhook,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text(
                        'Simulasi Webhook: Pembayaran Berhasil (FR-16)',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                      ),
                      onPressed: () {
                        _timer?.cancel();
                        _handleExpired();
                      },
                      icon: const Icon(Icons.timer_off_outlined),
                      label: const Text(
                        'Simulasi Waktu 20 Menit Habis / Kedaluwarsa (FR-15)',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _PriceRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isBold ? 14 : 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 15 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
