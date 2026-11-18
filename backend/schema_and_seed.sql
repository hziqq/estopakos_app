-- ============================================================================
-- SKEMA DATABASE POSTGRESQL (pgAdmin 4) - ESTOPA KOS (100% BAHASA INDONESIA)
-- ============================================================================
-- Lokasi Kos : Jl. Sei Padang, Kec. Medan Baru, Kota Medan
-- Kapasitas  : 39 Kamar di 4 Lantai
-- Email Admin: haziqalfareza06@gmail.com
-- ============================================================================

DROP TABLE IF EXISTS
  webhook_terproses, notifikasi, pengumuman_dibaca, pengumuman, keluhan,
  pengeluaran, pembayaran, tagihan, pemesanan, penghuni, kamar,
  riwayat_reset_sandi, peran_akun, akun,
  status_baca_pengumuman, pemesanan_sementara,
  announcement_reads, announcements, complaints, expenses, payments,
  invoices, booking_holds, tenants, rooms, notifications, processed_webhooks
CASCADE;

DROP FUNCTION IF EXISTS set_diperbarui_pada() CASCADE;

-- 0. Fungsi pembantu: isi kolom diperbarui_pada otomatis saat UPDATE
CREATE OR REPLACE FUNCTION set_diperbarui_pada() RETURNS TRIGGER AS $$
BEGIN
  NEW.diperbarui_pada = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 1. akun: satu-satunya tempat email, no_hp, dan password
CREATE TABLE IF NOT EXISTS akun (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email           VARCHAR(120) NOT NULL,
  no_hp           VARCHAR(30)  NOT NULL UNIQUE,
  password_hash   TEXT         NOT NULL,
  aktif           BOOLEAN      NOT NULL DEFAULT TRUE,
  dibuat_pada     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  diperbarui_pada TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_akun_email ON akun (LOWER(email));

-- 2. peran_akun (RBAC)
CREATE TABLE IF NOT EXISTS peran_akun (
  id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  akun_id  UUID NOT NULL REFERENCES akun(id) ON DELETE CASCADE,
  peran    VARCHAR(20) NOT NULL CHECK (peran IN ('admin', 'penghuni')),
  UNIQUE (akun_id, peran)
);

-- 3. riwayat_reset_sandi (audit trail)
CREATE TABLE IF NOT EXISTS riwayat_reset_sandi (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  akun_id              UUID NOT NULL REFERENCES akun(id) ON DELETE CASCADE,
  email_akun_snapshot  VARCHAR(120) NOT NULL,
  direset_oleh         UUID NULL REFERENCES akun(id) ON DELETE SET NULL,
  dibuat_pada          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_riwayat_reset_akun ON riwayat_reset_sandi (akun_id);

-- 4. kamar
CREATE TABLE IF NOT EXISTS kamar (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nomor_kamar      VARCHAR(10) NOT NULL UNIQUE,
  lantai           INT         NOT NULL CHECK (lantai BETWEEN 1 AND 4),
  tipe             VARCHAR(10) NOT NULL CHECK (tipe IN ('putri', 'putra')),
  harga_per_bulan  INT         NOT NULL CHECK (harga_per_bulan > 0),
  fasilitas        JSONB       NOT NULL DEFAULT '[]'::jsonb,
  url_foto         TEXT        NULL,
  status           VARCHAR(15) NOT NULL DEFAULT 'tersedia'
                     CHECK (status IN ('tersedia', 'ditahan', 'terisi')),
  ditahan_sampai   TIMESTAMPTZ NULL,
  dibuat_pada      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  diperbarui_pada  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (status <> 'ditahan' OR ditahan_sampai IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS ix_kamar_status ON kamar (status);

-- 5. penghuni (email & no_hp ada di akun, tidak diduplikasi)
CREATE TABLE IF NOT EXISTS penghuni (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  akun_id              UUID NOT NULL UNIQUE REFERENCES akun(id) ON DELETE CASCADE,
  kamar_id             UUID NULL REFERENCES kamar(id) ON DELETE SET NULL,
  riwayat_nomor_kamar  VARCHAR(30) NULL,
  nama_lengkap         VARCHAR(120) NOT NULL,
  alamat_asal          TEXT NOT NULL,
  nama_orang_tua       VARCHAR(120) NOT NULL,
  no_hp_orang_tua      VARCHAR(30) NOT NULL,
  nomor_ktp            VARCHAR(32) NOT NULL,
  url_ktp              VARCHAR(150) NOT NULL,
  ktp_data             TEXT NULL,
  persetujuan_ktp      BOOLEAN NOT NULL DEFAULT TRUE,
  tanggal_masuk        DATE NULL,
  tanggal_keluar       DATE NULL,
  periode_bayar_bulan  INT NOT NULL DEFAULT 1 CHECK (periode_bayar_bulan IN (1, 3, 6, 12)),
  dibayar_sampai       DATE NULL,
  status               VARCHAR(25) NOT NULL DEFAULT 'menunggu_pembayaran'
                         CHECK (status IN ('menunggu_pembayaran', 'aktif', 'nonaktif')),
  dibuat_pada          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  diperbarui_pada      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (tanggal_keluar IS NULL OR tanggal_masuk IS NULL OR tanggal_keluar >= tanggal_masuk)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_penghuni_kamar_berjalan
  ON penghuni (kamar_id)
  WHERE kamar_id IS NOT NULL AND status IN ('menunggu_pembayaran', 'aktif');

-- 6. pemesanan (hold kamar 20 menit)
CREATE TABLE IF NOT EXISTS pemesanan (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kamar_id          UUID NOT NULL REFERENCES kamar(id) ON DELETE CASCADE,
  penghuni_id       UUID NOT NULL REFERENCES penghuni(id) ON DELETE CASCADE,
  durasi_bulan      INT  NOT NULL CHECK (durasi_bulan IN (1, 3, 6, 12)),
  jumlah            INT  NOT NULL CHECK (jumlah > 0),
  status            VARCHAR(20) NOT NULL DEFAULT 'menunggu'
                      CHECK (status IN ('menunggu', 'dibayar', 'kedaluwarsa', 'dibatalkan')),
  kedaluwarsa_pada  TIMESTAMPTZ NOT NULL,
  dibayar_pada      TIMESTAMPTZ NULL,
  dibuat_pada       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  diperbarui_pada   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_pemesanan_menunggu_per_kamar
  ON pemesanan (kamar_id) WHERE status = 'menunggu';

CREATE INDEX IF NOT EXISTS ix_pemesanan_kedaluwarsa
  ON pemesanan (kedaluwarsa_pada) WHERE status = 'menunggu';

CREATE INDEX IF NOT EXISTS ix_pemesanan_penghuni ON pemesanan (penghuni_id);

-- 7. tagihan (riwayat keuangan: RESTRICT, jangan ikut terhapus)
CREATE TABLE IF NOT EXISTS tagihan (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  penghuni_id              UUID NOT NULL REFERENCES penghuni(id) ON DELETE RESTRICT,
  nama_penghuni_snapshot   VARCHAR(120) NOT NULL,
  nomor_kamar_snapshot     VARCHAR(20)  NOT NULL,
  periode_bulan            INT  NOT NULL DEFAULT 1 CHECK (periode_bulan IN (1, 3, 6, 12)),
  periode_mulai            DATE NOT NULL,
  periode_selesai          DATE NOT NULL,
  jatuh_tempo              DATE NOT NULL,
  biaya_kamar              INT  NOT NULL CHECK (biaya_kamar >= 0),
  biaya_air                INT  NOT NULL DEFAULT 0 CHECK (biaya_air >= 0),
  biaya_admin              INT  NOT NULL DEFAULT 0 CHECK (biaya_admin >= 0),
  denda                    INT  NOT NULL DEFAULT 0 CHECK (denda >= 0),
  jumlah_hari_terlambat    INT  NOT NULL DEFAULT 0 CHECK (jumlah_hari_terlambat >= 0),
  total_tagihan            INT  NOT NULL,
  status                   VARCHAR(15) NOT NULL DEFAULT 'belum_dibayar'
                             CHECK (status IN ('belum_dibayar', 'terlambat', 'lunas')),
  qr_kedaluwarsa_pada      TIMESTAMPTZ NULL,
  pengingat_terkirim       JSONB NOT NULL DEFAULT '[]'::jsonb,
  dibayar_pada             TIMESTAMPTZ NULL,
  dibuat_pada              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  diperbarui_pada          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (periode_selesai > periode_mulai),
  CHECK (total_tagihan = biaya_kamar + biaya_air + biaya_admin + denda),
  UNIQUE (penghuni_id, periode_mulai)
);

CREATE INDEX IF NOT EXISTS ix_tagihan_status_tempo ON tagihan (status, jatuh_tempo);

-- 8. pembayaran (pencatatan dana masuk & sumber dana)
CREATE TABLE IF NOT EXISTS pembayaran (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pemesanan_id            UUID NULL REFERENCES pemesanan(id) ON DELETE SET NULL,
  tagihan_id              UUID NULL REFERENCES tagihan(id)   ON DELETE SET NULL,
  penghuni_id             UUID NULL REFERENCES penghuni(id)  ON DELETE SET NULL,
  nama_penghuni_snapshot  VARCHAR(120) NOT NULL,
  nomor_kamar_snapshot    VARCHAR(20)  NOT NULL,
  jenis_pembayaran        VARCHAR(20)  NOT NULL
                            CHECK (jenis_pembayaran IN ('pemesanan_awal', 'tagihan_rutin')),
  jumlah                  INT NOT NULL CHECK (jumlah > 0),
  id_order_gateway        VARCHAR(80) NOT NULL UNIQUE,
  qr_code_url             TEXT NOT NULL,
  status                  VARCHAR(20) NOT NULL DEFAULT 'menunggu'
                            CHECK (status IN ('menunggu', 'berhasil', 'gagal', 'kedaluwarsa')),
  dibayar_pada            TIMESTAMPTZ NULL,
  dibuat_pada             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  diperbarui_pada         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (num_nonnulls(pemesanan_id, tagihan_id) <= 1)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_pembayaran_menunggu_tagihan
  ON pembayaran (tagihan_id) WHERE status = 'menunggu' AND tagihan_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_pembayaran_menunggu_pemesanan
  ON pembayaran (pemesanan_id) WHERE status = 'menunggu' AND pemesanan_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_pembayaran_penghuni ON pembayaran (penghuni_id);

-- 9. keluhan
CREATE TABLE IF NOT EXISTS keluhan (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  penghuni_id       UUID NOT NULL REFERENCES penghuni(id) ON DELETE CASCADE,
  kamar_id          UUID NULL REFERENCES kamar(id) ON DELETE SET NULL,
  kategori          VARCHAR(60) NOT NULL,
  deskripsi         TEXT NOT NULL,
  url_foto          VARCHAR(150) NULL,
  status            VARCHAR(20) NOT NULL DEFAULT 'diajukan'
                      CHECK (status IN ('diajukan', 'diproses', 'selesai')),
  catatan_admin     TEXT NULL,
  diselesaikan_pada TIMESTAMPTZ NULL,
  dibuat_pada       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  diperbarui_pada   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_keluhan_penghuni ON keluhan (penghuni_id);
CREATE INDEX IF NOT EXISTS ix_keluhan_status ON keluhan (status);

-- 10-11. pengumuman & pengumuman_dibaca
CREATE TABLE IF NOT EXISTS pengumuman (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  judul               VARCHAR(150) NOT NULL,
  isi                 TEXT NOT NULL,
  tanggal_pengumuman  DATE NOT NULL DEFAULT CURRENT_DATE,
  dibuat_oleh         UUID NULL REFERENCES akun(id) ON DELETE SET NULL,
  dibuat_pada         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pengumuman_dibaca (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pengumuman_id  UUID NOT NULL REFERENCES pengumuman(id) ON DELETE CASCADE,
  penghuni_id    UUID NOT NULL REFERENCES penghuni(id)   ON DELETE CASCADE,
  dibaca_pada    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (pengumuman_id, penghuni_id)
);

CREATE INDEX IF NOT EXISTS ix_pengumuman_dibaca_penghuni ON pengumuman_dibaca (penghuni_id);

-- 12. notifikasi
CREATE TABLE IF NOT EXISTS notifikasi (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  akun_id       UUID NOT NULL REFERENCES akun(id) ON DELETE CASCADE,
  judul         VARCHAR(150) NOT NULL,
  isi           TEXT NOT NULL,
  tipe          VARCHAR(30) NOT NULL
                  CHECK (tipe IN ('tagihan', 'pembayaran', 'pengumuman', 'keluhan', 'sistem')),
  sudah_dibaca  BOOLEAN NOT NULL DEFAULT FALSE,
  kirim_email   BOOLEAN NOT NULL DEFAULT FALSE,
  dibuat_pada   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_notifikasi_akun_belum_dibaca
  ON notifikasi (akun_id, dibuat_pada DESC) WHERE sudah_dibaca = FALSE;

-- 13. webhook_terproses (idempotensi payment gateway)
CREATE TABLE IF NOT EXISTS webhook_terproses (
  kunci_webhook   VARCHAR(80) PRIMARY KEY,
  waktu_diproses  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
