-- =====================================================================
-- Bank Arunika: query untuk pertanyaan bisnis
-- Database: PostgreSQL. Schema: clean (data bersih), mart (siap analisis)
-- =====================================================================


-- Q1. Pencairan per produk, Jan-Jun setiap tahun (Rp juta)
--     Hanya Jan-Jun, karena pencairan terakhir 9 Jul 2026.
SELECT EXTRACT(YEAR FROM disbursement_date) AS tahun,
       product,
       COUNT(*) AS jumlah_kredit,
       ROUND(SUM(principal_amount) / 1000000) AS pencairan_juta
FROM mart.loans
WHERE EXTRACT(MONTH FROM disbursement_date) <= 6
GROUP BY 1, 2
ORDER BY 1, 2;


-- Q2. Komposisi channel pengajuan per tahun (% pengajuan)
SELECT EXTRACT(YEAR FROM application_date) AS tahun,
       channel,
       COUNT(*) AS jumlah_pengajuan,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY EXTRACT(YEAR FROM application_date)), 1) AS persen
FROM mart.loan_applications
GROUP BY 1, 2
ORDER BY 1, 2;


-- Q3. Bulan dengan NPL gross di atas 5%
SELECT bulan, npl_persen
FROM mart.npl_bulanan
WHERE npl_persen > 5
ORDER BY bulan;


-- Q4. Nasib kredit yang NPL per 31 Des 2025, dilihat pada 30 Sep 2026
WITH npl_awal AS (
  SELECT loan_id, outstanding_principal AS outstanding_des25
  FROM mart.loan_monthly_snapshot
  WHERE snapshot_date = '2025-12-31' AND flag_npl = 1 AND loan_status <> 'WRITE_OFF'
),
nasib AS (
  SELECT n.loan_id, n.outstanding_des25,
         CASE WHEN l.status_akhir = 'WRITE_OFF' THEN '1. Dihapus buku'
              WHEN l.status_akhir = 'CLOSED' THEN '2. Lunas'
              WHEN s.flag_npl = 0 THEN '3. Kembali lancar'
              ELSE '4. Masih NPL' END AS nasib_sep26
  FROM npl_awal n
  JOIN mart.loans l ON l.loan_id = n.loan_id
  LEFT JOIN mart.loan_monthly_snapshot s ON s.loan_id = n.loan_id AND s.snapshot_date = '2026-09-30'
)
SELECT nasib_sep26,
       COUNT(*) AS jumlah_kredit,
       ROUND(SUM(outstanding_des25) / 1000000) AS outstanding_des25_juta,
       ROUND(100.0 * SUM(outstanding_des25) / SUM(SUM(outstanding_des25)) OVER (), 1) AS persen
FROM nasib
GROUP BY 1
ORDER BY 1;


-- Q5. NPL di MOB 6 per angkatan: lihat mart.v_vintage_semester di 03_dashboard_views.sql


-- Q6. Approval rate sebelum vs selama Program Akselerasi UMKM
SELECT CASE WHEN application_date < '2024-07-01' THEN '1. Before (Jan-Jun 2024)'
            ELSE '2. During (Jul-Dec 2024)' END AS periode,
       ROUND(100.0 * SUM(flag_disetujui) / COUNT(*), 1) AS approval_all,
       ROUND(100.0 * SUM(flag_disetujui) FILTER (WHERE kelompok_skor = '2. 550-649')
             / COUNT(*) FILTER (WHERE kelompok_skor = '2. 550-649'), 1) AS approval_550_649
FROM mart.loan_applications
WHERE application_date BETWEEN '2024-01-01' AND '2024-12-31'
GROUP BY 1
ORDER BY 1;


-- Q7. Ever-NPL rate per segmen
--     Satu tabel dasar, banyak sudut pandang: ganti kolom di SELECT terakhir
--     (produk, sektor, kelompok_skor, channel, kelompok_dbr).
--     Uji ketahanan: tambahkan  AND a.officer_id <> 'SO0402'  di WHERE.
WITH dasar AS (
  SELECT l.loan_id,
         l.product AS produk,
         COALESCE(c.business_sector, 'Tidak ada sektor (karyawan)') AS sektor,
         a.kelompok_skor,
         a.channel,
         a.officer_id,
         CASE WHEN c.monthly_income IS NULL THEN '5. Tidak diketahui'
              WHEN (a.existing_monthly_debt + l.installment_amount) / c.monthly_income < 0.2 THEN '1. < 20%'
              WHEN (a.existing_monthly_debt + l.installment_amount) / c.monthly_income < 0.3 THEN '2. 20-30%'
              WHEN (a.existing_monthly_debt + l.installment_amount) / c.monthly_income < 0.4 THEN '3. 30-40%'
              ELSE '4. 40% ke atas' END AS kelompok_dbr,
         l.pernah_npl
  FROM mart.loans l
  JOIN mart.loan_applications a ON a.application_id = l.application_id
  JOIN mart.customers c ON c.customer_id = l.customer_id
  WHERE l.disbursement_date <= '2025-09-30'
)
SELECT kelompok_skor AS segmen,
       COUNT(*) AS jumlah_kredit,
       SUM(pernah_npl) AS kredit_pernah_npl,
       ROUND(100.0 * SUM(pernah_npl) / COUNT(*), 1) AS persen_pernah_npl
FROM dasar
GROUP BY 1
ORDER BY 4 DESC;


-- Q8. FPD (first payment default) rate per petugas
SELECT a.officer_id,
       COUNT(*) AS jumlah_kredit,
       SUM(l.flag_fpd) AS kredit_fpd,
       ROUND(100.0 * SUM(l.flag_fpd) / COUNT(*), 1) AS persen_fpd
FROM mart.loans l
JOIN mart.loan_applications a USING (application_id)
GROUP BY 1
ORDER BY 4 DESC;

-- Q8 detail: kredit jalur Agen SO0402 yang cair Jan-Jun 2025 (hasil: 56 kredit, 34 FPD)
SELECT COUNT(*) AS jumlah_kredit, SUM(l.flag_fpd) AS kredit_fpd
FROM mart.loans l
JOIN mart.loan_applications a USING (application_id)
WHERE a.officer_id = 'SO0402'
  AND a.channel = 'Agen'
  AND l.disbursement_date BETWEEN '2025-01-01' AND '2025-06-30';


-- Q9a. Collection rate dan cure rate per bulan: lihat mart.v_collection_bulanan di 03_dashboard_views.sql

-- Q9b. Persen tepat waktu dan rata-rata hari telat per channel bayar (hanya cicilan yang sudah dibayar)
SELECT payment_channel,
       COUNT(*) AS cicilan_dibayar,
       ROUND(100.0 * COUNT(*) FILTER (WHERE payment_date <= due_date) / COUNT(*), 1) AS persen_tepat_waktu,
       ROUND(AVG(GREATEST(payment_date - due_date, 0)), 1) AS rata_rata_hari_telat
FROM clean.repayments
WHERE payment_date IS NOT NULL
GROUP BY 1
ORDER BY 3 DESC;
