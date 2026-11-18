-- =====================================================================
-- Bank Arunika: view yang dipakai dashboard Power BI
-- Metrik ini membandingkan antarbulan atau menggabungkan dua tabel, jadi
-- dihitung di SQL lalu dimuat ke Power BI sebagai tabel.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Kualitas angkatan per semester (halaman Credit Quality, Q5 dan Q6)
--    npl_mob6_rate : persen kredit yang NPL di umur 6 bulan (MOB 6),
--                    per semester pencairan (angkatan)
--    approval_rate : persen pengajuan yang disetujui, per semester pengajuan
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW mart.v_vintage_semester AS
WITH npl_mob6 AS (
  SELECT EXTRACT(YEAR FROM vintage)::int || '-S' || CASE WHEN EXTRACT(MONTH FROM vintage) <= 6 THEN 1 ELSE 2 END AS semester,
         COUNT(*) AS kredit_mob6,
         SUM(flag_npl) AS npl_mob6
  FROM mart.loan_monthly_snapshot
  WHERE mob = 6
  GROUP BY 1
),
approval AS (
  SELECT EXTRACT(YEAR FROM application_date)::int || '-S' || CASE WHEN EXTRACT(MONTH FROM application_date) <= 6 THEN 1 ELSE 2 END AS semester,
         COUNT(*) AS pengajuan,
         SUM(flag_disetujui) AS disetujui
  FROM mart.loan_applications
  GROUP BY 1
)
SELECT a.semester,
       a.pengajuan,
       ROUND(a.disetujui::numeric / a.pengajuan, 4) AS approval_rate,
       n.kredit_mob6,
       ROUND(n.npl_mob6::numeric / n.kredit_mob6, 4) AS npl_mob6_rate
FROM approval a
LEFT JOIN npl_mob6 n ON n.semester = a.semester;


-- ---------------------------------------------------------------------
-- 2. Collection rate dan cure rate per bulan (halaman Collection, Q9)
--    collection_rate : persen cicilan jatuh tempo bulan itu yang dibayar
--                      paling lambat di tanggal jatuh tempo
--    cure_rate       : persen kredit telat 1-90 hari bulan lalu yang
--                      kembali ke DPD 0 bulan ini
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW mart.v_collection_bulanan AS
WITH koleksi AS (
  SELECT (DATE_TRUNC('month', due_date) + INTERVAL '1 month - 1 day')::date AS bulan,
         COUNT(*) AS cicilan_jatuh_tempo,
         COUNT(*) FILTER (WHERE payment_date <= due_date) AS dibayar_tepat_waktu
  FROM clean.repayments
  GROUP BY 1
),
cure AS (
  SELECT s.snapshot_date AS bulan,
         COUNT(*) AS telat_bulan_lalu,
         COUNT(*) FILTER (WHERE s.dpd = 0) AS kembali_lancar
  FROM mart.loan_monthly_snapshot s
  JOIN mart.loan_monthly_snapshot p
    ON p.loan_id = s.loan_id
   AND p.snapshot_date = (DATE_TRUNC('month', s.snapshot_date) - INTERVAL '1 day')::date
  WHERE p.dpd BETWEEN 1 AND 90
  GROUP BY 1
)
SELECT k.bulan,
       k.cicilan_jatuh_tempo,
       ROUND(k.dibayar_tepat_waktu::numeric / k.cicilan_jatuh_tempo, 4) AS collection_rate,
       c.telat_bulan_lalu,
       ROUND(c.kembali_lancar::numeric / c.telat_bulan_lalu, 4) AS cure_rate
FROM koleksi k
LEFT JOIN cure c ON c.bulan = k.bulan
WHERE k.bulan >= '2024-01-01';
