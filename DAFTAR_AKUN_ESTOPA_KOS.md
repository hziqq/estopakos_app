# Daftar Akun & Struktur Database Bahasa Indonesia — Estopa Kos

## 1. Akun Admin / Pemilik Estopa Kos
| Peran | Email Login | Nomor HP Login | Kata Sandi | Keterangan |
|---|---|---|---|---|
| **Admin / Pemilik** | `haziqalfareza06@gmail.com` | `08116001234` | `admin123` | Akses penuh 39 kamar, keuangan, penghuni, keluhan & pengumuman |

---

## 2. Daftar Akun Penghuni (`@gmail.com`)
Semua akun penghuni di bawah ini menggunakan kata sandi bawaan: **`password123`**

| ID Penghuni | Nama Lengkap | Kamar | Email Login | Nomor HP Login | Kata Sandi | Status Akun & Tagihan |
|---|---|---|---|---|---|---|
| `TNT-001` | Nadia Salsabila Siregar | **2** (Lt. 1 • Kecil AC Rp1,3jt) | `nadia@gmail.com` | `081260001111` | `password123` | **Aktif** — Tagihan Belum Bayar (Jatuh Tempo H-2) |
| `TNT-002` | Rizky Pratama Ginting | **23** (Lt. 3 • Besar AC Rp1,5jt) | `rizky@gmail.com` | `081260002222` | `password123` | **Aktif** — Tagihan Terlambat 3 Hari (+Denda Rp150.000) |
| `TNT-003` | Kevin Immanuel Simanjuntak | **24** (Lt. 3 • Kecil Kipas Rp900rb) | `kevin@gmail.com` | `081260003333` | `password123` | **Aktif** — Tagihan Sudah Lunas (Sewa 3 Bulan) |
| `TNT-004` | Dinda Maharani Nasution | **12** (Sudah Keluar) | `dinda@gmail.com` | `081260004444` | `password123` | **Nonaktif** — Uji blokir login penghuni keluar (FR-21) |
| `TNT-100` | Penghuni Kamar 3 | **3** (Lt. 1 • Kecil Kipas Rp900rb) | `kamar3@gmail.com` | `081269990000` | `password123` | **Aktif** |
| `TNT-101` | Penghuni Kamar 7 | **7** (Lt. 1 • Kecil Kipas Rp900rb) | `kamar7@gmail.com` | `081269990001` | `password123` | **Aktif** |
| `TNT-102` | Penghuni Kamar 11 | **11** (Lt. 2 • Besar AC Rp1,5jt) | `kamar11@gmail.com` | `081269990002` | `password123` | **Aktif** |
| `TNT-103` | Penghuni Kamar 15 | **15** (Lt. 2 • Kecil AC Rp1,3jt) | `kamar15@gmail.com` | `081269990003` | `password123` | **Aktif** |
| `TNT-104` | Penghuni Kamar 17 | **17** (Lt. 2 • Besar AC Rp1,5jt) | `kamar17@gmail.com` | `081269990004` | `password123` | **Aktif** |
| `TNT-105` | Penghuni Kamar 25 | **25** (Lt. 3 • Kecil AC Rp1,3jt) | `kamar25@gmail.com` | `081269990005` | `password123` | **Aktif** |
| `TNT-106` | Penghuni Kamar 29 | **29** (Lt. 3 • Besar AC Rp1,5jt) | `kamar29@gmail.com` | `081269990006` | `password123` | **Aktif** |
| `TNT-107` | Penghuni Kamar 35 | **35** (Lt. 4 • Besar AC Rp1,5jt) | `kamar35@gmail.com` | `081269990007` | `password123` | **Aktif** |
| `TNT-108` | Penghuni Kamar 36 | **36** (Lt. 4 • Besar AC Rp1,5jt) | `kamar36@gmail.com` | `081269990008` | `password123` | **Aktif** |

---

## 3. Daftar 13 Tabel Database PostgreSQL (`estopa_kos`) — Skema UUID & RBAC Bahasa Indonesia
Di **pgAdmin 4** (`Databases` -> `estopa_kos` -> `Schemas` -> `public` -> `Tables`), seluruh tabel menggunakan `UUID` dan RBAC (`akun` & `peran_akun`) tanpa tabel pengeluaran:

1. **`akun`** — Satu-satunya tempat penyimpanan kredensial (`id`, `email`, `no_hp`, `password_hash`, `aktif`, `dibuat_pada`, `diperbarui_pada`)
2. **`peran_akun`** — Role-Based Access Control (`id`, `akun_id`, `peran` IN `'admin'`, `'penghuni'`)
3. **`riwayat_reset_sandi`** — Audit trail reset sandi oleh admin (`id`, `akun_id`, `email_akun_snapshot`, `direset_oleh`, `dibuat_pada`)
4. **`kamar`** — Data 39 kamar di 4 lantai (`id`, `nomor_kamar`, `lantai`, `tipe`, `harga_per_bulan`, `fasilitas` JSONB, `status` IN `'tersedia'`, `'ditahan'`, `'terisi'`, `ditahan_sampai`)
5. **`penghuni`** — Biodata penghuni terhubung ke `akun` (`id`, `akun_id`, `kamar_id`, `riwayat_nomor_kamar`, `nama_lengkap`, `alamat_asal`, `nama_orang_tua`, `no_hp_orang_tua`, `nomor_ktp`, `url_ktp`, `tanggal_masuk`, `tanggal_keluar`, `periode_bayar_bulan`, `dibayar_sampai`, `status`)
6. **`pemesanan`** — Tahan kamar 20 menit (`id`, `kamar_id`, `penghuni_id`, `durasi_bulan`, `jumlah`, `status`, `kedaluwarsa_pada`, `dibayar_pada`)
7. **`tagihan`** — Tagihan sewa rutin & denda (`id`, `penghuni_id`, `nama_penghuni_snapshot`, `nomor_kamar_snapshot`, `periode_bulan`, `periode_mulai`, `periode_selesai`, `jatuh_tempo`, `biaya_kamar`, `biaya_air`, `biaya_admin`, `denda`, `jumlah_hari_terlambat`, `total_tagihan`, `status`)
8. **`pembayaran`** — Pencatatan dana masuk & sumber dana (`id`, `pemesanan_id`, `tagihan_id`, `penghuni_id`, `nama_penghuni_snapshot`, `nomor_kamar_snapshot`, `jenis_pembayaran` IN `'pemesanan_awal'`, `'tagihan_rutin'`, `jumlah`, `id_order_gateway`, `qr_code_url`, `status`, `dibayar_pada`)
9. **`keluhan`** — Laporan kerusakan fasilitas (`id`, `penghuni_id`, `kamar_id`, `kategori`, `deskripsi`, `url_foto`, `status` IN `'diajukan'`, `'diproses'`, `'selesai'`, `catatan_admin`, `diselesaikan_pada`)
10. **`pengumuman`** — Papan pengumuman digital (`id`, `judul`, `isi`, `tanggal_pengumuman`, `dibuat_oleh`, `dibuat_pada`)
11. **`pengumuman_dibaca`** — Status baca pengumuman (`id`, `pengumuman_id`, `penghuni_id`, `dibaca_pada`)
12. **`notifikasi`** — Log notifikasi sistem & pengiriman email (`id`, `akun_id`, `judul`, `isi`, `tipe`, `sudah_dibaca`, `kirim_email`, `dibuat_pada`)
13. **`webhook_terproses`** — Kunci idempotensi payment gateway (`kunci_webhook`, `waktu_diproses`)
