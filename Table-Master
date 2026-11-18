-- =====================================================================
-- Bank Arunika: Credit Risk Analysis 2023-2026
-- File: 01_table_master.sql
--
-- Tujuan:
-- Membuat tabel master (schema mart) dari data yang sudah bersih
-- (schema clean). Tabel master berisi kolom bantu (flag, kelompok,
-- umur kredit) supaya pertanyaan bisnis bisa dijawab dengan query
-- yang pendek dan dashboard Power BI tidak perlu rumus yang rumit.
--
-- Alur data:
--   staging (data mentah, 7 tabel)
--     -> clean (5 tabel, setelah 34 temuan kualitas data ditangani,
--               lihat docs/data_quality_log.md)
--       -> mart (tabel master, file ini)
--         -> 02_analysis_queries.sql dan 03_dashboard_views.sql
--           -> Power BI
--
-- Urutan menjalankan (karena ada tabel yang bergantung pada tabel lain):
--   1. mart.customers
--   2. mart.loan_applications
--   3. mart.loan_monthly_snapshot
--   4. mart.loans          (butuh mart.loan_monthly_snapshot)
--   5. mart.npl_bulanan    (butuh mart.loan_monthly_snapshot)
--
-- Database: PostgreSQL
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS mart;


-- ---------------------------------------------------------------------
-- 1. mart.customers
--    Satu baris = satu nasabah (pemohon kredit), 4.802 baris.
--    Salinan data nasabah yang sudah bersih, supaya semua tabel analisis
--    ada di satu schema.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS mart.customers;

CREATE TABLE mart.customers AS
SELECT *
FROM clean.customers;


-- ---------------------------------------------------------------------
-- 2. mart.loan_applications
--    Satu baris = satu pengajuan kredit (disetujui, ditolak, atau batal),
--    5.260 baris.
--
--    Kolom bantu:
--    kelompok_skor   : skor kredit dikelompokkan supaya risiko bisa
--                      dibandingkan antarkelompok. Angka di depan
--                      ("1.", "2.", ...) supaya urutannya benar saat
--                      diurutkan. Skor kosong = "Tidak diketahui".
--    flag_disetujui  : 1 kalau pengajuan disetujui, 0 kalau tidak.
--                      Approval rate = SUM(flag_disetujui) / COUNT(*).
--    bulan_pengajuan : tanggal pengajuan dibulatkan ke awal bulan,
--                      untuk tren bulanan.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS mart.loan_applications;

CREATE TABLE mart.loan_applications AS
SELECT a.*,
       CASE
         WHEN a.credit_score IS NULL THEN '5. Tidak diketahui'
         WHEN a.credit_score < 550   THEN '1. < 550'
         WHEN a.credit_score < 650   THEN '2. 550-649'
         WHEN a.credit_score < 750   THEN '3. 650-749'
         ELSE '4. 750+'
       END AS kelompok_skor,
       CASE WHEN a.status = 'APPROVED' THEN 1 ELSE 0 END AS flag_disetujui,
       DATE_TRUNC('month', a.application_date)::date AS bulan_pengajuan
FROM clean.loan_applications a;


-- ---------------------------------------------------------------------
-- 3. mart.loan_monthly_snapshot
--    Satu baris = satu kredit pada satu akhir bulan (foto kondisi
--    kredit: sisa pokok, DPD, status), 55.434 baris.
--
--    Kolom bantu:
--    kolektibilitas : kualitas kredit 1-5 berdasarkan DPD (hari telat):
--                     1 Lancar (DPD 0), 2 Dalam Perhatian Khusus (1-90),
--                     3 Kurang Lancar (91-120), 4 Diragukan (121-180),
--                     5 Macet (> 180).
--    flag_npl       : 1 kalau kredit NPL, yaitu telat lebih dari 90 hari
--                     (kolektibilitas 3-5).
--    vintage        : bulan kredit cair (angkatan kredit).
--    mob            : month on book, umur kredit dalam bulan sejak cair.
--                     Dipakai supaya angkatan dibandingkan di umur yang
--                     sama (misalnya semua di MOB 6).
--    product, branch_id, disbursement_date diambil dari tabel loans
--    supaya analisis per produk dan cabang tidak perlu JOIN lagi.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS mart.loan_monthly_snapshot;

CREATE TABLE mart.loan_monthly_snapshot AS
SELECT s.loan_id,
       s.snapshot_date,
       s.outstanding_principal,
       s.dpd,
       s.loan_status,
       CASE
         WHEN s.dpd = 0                THEN 1
         WHEN s.dpd BETWEEN 1 AND 90   THEN 2
         WHEN s.dpd BETWEEN 91 AND 120 THEN 3
         WHEN s.dpd BETWEEN 121 AND 180 THEN 4
         ELSE 5
       END AS kolektibilitas,
       CASE WHEN s.dpd > 90 THEN 1 ELSE 0 END AS flag_npl,
       l.product,
       l.branch_id,
       l.disbursement_date,
       DATE_TRUNC('month', l.disbursement_date)::date AS vintage,
       ((EXTRACT(YEAR FROM s.snapshot_date) - EXTRACT(YEAR FROM l.disbursement_date)) * 12
        + (EXTRACT(MONTH FROM s.snapshot_date) - EXTRACT(MONTH FROM l.disbursement_date)))::int AS mob
FROM clean.loan_monthly_snapshot s
JOIN clean.loans l ON l.loan_id = s.loan_id;


-- ---------------------------------------------------------------------
-- 4. mart.loans
--    Satu baris = satu kredit yang cair, 3.420 baris.
--
--    Kolom bantu:
--    vintage      : bulan kredit cair (angkatan kredit).
--    flag_fpd     : first payment default. 1 kalau cicilan pertama tidak
--                   pernah dibayar. Tanda awal kredit bermasalah sejak
--                   awal, misalnya data pemohon tidak benar.
--    pernah_npl   : 1 kalau kredit pernah NPL di salah satu bulan.
--                   Ever-NPL rate = SUM(pernah_npl) / COUNT(*), dihitung
--                   untuk kredit yang cair sampai 30 Sep 2025 supaya
--                   setiap kredit punya riwayat minimal 12 bulan.
--    dpd_terburuk : DPD tertinggi sepanjang umur kredit.
--    status_akhir : status di snapshot terakhir
--                   (ACTIVE, CLOSED, atau WRITE_OFF).
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS mart.loans;

CREATE TABLE mart.loans AS
WITH cicilan_pertama AS (
  SELECT loan_id,
         CASE WHEN payment_date IS NULL THEN 1 ELSE 0 END AS flag_fpd
  FROM clean.repayments
  WHERE installment_no = 1
),
ringkasan_rapor AS (
  SELECT loan_id,
         MAX(flag_npl) AS pernah_npl,
         MAX(dpd)      AS dpd_terburuk
  FROM mart.loan_monthly_snapshot
  GROUP BY loan_id
),
rapor_terakhir AS (
  SELECT DISTINCT ON (loan_id)
         loan_id,
         loan_status AS status_akhir
  FROM mart.loan_monthly_snapshot
  ORDER BY loan_id, snapshot_date DESC
)
SELECT l.*,
       DATE_TRUNC('month', l.disbursement_date)::date AS vintage,
       f.flag_fpd,
       r.pernah_npl,
       r.dpd_terburuk,
       t.status_akhir
FROM clean.loans l
LEFT JOIN cicilan_pertama f ON f.loan_id = l.loan_id
LEFT JOIN ringkasan_rapor r ON r.loan_id = l.loan_id
LEFT JOIN rapor_terakhir  t ON t.loan_id = l.loan_id;


-- ---------------------------------------------------------------------
-- 5. mart.npl_bulanan
--    Satu baris = satu akhir bulan, ringkasan seluruh portofolio.
--
--    Rumus:
--    total_outstanding     : sisa pokok semua kredit, tanpa kredit yang
--                            sudah dihapus buku (WRITE_OFF).
--    outstanding_npl       : sisa pokok kredit NPL (flag_npl = 1).
--    npl_persen            : NPL gross = outstanding_npl / total_outstanding
--                            x 100. Batas aman bank: 5%.
--    jumlah_write_off      : jumlah kredit berstatus WRITE_OFF bulan itu.
--    outstanding_write_off : sisa pokok kredit yang dihapus buku bulan itu.
--                            Dipakai untuk membuktikan bahwa penurunan NPL
--                            2026 berasal dari hapus buku.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS mart.npl_bulanan;

CREATE TABLE mart.npl_bulanan AS
SELECT snapshot_date AS bulan,
       COUNT(*) FILTER (WHERE loan_status <> 'WRITE_OFF') AS jumlah_kredit,
       SUM(outstanding_principal) FILTER (WHERE loan_status <> 'WRITE_OFF') AS total_outstanding,
       SUM(outstanding_principal * flag_npl) FILTER (WHERE loan_status <> 'WRITE_OFF') AS outstanding_npl,
       ROUND(100.0 * SUM(outstanding_principal * flag_npl) FILTER (WHERE loan_status <> 'WRITE_OFF')
                   / SUM(outstanding_principal)            FILTER (WHERE loan_status <> 'WRITE_OFF'), 2) AS npl_persen,
       COUNT(*) FILTER (WHERE loan_status = 'WRITE_OFF') AS jumlah_write_off,
       COALESCE(SUM(outstanding_principal) FILTER (WHERE loan_status = 'WRITE_OFF'), 0) AS outstanding_write_off
FROM mart.loan_monthly_snapshot
GROUP BY snapshot_date
ORDER BY snapshot_date;


-- ---------------------------------------------------------------------
-- Cek hasil: jumlah baris setiap tabel master
-- Hasil yang diharapkan: customers 4.802, loan_applications 5.260,
-- loan_monthly_snapshot 55.434, loans 3.420, npl_bulanan 45 bulan.
-- ---------------------------------------------------------------------
SELECT 'customers' AS tabel, COUNT(*) AS jumlah_baris FROM mart.customers
UNION ALL SELECT 'loan_applications', COUNT(*) FROM mart.loan_applications
UNION ALL SELECT 'loan_monthly_snapshot', COUNT(*) FROM mart.loan_monthly_snapshot
UNION ALL SELECT 'loans', COUNT(*) FROM mart.loans
UNION ALL SELECT 'npl_bulanan', COUNT(*) FROM mart.npl_bulanan;
