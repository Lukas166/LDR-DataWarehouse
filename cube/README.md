# 📌 SSAS Cube Deployment Guide (Untuk UI Team - Rynad)

Repository ini sudah dilengkapi dengan file backup Cube SSAS (`.abf`). Agar kamu bisa menghubungkan UI/Dashboard (Power BI / Tableau / Web App) ke OLAP Cube secara lokal, silakan ikuti panduan setup di bawah ini secara berurutan.

---

## 🛠️ Langkah-Langkah Setup Lokal

### TAHAP 1: Relational Data Warehouse (SQL Server)
1. Jalankan semua script SQL (`.sql`) yang ada di repository ini pada instance SQL Server (Database Engine) lokal kamu.
2. Pastikan database Data Warehouse (DW) sudah terbentuk sempurna dan seluruh baris datanya sudah masuk ke dalam tabel.

### TAHAP 2: Restore Cube (SQL Server Analysis Services - SSAS)
1. Buka **SQL Server Management Studio (SSMS)**, lalu hubungkan ke server **Analysis Services** lokal kamu.
2. Di panel Object Explorer (sebelah kiri), klik kanan pada folder **Databases** ➔ pilih **Restore...**
3. Cari dan pilih file **`LDR_CUBE_PROJECT.abf`** dari folder repository hasil clone, lalu klik **OK** hingga database Cube muncul di daftar.

### TAHAP 3: Konfigurasi Ulang Data Source & Impersonation (PENTING ⚠️)
Karena file `.abf` ini membawa metadata koneksi dari komputer sebelumnya, kamu **wajib** mengubah jalur koneksinya ke environment lokal kamu sendiri agar tidak terkena error *login failed*:
1. Buka folder database Cube hasil restore di SSMS ➔ masuk ke folder **Data Sources**.
2. Klik kanan pada file koneksi **`LDR DW`** ➔ pilih **Properties**.
3. Pada baris **Connection String**, edit teksnya: ubah bagian `Data Source=...` menjadi nama server SQL lokal kamu (atau bisa diganti dengan `localhost`).
4. Pada bagian **Security Settings**, klik dua kali (double-click) pada teks di sebelah kanan kolom **Impersonation Info**.
5. Di jendela pop-up yang muncul, pindahkan pilihan ke **`Use a specific Windows user name and password`**.
6. Masukkan **Username** dan **Password/PIN** yang biasa kamu pakai untuk login ke Windows laptop kamu sendiri, lalu klik **OK** dan simpan perubahan.

### TAHAP 4: Process Database (Mengisi Data ke Cube)
1. Setelah kredensial koneksi disesuaikan, kembali ke Object Explorer.
2. Klik kanan pada folder utama database Cube (**`LDR_CUBE_PROJECT`**) ➔ pilih **Process...**
3. Di jendela *Process Database*, pastikan pilihannya adalah *Process Full*, lalu langsung klik tombol **OK** di pojok kanan bawah.
4. Tunggu beberapa detik hingga proses ETL latar belakang selesai sampai muncul status sukses berwarna hijau: **`Process succeeded`**.

---

## 📊 Menghubungkan ke UI / Dashboard
Setelah statusnya *Process succeeded*, engine Cube sudah aktif dan datanya sudah ter-agregasi secara utuh. Kamu sudah bisa langsung menghubungkan tools visualisasi (seperti Power BI, Tableau, atau library charting di web app) dengan mengarahkan koneksi server ke SSAS lokal kamu (`localhost` atau nama device kamu).

*Jika ada kendala atau error terkait hak akses saat proses impersonation, langsung colek di grup ya!*
