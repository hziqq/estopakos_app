import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/estopa_store.dart';
import '../utils/formatters.dart';
import 'booking_flow_screen.dart';
import 'login_screen.dart';

class PublicHomeScreen extends StatefulWidget {
  final EstopaStore store;

  const PublicHomeScreen({super.key, required this.store});

  @override
  State<PublicHomeScreen> createState() => _PublicHomeScreenState();
}

class _PublicHomeScreenState extends State<PublicHomeScreen> {
  int? _selectedFloor;
  RoomGender? _selectedGender;
  bool _onlyAvailable = true;
  bool _isFloorMapMode = false;
  String _searchQuery = '';
  bool _sortCheapestFirst = true;

  void _showDbConfigDialog() {
    final urlCtrl = TextEditingController(text: widget.store.backendUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Koneksi Backend PostgreSQL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.store.isBackendConnected
                  ? 'Status: Terhubung ke Server PostgreSQL'
                  : 'Status: Mode Offline Lokal (Server belum aktif / tidak terjangkau)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: widget.store.isBackendConnected
                    ? Colors.green.shade700
                    : Colors.orange.shade800,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'URL API Backend',
                hintText: 'http://10.0.2.2:8080/api',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Otomatis (USB/Wireless ADB): http://127.0.0.1:8080/api\nHP Fisik (Wi-Fi): http://192.168.1.32:8080/api\nAndroid Emulator: http://10.0.2.2:8080/api',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final ok = await widget.store.syncFromBackend(urlCtrl.text);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Berhasil terhubung & sinkron dengan PostgreSQL!'
                        : 'Gagal terhubung ke server (${widget.store.lastSyncError ?? "cek backend/server.dart"}).',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.sync, size: 16),
            label: const Text('Hubungkan & Sinkron'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final allRooms = widget.store.rooms;
        final filteredRooms = allRooms.where((r) {
          if (_onlyAvailable && r.status != RoomStatus.available) return false;
          if (_selectedFloor != null && r.floor != _selectedFloor) return false;
          if (_selectedGender != null && r.gender != _selectedGender) {
            return false;
          }
          if (_searchQuery.trim().isNotEmpty) {
            final q = _searchQuery.trim().toLowerCase();
            final matchNumber = r.number.toLowerCase().contains(q);
            final matchFac = r.facilities
                .any((f) => f.toLowerCase().contains(q));
            if (!matchNumber && !matchFac) return false;
          }
          return true;
        }).toList()
          ..sort(
            (a, b) => _sortCheapestFirst
                ? a.pricePerMonth.compareTo(b.pricePerMonth)
                : b.pricePerMonth.compareTo(a.pricePerMonth),
          );

        final availableCount = widget.store.availableRooms.length;
        final activeHolds = widget.store.bookingHolds
            .where((h) => !h.isExpired && !h.isPaid)
            .toList();

        return Scaffold(
          appBar: AppBar(
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estopa Kos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  'Jl. Sei Padang, Medan Baru • 39 Kamar (4 Lantai)',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: widget.store.isBackendConnected
                    ? 'PostgreSQL Terhubung'
                    : 'Pengaturan Server PostgreSQL',
                onPressed: _showDbConfigDialog,
                icon: Icon(
                  widget.store.isBackendConnected
                      ? Icons.cloud_done
                      : Icons.cloud_off_outlined,
                  color: widget.store.isBackendConnected
                      ? Colors.green.shade700
                      : Colors.grey.shade600,
                ),
              ),
              IconButton(
                tooltip: _isFloorMapMode ? 'Tampilan Daftar' : 'Denah 4 Lantai',
                onPressed: () =>
                    setState(() => _isFloorMapMode = !_isFloorMapMode),
                icon: Icon(
                  _isFloorMapMode ? Icons.view_list : Icons.grid_view_rounded,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LoginScreen(store: widget.store),
                      ),
                    );
                  },
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('Masuk'),
                ),
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.tertiary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$availableCount dari ${allRooms.length} Kamar Kosong',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Pesan Tanpa Login',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Cek Kamar Kosong & Pesan Langsung via QRIS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Biaya Air Rp35.000/bln • Biaya Transaksi QRIS Rp4.000 • Akun Penghuni Otomatis Aktif Setelah Bayar',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // Jika ada pemesanan yang sedang ditahan 20 menit, tampilkan pintasan kembali ke QR
              if (activeHolds.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Material(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookingQrPaymentScreen(
                              store: widget.store,
                              hold: activeHolds.first,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.qr_code_scanner,
                              color: Colors.deepOrange,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Pemesanan Kamar ${activeHolds.first.roomNumber} sedang menunggu pembayaran (Ditahan 20 menit). Ketuk untuk buka QR.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Pencarian Kamar & Urutan Harga (NFR-01 Usability)
              if (!_isFloorMapMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: const InputDecoration(
                            hintText:
                                'Cari nomor kamar atau fasilitas (mis. AC, 103)...',
                            prefixIcon: Icon(Icons.search, size: 18),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.sort, size: 16),
                        label: Text(
                          _sortCheapestFirst ? 'Termurah' : 'Tertinggi',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () => setState(
                          () => _sortCheapestFirst = !_sortCheapestFirst,
                        ),
                      ),
                    ],
                  ),
                ),

              // Filter Bar (Lantai, Jenis Putra/Putri, Status, Mode Denah)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    FilterChip(
                      avatar: Icon(
                        _isFloorMapMode
                            ? Icons.grid_view_rounded
                            : Icons.view_list,
                        size: 16,
                      ),
                      label: Text(
                        _isFloorMapMode ? 'Denah 4 Lantai' : 'Mode Denah',
                      ),
                      selected: _isFloorMapMode,
                      onSelected: (val) =>
                          setState(() => _isFloorMapMode = val),
                    ),
                    const SizedBox(width: 8),
                    if (!_isFloorMapMode) ...[
                      FilterChip(
                        label: const Text('Hanya Kamar Kosong'),
                        selected: _onlyAvailable,
                        onSelected: (val) =>
                            setState(() => _onlyAvailable = val),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Semua Jenis'),
                        selected: _selectedGender == null,
                        onSelected: (_) =>
                            setState(() => _selectedGender = null),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('Khusus Putri (Lt. 1-2)'),
                        selected: _selectedGender == RoomGender.putri,
                        onSelected: (s) => setState(
                          () => _selectedGender = s ? RoomGender.putri : null,
                        ),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('Khusus Putra (Lt. 3-4)'),
                        selected: _selectedGender == RoomGender.putra,
                        onSelected: (s) => setState(
                          () => _selectedGender = s ? RoomGender.putra : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      for (int floor = 1; floor <= 4; floor++) ...[
                        ChoiceChip(
                          label: Text('Lantai $floor'),
                          selected: _selectedFloor == floor,
                          onSelected: (s) => setState(
                            () => _selectedFloor = s ? floor : null,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ],
                ),
              ),
                  ],
                ),
              ),

              // Daftar Kamar atau Denah Visual 4 Lantai (FR-12)
              if (_isFloorMapMode)
                SliverToBoxAdapter(
                  child: _FloorMapVisualView(
                    rooms: allRooms,
                    onSelectRoom: (room) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RoomDetailAndBookingScreen(
                            store: widget.store,
                            room: room,
                          ),
                        ),
                      );
                    },
                  ),
                )
              else if (filteredRooms.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Tidak ada kamar yang sesuai dengan filter.',
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                  sliver: SliverList.builder(
                    itemCount: filteredRooms.length,
                    itemBuilder: (context, index) {
                      final room = filteredRooms[index];
                      return _RoomCard(
                        room: room,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RoomDetailAndBookingScreen(
                                store: widget.store,
                                room: room,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FloorMapVisualView extends StatelessWidget {
  final List<Room> rooms;
  final ValueChanged<Room> onSelectRoom;

  const _FloorMapVisualView({
    required this.rooms,
    required this.onSelectRoom,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        // Legenda Status Kamar
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: Colors.green.shade600, label: 'Kosong'),
            const SizedBox(width: 16),
            _LegendDot(color: Colors.amber.shade700, label: 'Ditahan (20m)'),
            const SizedBox(width: 16),
            _LegendDot(color: Colors.grey.shade500, label: 'Terisi'),
          ],
        ),
        const SizedBox(height: 12),
        for (int floor = 1; floor <= 4; floor++) ...[
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Lantai $floor (${floor <= 2 ? "Khusus Putri" : "Khusus Putra"})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${rooms.where((r) => r.floor == floor && r.status == RoomStatus.available).length} Kosong',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: rooms
                        .where((r) => r.floor == floor)
                        .map((room) {
                          final isAvail = room.status == RoomStatus.available;
                          final isHeld = room.status == RoomStatus.held;
                          final bgColor = isAvail
                              ? Colors.green.shade50
                              : (isHeld
                                  ? Colors.amber.shade100
                                  : Colors.grey.shade200);
                          final borderColor = isAvail
                              ? Colors.green.shade600
                              : (isHeld
                                  ? Colors.amber.shade800
                                  : Colors.grey.shade400);

                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => onSelectRoom(room),
                            child: Container(
                              width: 62,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderColor, width: 1.4),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    room.number,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isAvail
                                          ? Colors.green.shade900
                                          : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    '${(room.pricePerMonth / 1000).round()}rb',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        })
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _RoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;

  const _RoomCard({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isAvailable = room.status == RoomStatus.available;
    final isHeld = room.status == RoomStatus.held;

    Color statusColor;
    if (isAvailable) {
      statusColor = Colors.green.shade700;
    } else if (isHeld) {
      statusColor = Colors.orange.shade800;
    } else {
      statusColor = Colors.grey.shade600;
    }

    final isPutri = room.gender == RoomGender.putri;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Image.asset(
                  room.effectivePhotoAsset,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 120,
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Icon(Icons.bed_outlined, size: 36),
                  ),
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      room.isLargeRoom
                          ? 'Kamar Besar • AC'
                          : (room.facilities.contains('AC')
                              ? 'Kamar Kecil • AC'
                              : 'Kamar Kecil • Kipas'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Kamar ${room.number}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isPutri
                          ? Colors.pink.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${room.genderLabel} • Lantai ${room.floor}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isPutri
                            ? Colors.pink.shade800
                            : Colors.blue.shade800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      room.statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: room.facilities
                    .map(
                      (f) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          f,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${AppFormatters.currency(room.pricePerMonth)} / bulan',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        '+ Air Rp35.000/bln',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                  FilledButton.tonalIcon(
                    onPressed: onTap,
                    icon: Icon(
                      isAvailable
                          ? Icons.shopping_bag_outlined
                          : Icons.info_outline,
                      size: 16,
                    ),
                    label: Text(isAvailable ? 'Lihat & Pesan' : 'Detail'),
                  ),
                ],
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
