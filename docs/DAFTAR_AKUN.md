# Daftar Akun Akses Aplikasi Estopa Kos

Berikut adalah seluruh akun bawaan (*seed data*) yang ada pada [estopa_store.dart](file:///c:/contohaplikasi/cntohaplikasi/lib/state/estopa_store.dart). Semua akun dapat login menggunakan **Email** maupun **Nomor HP** (`FR-29`).

---

## 1. Akun Admin (Pemilik / Pengelola)

| Peran | Nama | Email | Nomor HP | Kata Sandi | Hak Akses |
|---|---|---|---|---|---|
| **Admin** | Pemilik / Pengelola Estopa Kos | `admin@estopakos.id` | `08116001234` | `admin123` | Kelola 39 kamar, data penghuni & KTP (`NFR-03`), reset password (`FR-22`), tagihan & keuangan (`FR-07`, `FR-10`, `FR-11`), keluhan (`FR-24`), pengumuman (`FR-26`). |

---

## 2. Akun Penghuni Utama (Skenario Demo PRD)

| ID | Nama Lengkap | Kamar | Email | Nomor HP | Kata Sandi | Status Akun | Skenario Tagihan |
|---|---|---|---|---|---|---|---|
| `TNT-001` | Nadia Salsabila Siregar | `101` (Putri) | `nadia@mahasiswa.polmed.ac.id` | `081260001111` | `password123` | **Aktif** | Belum Bayar (Jatuh tempo H-2) |
| `TNT-002` | Rizky Pratama Ginting | `301` (Putra) | `rizky@mahasiswa.polmed.ac.id` | `081260002222` | `password123` | **Aktif** | Terlambat 3 hari (Denda Rp150.000) |
| `TNT-003` | Kevin Immanuel Simanjuntak | `305` (Putra) | `kevin@mahasiswa.polmed.ac.id` | `081260003333` | `password123` | **Aktif** | Sudah Lunas (Sewa 3 Bulan) |
| `TNT-004` | Dinda Maharani Nasution (Alumni) | `202 (Sudah Keluar)` | `dinda@alumni.polmed.ac.id` | `081260004444` | `password123` | **Nonaktif** | Uji blokir login akun nonaktif (`FR-21`) |

---

## 3. Akun Penghuni Kamar Lainnya (Kamar Terisi)

Semua akun di bawah berstatus **Aktif** dengan kata sandi default `password123`:

| ID | Nama | Kamar | Email | Nomor HP | Kata Sandi |
|---|---|---|---|---|---|
| `TNT-100` | Penghuni Kamar 102 | `102` (Putri) | `kamar102@estopakos.id` | `081269990000` | `password123` |
| `TNT-101` | Penghuni Kamar 104 | `104` (Putri) | `kamar104@estopakos.id` | `081269990001` | `password123` |
| `TNT-102` | Penghuni Kamar 201 | `201` (Putri) | `kamar201@estopakos.id` | `081269990002` | `password123` |
| `TNT-103` | Penghuni Kamar 203 | `203` (Putri) | `kamar203@estopakos.id` | `081269990003` | `password123` |
| `TNT-104` | Penghuni Kamar 205 | `205` (Putri) | `kamar205@estopakos.id` | `081269990004` | `password123` |
| `TNT-105` | Penghuni Kamar 302 | `302` (Putra) | `kamar302@estopakos.id` | `081269990005` | `password123` |
| `TNT-106` | Penghuni Kamar 304 | `304` (Putra) | `kamar304@estopakos.id` | `081269990006` | `password123` |
| `TNT-107` | Penghuni Kamar 401 | `401` (Putra) | `kamar401@estopakos.id` | `081269990007` | `password123` |
| `TNT-108` | Penghuni Kamar 402 | `402` (Putra) | `kamar402@estopakos.id` | `081269990008` | `password123` |

> **Catatan Database**: Saat ini aplikasi masih menyimpan data secara **in-memory (RAM lokal)** — belum terhubung ke **SQLite** maupun **PostgreSQL**. Setiap perubahan saat aplikasi berjalan tidak tersimpan setelah aplikasi ditutup/di-restart.
