# PRD: Sistem Informasi Manajemen Estopa Kos (Aplikasi Flutter)

Product Requirements Document. Mata kuliah Rekayasa Perangkat Lunak, D-4 TRPL Politeknik Negeri Medan. Dosen: Cut Try Utari, S.T., M.Kom. Product Owner: Haziq Al Fareza. Status: Draf 1.

## 1. Ringkasan Produk

Aplikasi Android untuk mengelola Estopa Kos (39 kamar, 4 lantai, Jl. Sei Padang, Medan Baru) dalam satu tempat: informasi kamar kosong, pemesanan online, tagihan otomatis dengan pengingat, pembayaran lewat payment gateway, pencatatan keuangan, data penghuni, laporan keluhan, dan pengumuman. Aplikasi dibangun dengan Flutter dan dipakai oleh tiga peran: calon penghuni, penghuni, dan admin (pemilik).

## 2. Latar Belakang dan Masalah

Pengelolaan saat ini manual lewat aplikasi percakapan dan catatan kertas. Data diperoleh dari wawancara pemilik dan tiga penghuni (7 November 2026).

| No | Masalah | Dampak |
|---|---|---|
| 1 | Penagihan sewa terlambat dan bergantung pengingat manual | Pemasukan tidak tepat waktu, pemilik menagih berulang |
| 2 | Penghuni berulang kali menanyakan nomor rekening | Pembayaran tidak efisien |
| 3 | Bukti bayar dan pencatatan keuangan tersebar di percakapan | Keuangan sulit direkap |
| 4 | Data penghuni di kertas dan pernah hilang | Data identitas tidak terjamin |
| 5 | Info kamar kosong tidak terbuka (sekitar 10 penanya per minggu) | Pertanyaan berulang, calon penghuni sulit dapat info |
| 6 | Keluhan tanpa alur dan respons tidak menentu | Penghuni tidak tahu status keluhan |
| 7 | Pengumuman sering terlewat | Informasi penting tidak sampai |
| 8 | Biaya air tidak selalu terbayar | Kos menombok |

## 3. Tujuan dan Indikator Keberhasilan

| Tujuan | Indikator (target usulan) |
|---|---|
| Penagihan tertib | Tagihan terbit otomatis untuk semua penghuni aktif; pengingat terkirim tepat jadwal |
| Pembayaran tercatat otomatis | Semua pembayaran lewat gateway masuk riwayat tanpa input manual |
| Info kamar terbuka | Calon penghuni melihat kamar kosong tanpa bertanya ke pemilik |
| Data terpusat dan aman | Seluruh data penghuni dan KTP tersimpan di sistem, hanya admin yang bisa mengakses |
| Keluhan dan pengumuman terpantau | Setiap keluhan punya status; pengumuman tercatat sudah dibaca |

## 4. Pengguna

| Pengguna | Kebutuhan utama |
|---|---|
| Admin (pemilik/pengelola) | Penagihan otomatis, rekap keuangan, data penghuni aman, keluhan terkelola |
| Penghuni | Tagihan dan nominal jelas, pengingat, bayar mudah, pantau keluhan, terima pengumuman |
| Calon penghuni | Lihat kamar kosong kapan saja dan memesan tanpa datang langsung |

## 5. Ruang Lingkup

**Dikerjakan:** satu kos (Estopa Kos), enam fitur, pembayaran pemesanan dan tagihan lewat payment gateway (sandbox), akun penghuni otomatis setelah bayar, notifikasi sistem dan email, platform Android.

**Tidak dikerjakan:** pembayaran tunai, refund otomatis, cicilan, fitur ganti/lupa kata sandi oleh penghuni (diganti reset oleh admin), penagihan di luar sistem, multi-kos, pengelolaan karyawan, akuntansi lengkap, integrasi perangkat fisik.

## 6. Fitur, User Story, dan Kriteria Penerimaan

- **Fitur 1: Tagihan dan Pengingat (FR-01 s.d. FR-07)**
- **Fitur 2: Pembayaran dan Pencatatan Keuangan (FR-08 s.d. FR-11)**
- **Fitur 3: Info Kamar Kosong dan Pemesanan (FR-12 s.d. FR-17)**
- **Fitur 4: Data Penghuni dan Kamar (FR-18 s.d. FR-22)**
- **Fitur 5: Laporan Keluhan (FR-23 s.d. FR-25)**
- **Fitur 6: Pengumuman (FR-26 s.d. FR-28)**
- **Umum: Login (FR-29)**
