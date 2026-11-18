# Dokumen Perancangan Teknis (Sprint 2 & Kontrak API): Estopa Kos

Dokumen ini melengkapi [PRD.md](file:///c:/contohaplikasi/cntohaplikasi/docs/PRD.md) dan [PROJECT_PLAN.md](file:///c:/contohaplikasi/cntohaplikasi/docs/PROJECT_PLAN.md) dengan diagram UML, ERD database, dan kontrak endpoint API untuk tim pengembang D-4 TRPL Politeknik Negeri Medan.

---

## 1. Entity-Relationship Diagram (ERD)

```mermaid
erDiagram
    USERS ||--o| TENANTS : "memiliki profil"
    ROOMS ||--o{ BOOKING_HOLDS : "ditahan sementara (20m)"
    ROOMS ||--o| TENANTS : "ditempati oleh"
    TENANTS ||--o{ INVOICES : "ditagih"
    TENANTS ||--o{ PAYMENTS : "membayar"
    TENANTS ||--o{ COMPLAINTS : "melaporkan"
    TENANTS ||--o{ ANNOUNCEMENT_READS : "membaca"
    ANNOUNCEMENTS ||--o{ ANNOUNCEMENT_READS : "tercatat dibaca"

    ROOMS {
        string id PK
        string room_number UK
        int floor "1 s.d. 4 (39 kamar)"
        int price_per_month
        string gender "PUTRA / PUTRI"
        string facilities_json
        string status "AVAILABLE / HELD / OCCUPIED"
        datetime hold_expires_at
    }

    TENANTS {
        string id PK
        string room_id FK
        string full_name
        string phone UK
        string email UK
        string password_hash "NFR-02"
        string origin_address
        string parent_name
        string parent_phone
        string ktp_number
        string ktp_file_path "Hanya Admin (NFR-03)"
        boolean ktp_consent "NFR-04"
        boolean is_active "Nonaktif saat kamar dikosongkan (FR-21)"
        date lease_start_date
        date lease_end_date
    }

    BOOKING_HOLDS {
        string id PK
        string room_id FK
        int months "1, 3, 6, 12"
        int total_amount
        string qr_payload "Berlaku 20 menit (FR-14)"
        datetime expires_at
        string status "PENDING / PAID / EXPIRED"
    }

    INVOICES {
        string id PK
        string tenant_id FK
        int selected_months "1, 3, 6, 12 (FR-01)"
        int room_subtotal
        int water_subtotal "Rp35.000 x bulan"
        int transaction_fee "Rp4.000"
        int late_days
        int late_fee_subtotal "Rp50.000 x hari (FR-04)"
        int total_amount
        date due_date
        string status "UNPAID / OVERDUE / PAID"
        string qr_payload "Berlaku 24 jam (FR-03)"
        datetime qr_expires_at
    }

    PAYMENTS {
        string id PK
        string tenant_id FK
        string invoice_id FK
        string payment_type "BOOKING / INVOICE"
        int total_amount
        string gateway_ref
        datetime paid_at
    }

    EXPENSES {
        string id PK
        string title
        string category
        int amount
        date expense_date
        string notes
    }

    COMPLAINTS {
        string id PK
        string tenant_id FK
        string category
        string description
        string photo_path
        string status "MASUK / DIPROSES / SELESAI"
        string admin_note
        datetime created_at
    }

    ANNOUNCEMENTS {
        string id PK
        string title
        string content
        datetime created_at
    }

    ANNOUNCEMENT_READS {
        string announcement_id FK
        string tenant_id FK
        datetime read_at
    }
```

---

## 2. Alur Pemesanan Kamar & QR 20 Menit (`FR-12` s.d. `FR-17`)

```mermaid
sequenceDiagram
    actor Calon as Calon Penghuni
    participant App as Aplikasi Flutter
    participant API as Backend Estopa Kos
    participant GW as Payment Gateway (Sandbox)
    actor Admin as Admin / Pemilik

    Calon->>App: Pilih kamar kosong & isi biodata + unggah KTP + centang persetujuan (FR-13)
    App->>API: POST /api/bookings (durasi 1/3/6/12 bln)
    API->>API: Kunci status kamar = HELD (20 menit)
    API->>GW: Request QRIS Pemesanan (exp = 20 menit)
    GW-->>API: qr_string & reference
    API-->>App: Tampilkan QRIS & Countdown 20:00 (FR-14)
    alt Pembayaran Berhasil Sebelum 20 Menit (FR-16, FR-17)
        GW->>API: POST /api/webhooks/payment (status = SUCCESS)
        API->>API: Ubah kamar = OCCUPIED, buat akun penghuni aktif, simpan riwayat bayar
        API-->>Calon: Kirim Email info pembayaran & akun + Tampilkan Pop-up Terima Kasih
        API-->>Admin: Push Notification pemesanan baru
    else Waktu 20 Menit Habis (FR-15, NFR-04)
        API->>API: Scheduler mendeteksi hold_expires_at lewat
        API->>API: Kembalikan kamar = AVAILABLE, hapus biodata sementara & file KTP
    end
```

---

## 3. Alur Tagihan Otomatis, Denda & QR 24 Jam (`FR-01` s.d. `FR-08`)

```mermaid
flowchart TD
    A["Akhir Masa Sewa Penghuni Aktif"] --> B["Terbit Tagihan Otomatis (FR-01)"]
    B --> C["Kirim Pengingat H-3, H-2, H-1, H-0 via Sistem & Email (FR-05)"]
    C --> D{"Sudah Dibayar Saat Jatuh Tempo?"}
    D -- "Belum Lewat Jatuh Tempo" --> E["Status: Belum Bayar"]
    D -- "Melewati Jatuh Tempo" --> F["Status Otomatis: Terlambat + Denda Rp50.000/hari (FR-04)"]
    E --> G["Penghuni Pilih Bulan (1, 3, 6, 12) & Buat QR 24 Jam (FR-02, FR-03)"]
    F --> G
    G --> H["Hitung Total = (Harga Kamar x Bulan) + (Rp35.000 x Bulan) + Rp4.000 + Denda"]
    H --> I["Webhook Gateway: Pembayaran Berhasil (FR-08)"]
    I --> J["Status = Lunas, Masuk Riwayat & Rekap Pemasukan, Jadwalkan Tagihan Berikutnya"]
```

---

## 4. Kontrak Endpoint REST API per Pembagian Tim

### A. Modul Pemesanan & Pembayaran (PIC Usulan: Andrew)
- `GET /api/rooms` — Daftar 39 kamar (filter `floor`, `gender`, `status`) tanpa autentikasi (`FR-12`).
- `POST /api/bookings` — Buat pemesanan baru, unggah KTP (`multipart/form-data`), tahan kamar 20 menit, kembalikan QRIS 20 menit (`FR-13`, `FR-14`).
- `POST /api/webhooks/payment-gateway` — Terima callback status bayar pemesanan maupun tagihan (`FR-08`, `FR-16`).

### B. Modul Tagihan, Keuangan & Scheduler (PIC Usulan: Henri)
- `GET /api/invoices` — Daftar tagihan penghuni (atau daftar belum bayar/terlambat untuk Admin `FR-06`, `FR-07`).
- `POST /api/invoices/{id}/qr` — Pilih jumlah bulan (`1, 3, 6, 12`) dan terbitkan QR tagihan masa berlaku 24 jam beserta kalkulasi denda terbaru (`FR-02`, `FR-03`, `FR-04`).
- `GET /api/finance/summary` — Rekap pemasukan otomatis, pengeluaran, dan saldo bersih (`FR-09`, `FR-10`).
- `POST /api/finance/expenses` — Catat pengeluaran kos oleh Admin (`FR-11`).

### C. Modul Kamar, Penghuni, Keluhan & Pengumuman (PIC Usulan: Sutanto)
- `POST /api/auth/login` — Login dengan email atau nomor HP + password (`FR-29`), tolak jika `is_active == false` (`FR-21`).
- `GET /api/admin/tenants` & `POST /api/admin/tenants` & `PUT /api/admin/tenants/{id}` — Kelola data penghuni & KTP (`FR-18`, `FR-19`).
- `POST /api/admin/tenants/{id}/reset-password` — Reset kata sandi penghuni oleh Admin (`FR-22`).
- `POST /api/admin/rooms/{id}/vacate` — Kosongkan kamar & nonaktifkan akun penghuni sebelumnya (`FR-21`).
- `GET /api/complaints` & `POST /api/complaints` & `PATCH /api/complaints/{id}/status` — Lapor dan ubah status keluhan (`FR-23` s.d. `FR-25`).
- `GET /api/announcements` & `POST /api/announcements` & `POST /api/announcements/{id}/read` — Pengumuman dan pencatatan status sudah dibaca (`FR-26` s.d. `FR-28`).
