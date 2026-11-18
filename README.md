# Sistem Informasi Manajemen Estopa Kos (Aplikasi Flutter)

Proyek Mata Kuliah **Rekayasa Perangkat Lunak**, Program Studi **D-4 Teknologi Rekayasa Perangkat Lunak (TRPL)**, **Politeknik Negeri Medan**.
- **Dosen Pengampu**: Cut Try Utari, S.T., M.Kom..
- **Lokasi Studi Kasus**: Estopa Kos (39 Kamar, 4 Lantai, Jl. Sei Padang, Medan Baru, Kota Medan).

---

## 1. Tim Pengembang (Scrum Team)

| Nama | Peran Scrum | Fokus Pengembangan |
|---|---|---|
| **Haziq Al Fareza** | Product Owner | Prioritas backlog, kriteria penerimaan, komunikasi pemilik kos, pengembangan |
| **David Gerard Hutagaol** | Scrum Master (Ketua) | Fasilitasi Scrum, review, retrospektif, manajemen Trello, pengembangan |
| **Andrew Choky Tuani Simanjuntak** | Developer | Pemesanan kamar online, tahan kamar 20 menit & pembayaran QRIS |
| **Henri Santoso Hutasoit** | Developer | Tagihan otomatis, denda keterlambatan, rekap keuangan & scheduler pengingat |
| **Sutanto Marpaung** | Developer | Kelola 39 kamar, data penghuni & KTP, laporan keluhan & pengumuman |

---

## 2. Daftar Fitur Lengkap (`FR-01` s.d. `FR-29`)

1. **Info Kamar Kosong & Pemesanan Online Tanpa Login (`FR-12` s.d. `FR-17`)**
   - Katalog **39 kamar di 4 lantai** (Lantai 1–2 Khusus Putri, Lantai 3–4 Khusus Putra) dengan **Mode Daftar** dan **Mode Denah Visual 4 Lantai**.
   - Form pemesanan online lengkap dengan unggah foto KTP & persetujuan privasi (`NFR-04`).
   - Kamar ditahan selama **20 menit** dan **QRIS Pemesanan** berlaku 20 menit (`FR-14`).
   - Jika waktu 20 menit habis: QR hangus, kamar kembali kosong, dan data sementara/KTP dihapus (`FR-15`).
   - Jika pembayaran berhasil via webhook: kamar berstatus *Terisi*, akun penghuni otomatis aktif, email konfirmasi terkirim, pop-up terima kasih tampil, dan Admin menerima notifikasi (`FR-16`, `FR-17`).

2. **Tagihan Otomatis, Denda & Pengingat (`FR-01` s.d. `FR-07`)**
   - Tagihan terbit otomatis di akhir masa sewa; penghuni dapat memilih durasi perpanjangan (`1`, `3`, `6`, atau `12` bulan).
   - Rumus perhitungan transparan:
     $$\text{Total} = (\text{Harga Kamar} \times \text{Bulan}) + (\text{Rp35.000} \times \text{Bulan}) + \text{Rp4.000} + (\text{Rp50.000} \times \text{Hari Terlambat})$$
   - **QRIS Tagihan** berlaku **24 jam** dan terpisah dari QR pemesanan (`FR-03`).
   - Pengingat terjadwal `H-3`, `H-2`, `H-1`, hari jatuh tempo (`H-0`), dan saat `Terlambat` dikirim via notifikasi sistem & email (`FR-05`).

3. **Pembayaran Gateway, Kwitansi Digital & Pencatatan Keuangan (`FR-08` s.d. `FR-11`)**
   - Status tagihan otomatis berubah menjadi *Lunas* setelah webhook pembayaran berhasil (dilengkapi proteksi idempotensi terhadap webhook ganda).
   - Kwitansi pembayaran digital tersedia bagi Penghuni dan Admin.
   - Rekap pemasukan otomatis (termasuk pemisahan pemasukan Sewa Kamar vs Biaya Air Rp35.000/bulan) dan pencatatan pengeluaran kos oleh Admin.

4. **Data Penghuni, Dokumen KTP & Manajemen Kamar (`FR-18` s.d. `FR-22`)**
   - Data penghuni otomatis terisi dari pemesanan atau ditambah manual oleh Admin (untuk penghuni lama).
   - Dokumen KTP hanya dapat diakses oleh Admin (`NFR-03`), kata sandi di-hash (`NFR-02`), dan Admin dapat mereset kata sandi penghuni (`FR-22`).
   - Saat Admin mengosongkan kamar, akun penghuni sebelumnya otomatis **nonaktif** dan tidak dapat login (`FR-21`), tetapi seluruh riwayat pembayaran dan keluhan tetap tersimpan (`NFR-07`).

5. **Laporan Keluhan (`FR-23` s.d. `FR-25`) & Pengumuman (`FR-26` s.d. `FR-28`)**
   - Penghuni mengirim keluhan beserta kategori dan lampiran foto opsional; Admin memperbarui status (`Masuk` → `Diproses` → `Selesai`).
   - Admin menerbitkan pengumuman ke seluruh penghuni aktif dan memantau jumlah penghuni yang **Sudah Membaca** (`FR-28`).

---

## 3. Struktur Folder Proyek

- `lib/main.dart` — Konfigurasi utama aplikasi Flutter & tema Material 3.
- `lib/models/models.dart` — Model data domain & kalkulator biaya (`CostConstants`).
- `lib/state/estopa_store.dart` — State management, logika bisnis `FR-01` s.d. `FR-29`, dan data awal 39 kamar.
- `lib/screens/public_home_screen.dart` — Beranda publik calon penghuni (Daftar & Denah 4 Lantai).
- `lib/screens/booking_flow_screen.dart` — Detail kamar, form pemesanan + KTP, dan layar pembayaran QRIS 20 menit.
- `lib/screens/login_screen.dart` — Halaman login multi-peran (`FR-29`) & pintasan akun uji demo.
- `lib/screens/tenant_dashboard_screen.dart` — Dashboard Penghuni (Tagihan, Keluhan, Pengumuman, Profil).
- `lib/screens/admin_dashboard_screen.dart` — Dashboard Admin (Kas & Tagihan, Penghuni & 39 Kamar, Keluhan, Pengumuman).
- `lib/widgets/qris_box.dart` — Generator visual matriks QRIS Pemesanan (20m) & QRIS Tagihan (24j).
- `lib/widgets/receipt_dialog.dart` — Dialog Kwitansi Pembayaran Digital Estopa Kos.
- `lib/utils/security.dart` — Hashing kata sandi (`NFR-02`).
- `backend/server.dart` — Server REST API, endpoint webhook payment gateway, & cron scheduler.
- `test/widget_test.dart` — Unit test, widget test, dan uji kasus batas (`B-20`).
- `docs/` — Dokumen [PRD.md](file:///c:/contohaplikasi/cntohaplikasi/docs/PRD.md), [PROJECT_PLAN.md](file:///c:/contohaplikasi/cntohaplikasi/docs/PROJECT_PLAN.md), dan [SRS_UML_ERD_API.md](file:///c:/contohaplikasi/cntohaplikasi/docs/SRS_UML_ERD_API.md).

---

## 4. Cara Menjalankan & Menguji

1. **Menjalankan Aplikasi Flutter**:
   ```powershell
   flutter run
   ```
2. **Menjalankan Unit Test & Uji Kasus Batas (`B-20`)**:
   ```powershell
   flutter test
   ```
3. **Menjalankan Server Backend & Cron Scheduler (`B-02`)**:
   ```powershell
   dart run backend/server.dart
   ```
