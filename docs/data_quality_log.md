# Data Quality Log – Bank Arunika

Log ini mencatat setiap temuan kualitas data yang ditemukan saat memeriksa data mentah (schema `staging`), beserta tindakan yang diambil saat cleaning (schema `clean`). Total **34 temuan** di 5 tabel utama. File aslinya: [data_quality_log.xlsx](data_quality_log.xlsx).

Kategori: **Duplikat** (baris ganda), **Kosong** (nilai tidak diisi), **Penulisan** (ejaan atau format teks tidak seragam), **Format** (tipe atau satuan salah), **Rentang** (nilai tidak masuk akal). Label **(wajar)** berarti sudah diperiksa dan memang bukan kesalahan.

| No | Tabel | Kolom | Kategori | Masalah | Contoh | Jumlah baris | Tindakan |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Customers | customer_id | Duplikat | Baris duplikat persis (ID dan seluruh isi sama) | CUST00679 | 36 ID muncul 2 kali(36 baris kelebihan) | Duplikat dibuang dengan SELECT DISTINCT (4.838 → 4.802 baris) |
| 2 | Customers | gender | Kosong | Gender tidak diisi | - | 49 | Kosong dibiarkan NULL, tidak ditebak dari nama |
| 3 | Customers | monthly_income | Kosong | Penghasilan tidak diisi | - | 96 | Kosong dibiarkan NULL |
| 4 | Customers | business_sector | Kosong (Wajar) | Kosong hanya pada karyawan(1295 dari 1295). Pemilik usaha terisi semua | - | 1295 | Dibiarkan NULL; wajar karena nasabah Karyawan tidak punya sektor usaha |
| 5 | Customers | gender | Penulisan | Penulisan tidak seragam: spasi berlebih, huruf kecil, singkatan bahasa Inggris, kata lengkap | “[ L]”, “l (L kecil)”, “M”, “Perempuan” | 666 (354 laki-laki, 312 perempuan) | TRIM + UPPER, lalu CASE: L/M/Laki-laki → L, P/F/Perempuan → P |
| 6 | Customers | city | Penulisan | Penulisan tidak seragam: spasi berlebih, huruf besar/ kecil, ada nya singkatan, kata lengkap | "[bandung ]","bogor","Jaktim", "Kota Bandung" | 583 (55 depok, 88 jakarta pusat, 60 bandung, 58 bogor, 71 bekasi, 99 jakarta timur, 79 jakarta barat, 73 tangerang) | CASE: Jakbar/Jakpus/Jaktim → nama lengkap, awalan “Kota” dihapus, Tangerang Kota → Tangerang (asumsi, dicatat di README); sisanya INITCAP(TRIM). Hasil 8 kota sesuai branches |
| 7 | Customers | full_name | Penulisan | Spasi berlebih di depan nama | "[ Hendra Pangaribuan]" | 76 | TRIM (spasi di depan dibuang) |
| 8 | Customers | full_name | Penulisan | Penulisan huruf tidak lazim: huruf kecil semua atau huruf besar semua | "yoga sinaga", "FERRY HAKIM" | 167(83 huruf kecil, 84 huruf besar) | INITCAP (huruf kapital di awal tiap kata) |
| 9 | Customers | birth_date | Format | Dua format tanggal: sebagian DD/MM/YYYY, sisanya YYYY-MM-DD | "23/03/2002", "31/12/1971" | 389 | Format DD/MM/YYYY dibaca dengan TO_DATE(birth_date, ‘DD/MM/YYYY’); semua jadi tipe DATE |
| 10 | Customers | monthly_income | Format | Ditulis sebagai teks dengan "Rp", spasi, dan titik pemisah ribuan | "Rp 10.350.000" | 72 | “Rp”, titik, dan spasi dihapus dengan REPLACE, lalu diubah ke angka |
| 11 | Customers | monthly_income | Rentang | Penghasilan bernilai 0, tidak masuk akal untuk pemohon kredit | 0 | 24 | Penghasilan 0 diubah jadi NULL (tidak masuk akal, dan agar rata-rata tidak turun palsu) |
| 12 | loan_applications | credit_score | kosong | skor kredit tidak diisi | - | 79 | Kosong dibiarkan NULL |
| 13 | loan_applications | approved_amount | kosong(wajar) | kosong hanya pada pengajuan ditolak (1630 dari 1630) | - | 1630 | Dibiarkan NULL; wajar karena pengajuan ditolak |
| 14 | loan_applications | reject_reason | kosong(wajar) | kosong pada pengajuan disetujui (3420) dan dibatalkan (210) | - | 3630 | Dibiarkan NULL; wajar karena pengajuan disetujui/dibatalkan |
| 15 | loan_applications | product | Penulisan | Penulisan tidak seragam: huruf besar/kecil, spasi berlebih, singkatan dan kepanjangan | "kredit mikro", "[Kredit Mikro ]", "KUK", "Kredit Tanpa Agunan" | 316 (182 Kredit Mikro, 45 Kredit Usaha Kecil, 89 KTA) | CASE: KTA/kta/Kredit Tanpa Agunan → KTA, KUK → Kredit Usaha Kecil; sisanya INITCAP(TRIM). Hasil 3 produk |
| 16 | loan_applications | status | Penulisan | Huruf besar/kecil, spasi berlebih, dan ejaan berbeda (REJECT vs REJECTED, CANCELED vs CANCELLED) | "approved", "[APPROVED]", "REJECT", "Canceled" | 526(351 APPROVED, 158 REJECTED, 17 CANCELLED) | CASE: REJECT → REJECTED, Canceled → CANCELLED; sisanya UPPER(TRIM). Hasil 3 status |
| 17 | loan_applications | channel | Penulisan | Huruf besar/kecil, spasi berlebih, dan penulisan tanpa spasi (MobileApp) | "agen", "[cabang ]", "MobileApp" | 263 (66 Agen, 116 Cabang, 81 Mobile App) | CASE: MobileApp → Mobile App; sisanya INITCAP(TRIM). Hasil 3 channel |
| 18 | loan_applications | requested_amount | Rentang | Nominal pengajuan bernilai negatif | “-28000000.0”, “-50000000.0” | 16 | ABS (tanda minus dihapus) |
| 19 | loan_applications | application_date | Rentang | Tahun pengajuan salah ketik jadi 2027, sehingga tercatat setelah keputusan. Bulan dan tanggalnya wajar | “2027-04-19” (keputusan 2023-04-21) | 8 | Tahun 2027 diganti tahun decision_date: LEFT(decision_date, 4) // SUBSTRING(application_date, 5) |
| 20 | loan_applications | credit_score | Rentang | Skor di luar skala 300–850 | 0, 999 | 27 (16 di bawah 300, 11 di atas 850) | Skor di luar 300–850 diubah jadi NULL (nilai mustahil, tidak dipaksa ke batas) |
| 21 | loans | loan_id | Duplikat | Baris duplikat persis (ID dan seluruh isi sama) | LN001055 | 10 ID × 2 (10 baris kelebihan) | Duplikat dibuang dengan SELECT DISTINCT (3.430 → 3.420 baris) |
| 22 | loans | interest_rate_annual | Format | Satuan tidak seragam: sebagian desimal (0.1604 = 16,04%), sebagian persen (19.67 = 19,67%) | “0.1604”, “19.67” | 171 | Nilai ≥ 1 dibagi 100 dengan CASE; semua jadi desimal (9,23%–20,32%) |
| 23 | loans | disbursement_date | Rentang | Tanggal cair lebih awal dari tanggal keputusan(logika antar tabel, dibanding loan_applications.decision_date) | LN000560: keputusan 2023-10-17, cair 2023-09-28 (19 hari lebih awal). Selisih 3–19 hari. | 10 | Dibiarkan; tidak bisa dipastikan tanggal mana yang benar. Dicatat sebagai keterbatasan di README |
| 24 | loan_monthly_snapshot | dpd | kosong | DPD kosong, tersebar di status ACTIVE dan CLOSED. Seharusnya setiap snapshot punya DPD (0 kalau tidak telat) | (kosong) | 111 (106 ACTIVE, 5 CLOSED) | Dihitung ulang dari clean.repayments: tanggal rapor − jatuh tempo cicilan tertua yang belum dibayar; tanpa tunggakan → 0; status CLOSED → 0 |
| 25 | loan_monthly_snapshot | loan_status | Penulisan | Huruf besar-kecil tidak seragam | “active”, “closed”, “write_off” | 2.773 (2.692 active / 73 closed / 8 write_off) | UPPER(TRIM). Hasil 3 status |
| 26 | loan_monthly_snapshot | outstanding_principal | Rentang | Sisa pokok bernilai negatif | “-34066144.0” (LN000020, Feb 2025) | 55 | ABS (tanda minus dihapus) |
| 27 | loan_monthly_snapshot | loan_status | Rentang | Status ACTIVE padahal sisa pokok 0 dan DPD 0 selama 11 bulan (Nov 2025 – Sep 2026). Seharusnya CLOSED | LN001088, LN001600 | 22 baris (2 kredit) | Bulan pertama sisa pokok 0 diubah jadi CLOSED; 20 rapor sesudahnya dihapus, mengikuti pola kredit CLOSED lain (55.454 → 55.434 baris) |
| 28 | loan_monthly_snapshot | (baris) | kosong | Bulan bolong: ada bulan tanpa rapor di tengah riwayat kredit | LN000009: ada Mei 2024 dan Jul 2024, Jun 2024 tidak ada | 147 bulan (145 kredit) | Dibiarkan. Rencana diubah: menyalin bulan sebelumnya berisiko salah (sisa pokok dan DPD bisa berubah). Dampak < 0,3%, dicatat di README |
| 29 | repayments | loan_id + installment_no | Duplikat | Cicilan yang sama tercatat 2 kali dengan payment_id berbeda, kolom lain sama persis (double posting) | LN001570 cicilan ke-3: PAY00031880 dan PAY00031881 | 198 pasang (198 baris berlebih) | DISTINCT ON (loan_id, installment_no), disimpan payment_id terkecil (52.832 → 52.634 baris) |
| 30 | repayments | payment_date, amount_paid, payment_channel | Kosong (wajar) | Cicilan belum dibayar (tunggakan). Ketiga kolom kosong di baris yang sama, dan semua sudah lewat jatuh tempo | (kosong) | 3.227 | Dibiarkan NULL; cicilan belum dibayar (tunggakan), dipakai untuk menghitung DPD |
| 31 | repayments | payment_channel | Penulisan | Huruf besar-kecil tidak seragam + singkatan dan ejaan berbeda | “teller”, “MBanking”, “m-banking”, “autodebet”, “VA” | 3.969 (Mobile Banking 1.409 / Teller 1.247 / Auto Debit 759 / Virtual Account 554) | CASE: MBanking/m-banking → Mobile Banking, autodebet → Auto Debit, VA → Virtual Account; sisanya INITCAP(TRIM). Hasil 4 channel |
| 32 | repayments | amount_paid | Format | Teks rupiah: ada "Rp" dan titik pemisah ribuan | “Rp3.963.600” | 494 | “Rp” dan titik dihapus dengan REPLACE, lalu diubah ke angka; nilai dipertahankan |
| 33 | repayments | amount_paid | Rentang | Jumlah bayar negatif | “-1627700.0” (LN000001 cicilan 36) | 48 | ABS (tanda minus dihapus) |
| 34 | repayments | amount_paid | Rentang(wajar) | Bayar lebih besar dari tagihan, semuanya di cicilan terakhir = pelunasan dipercepat | “92312800.0” (tagihan terbesar cuma 14,3 jt) | 194 (+2 baris berformat Rp, total 196 setelah formatnya dirapikan) | Dibiarkan; pelunasan dipercepat di cicilan terakhir |

## Asumsi dan keterbatasan dari proses cleaning

| No | Jenis | Catatan |
| --- | --- | --- |
| 1 | Asumsi | “Tangerang Kota” (20 nasabah) digabung ke Tangerang, karena hanya ada satu cabang Tangerang |
| 2 | Asumsi | DPD yang kosong (111 rapor) dihitung ulang dari data repayments; rumusnya cocok 99,99% dengan DPD yang tersedia |
| 3 | Asumsi | Penghasilan 0 (24) dan skor kredit di luar 300–850 (27) dianggap tidak diketahui (NULL) |
| 4 | Keterbatasan | 10 kredit tercatat cair 3–19 hari sebelum tanggal keputusan; dibiarkan karena tidak diketahui tanggal mana yang benar |
| 5 | Keterbatasan | 147 rapor bulanan hilang (dari 55.434, < 0,3%); tidak diisi supaya tidak mengarang sisa pokok dan DPD |
