# MANUAL BOOK PENGGUNA
## TALog20

**Aplikasi Logbook dan Monitoring Tugas SMKN 20 Jakarta**

| Informasi | Keterangan |
|---|---|
| Nama aplikasi | TALog20 |
| Sasaran pengguna | Siswa, Guru, Admin, dan Superadmin |
| Platform | Android, Windows, dan Web/Chrome sesuai build yang disediakan |
| Versi dokumen | 1.0 |
| Tanggal | 16 September 2026 |
| Kontak bantuan | Isi nomor/email operator sekolah |
| Alamat aplikasi | Isi tautan aplikasi atau nama paket APK |

> Dokumen ini menjelaskan penggunaan aplikasi berdasarkan fitur yang tersedia pada proyek TALog20. Tampilan dapat sedikit berbeda antara Android, Windows, dan Web.

---

## 1. Tentang TALog20

TALog20 digunakan untuk mengelola tugas, pengumpulan pekerjaan, penilaian, feedback guru, dan pemantauan aktivitas akademik. Setiap pengguna masuk menggunakan akun masing-masing. Data yang tampil dibatasi sesuai peran pengguna.

### Peran pengguna

| Peran | Fungsi utama |
|---|---|
| **Siswa** | Melihat tugas, mengumpulkan jawaban, melihat status pengumpulan, nilai, dan feedback. |
| **Guru** | Membuat dan mengelola tugas, melihat pengumpulan siswa, membuka berkas, memberi nilai, dan memberi feedback. |
| **Admin** | Memantau operasional tugas, pengumpulan, pengguna, penilaian, serta fitur administrasi yang diberikan sistem. |
| **Superadmin** | Mengelola pengguna dan role, memantau seluruh aktivitas, melihat audit log, dan menggunakan Student Preview. |

Menu dan data yang terlihat akan menyesuaikan peran akun. Pengguna tidak dapat membuka data atau menu di luar kewenangannya.

---

## 2. Persiapan Sebelum Menggunakan Aplikasi

1. Pastikan perangkat terhubung ke internet.
2. Gunakan aplikasi TALog20 yang diberikan sekolah atau buka alamat aplikasi resmi.
3. Pastikan email/username dan password sudah diterima atau sudah dibuat.
4. Untuk pengguna staf, gunakan akun undangan yang telah diaktifkan oleh Admin atau Superadmin.
5. Untuk siswa baru, siapkan nama lengkap, email pribadi, kode jurusan, dan nomor absen.

Jika muncul pesan **Konfigurasi Supabase belum tersedia**, aplikasi belum dikonfigurasi oleh operator. Pengguna tidak dapat memperbaikinya dari dalam aplikasi. Hubungi operator atau administrator sistem.

---

## 3. Membuat Akun Siswa

Fitur pendaftaran mandiri ditujukan untuk siswa.

1. Pada halaman login, pilih **Belum punya akun siswa? Daftar sekarang**.
2. Isi **Nama lengkap** sesuai data sekolah.
3. Isi **Email pribadi** dengan alamat email yang valid.
4. Isi **Kode jurusan**, misalnya `RPL`, sesuai jurusan yang diberikan sekolah.
5. Isi **Nomor absen** dengan angka absen yang benar.
6. Pilih **Daftar akun siswa**.
7. Setelah akun berhasil dibuat, kembali ke halaman login.
8. Login menggunakan email yang didaftarkan.
9. Password awal dibuat otomatis dari nomor absen sebanyak tiga kali.

**Contoh:** nomor absen `12` menghasilkan password awal `121212`.

Segera ganti password setelah berhasil masuk. Jangan membagikan password kepada orang lain.

### Kendala saat pendaftaran

- Email harus memiliki format yang valid.
- Nama lengkap dan nomor absen wajib diisi.
- Nomor absen harus berupa angka lebih besar dari 0.
- Kode jurusan harus sesuai data yang tersedia di sekolah.
- Jika email sudah terdaftar, gunakan halaman login atau hubungi operator.

---

## 4. Login dan Lupa Password

### Login

1. Buka TALog20.
2. Isi **Email atau Username**.
3. Isi **Password**.
4. Pilih **Masuk**.
5. Tunggu sampai dashboard sesuai role tampil.

Pengguna dapat login menggunakan email. Username dapat digunakan apabila sudah diatur dan diaktifkan pada sistem.

### Reset password

1. Pada halaman login, pilih **Lupa password?**.
2. Masukkan alamat email akun.
3. Pilih **Kirim**.
4. Buka email pemulihan yang diterima dan ikuti petunjuknya.
5. Kembali ke aplikasi dan login dengan password baru.

Jika email pemulihan tidak diterima, periksa folder Spam/Junk atau hubungi administrator.

---

## 5. Panduan Siswa

### 5.1 Mengenal Student Workspace

Setelah login, siswa masuk ke **Student Workspace**. Di dalamnya siswa dapat melihat:

- Ringkasan aktivitas dan sapaan pengguna.
- Daftar tugas yang tersedia.
- Status tugas: aktif, belum dikumpulkan, atau sudah dikumpulkan.
- Deadline dan jurusan tugas.
- Daftar pengumpulan, nilai, dan feedback.
- Menu profil dan pengaturan password.

### 5.2 Melihat detail tugas

1. Buka daftar tugas pada dashboard siswa.
2. Pilih **Lihat Detail** pada tugas yang ingin diperiksa.
3. Baca nama tugas, deskripsi/instruksi, deadline, jurusan, dan lampiran jika tersedia.
4. Periksa bagian **Status** untuk mengetahui apakah tugas sudah dikumpulkan.
5. Jika tugas belum dikumpulkan, pilih **Kumpulkan**.

### 5.3 Mengumpulkan tugas dengan file

1. Buka detail tugas.
2. Pilih **Kumpulkan**.
3. Pilih **Pilih file tugas**.
4. Pilih berkas dari perangkat.
5. Tunggu sampai status berubah menjadi **Berhasil diunggah**.
6. Pastikan nama dan ukuran file yang tampil sudah benar.
7. Pilih **Kirim Tugas**.
8. Tunggu pesan **Tugas berhasil dikumpulkan!**.

### 5.4 Mengumpulkan jawaban teks

1. Buka detail tugas dan pilih **Kumpulkan**.
2. Isi kolom **Jawaban teks (opsional)**.
3. Pilih **Kirim Tugas**.
4. Jawaban teks tidak boleh kosong.

Jawaban teks dapat digabungkan dengan file. Isi jawaban teks dan pilih file sebelum menekan **Kirim Tugas**.

### 5.5 Aturan file pengumpulan

Format yang didukung:

- Dokumen: PDF, DOC, DOCX, TXT, CSV.
- Spreadsheet: XLS, XLSX.
- Presentasi: PPT, PPTX.
- Gambar: PNG, JPG, JPEG, GIF, WEBP, BMP, SVG.
- Arsip: ZIP, RAR, 7Z.

Ukuran file maksimum adalah **50 MiB**. Format seperti EXE tidak didukung. Gunakan nama file sederhana tanpa karakter yang tidak diperlukan.

### 5.6 Memeriksa pengumpulan, nilai, dan feedback

1. Buka bagian daftar pengumpulan atau nilai pada Student Workspace.
2. Status **Terkirim** berarti pengumpulan sudah tersimpan.
3. Jika nilai sudah diberikan, akan tampil **Nilai: angka**.
4. Jika guru memberikan komentar, feedback akan tampil sebagai catatan.
5. Untuk melihat detail tugas dan status terbaru, buka kembali **Lihat Detail**.

Perubahan pengumpulan atau nilai dapat muncul otomatis. Jika belum terlihat, gunakan tombol refresh yang tersedia atau buka kembali halaman.

### 5.7 Mengubah profil dan username

1. Buka menu profil pada bagian navigasi atau akun.
2. Pilih **Profil & Username** atau **Pengaturan Profil**.
3. Ubah nama atau username sesuai kebutuhan.
4. Username harus terdiri dari 3-20 karakter dan hanya boleh berisi huruf kecil, angka, dan underscore.
5. Pilih **Simpan**.

Username yang sudah digunakan pengguna lain tidak dapat dipakai.

### 5.8 Mengganti password

1. Buka menu profil.
2. Pilih **Ganti Password**.
3. Isi password lama.
4. Isi password baru minimal 6 karakter.
5. Isi konfirmasi password dengan nilai yang sama.
6. Pilih **Simpan**.

Jangan menggunakan password yang mudah ditebak dan jangan membagikannya kepada pengguna lain.

### 5.9 Keluar dari aplikasi

1. Buka menu profil.
2. Pilih **Keluar**.
3. Login kembali jika ingin menggunakan aplikasi.

Biasakan keluar dari aplikasi pada perangkat bersama.

---

## 6. Panduan Guru

### 6.1 Masuk ke Admin Dashboard

1. Login menggunakan akun guru yang aktif.
2. Setelah verifikasi berhasil, sistem menampilkan **Admin Dashboard**.
3. Gunakan navigasi untuk berpindah antara ringkasan, tugas, dan pengumpulan.

### 6.2 Membuat tugas

1. Buka menu **Tugas**.
2. Pilih **Tambah Tugas**.
3. Isi **Nama Tugas**.
4. Isi **Deskripsi / Instruksi** secara jelas.
5. Pilih **Jurusan** tujuan.
6. Pilih **Deadline**.
7. Periksa kembali data tugas.
8. Pilih **Simpan**.

Tugas yang tersimpan akan tampil pada daftar tugas siswa yang sesuai.

### 6.3 Mengarsipkan atau memulihkan tugas

1. Buka menu **Tugas**.
2. Temukan tugas yang ingin diubah.
3. Pilih **Arsipkan** untuk menyembunyikan tugas dari daftar aktif.
4. Untuk mengaktifkan kembali, pilih **Pulihkan**.

Arsipkan tugas yang sudah selesai atau tidak ingin ditampilkan sebagai tugas aktif.

### 6.4 Menghapus tugas

1. Buka menu **Tugas**.
2. Pilih **Hapus** pada tugas yang akan dihapus.
3. Baca peringatan yang muncul.
4. Pilih **Hapus Permanen** hanya jika benar-benar yakin.

Penghapusan permanen tidak dapat dibatalkan. Jika tugas sudah memiliki pengumpulan atau nilai, gunakan **Arsipkan** agar riwayat siswa tetap terjaga.

### 6.5 Memeriksa dan menilai pengumpulan

1. Buka menu **Pengumpulan**.
2. Pilih pengumpulan siswa yang ingin diperiksa.
3. Jika ada file, pilih **Buka** untuk membuka atau mengunduhnya.
4. Periksa jawaban dan catatan siswa.
5. Masukkan **Nilai (0 - 100)**.
6. Masukkan **Feedback / Catatan Guru** bila diperlukan.
7. Pilih **Simpan Nilai**.

Nilai harus berupa angka antara 0 dan 100. Setelah disimpan, siswa dapat melihat nilai dan feedback pada dashboardnya.

### 6.6 Student Preview

Jika tersedia pada akun staf, gunakan fitur Student Preview untuk melihat tampilan sebagaimana siswa. Mode ini digunakan untuk pengecekan tampilan dan alur, bukan untuk mengubah data milik siswa.

Pilih **Kembali ke Dashboard Admin** untuk kembali ke dashboard staf.

---

## 7. Panduan Admin

Admin memiliki fungsi operasional yang lebih luas daripada guru.

1. Login menggunakan akun Admin.
2. Gunakan menu **Tugas** untuk memantau dan mengelola tugas.
3. Gunakan menu **Pengumpulan** untuk memeriksa jawaban dan melakukan penilaian.
4. Gunakan menu pengguna yang tersedia untuk memantau akun sesuai izin.
5. Gunakan Student Preview bila perlu memeriksa pengalaman siswa.

Admin tidak dapat mengangkat pengguna menjadi Superadmin dan tidak dapat mengubah kebijakan keamanan database. Gunakan menu hanya untuk keperluan operasional resmi.

---

## 8. Panduan Superadmin

### 8.1 Mencari pengguna

1. Buka menu **Pengguna**.
2. Isi kolom **Cari berdasarkan Email atau Nama**.
3. Pilih **Cari** atau tekan Enter.
4. Periksa nama, email, dan role pada hasil pencarian.

### 8.2 Mengubah role pengguna

1. Cari pengguna yang akan diubah.
2. Pilih **Ubah Role**.
3. Pilih role baru: Student, Teacher, atau Admin.
4. Pilih **Simpan**.
5. Cari ulang pengguna untuk memastikan perubahan tersimpan.

Role **Superadmin** tidak dapat diubah dari menu ini. Lakukan perubahan role hanya berdasarkan permintaan dan kewenangan resmi.

### 8.3 Melihat audit log

1. Buka menu **Audit Log**.
2. Periksa aktivitas terbaru, role pelaku, deskripsi, dan waktu aktivitas.
3. Pilih **Refresh** untuk mengambil data terbaru.
4. Pilih **Bersihkan** untuk menghapus daftar dari tampilan saat ini.

Tombol **Bersihkan** hanya membersihkan tampilan lokal, bukan menghapus catatan audit permanen dari database.

### 8.4 Melihat Live Update

Pada akun Superadmin, menu **Live Update** menampilkan aktivitas terbaru terkait pengumpulan tugas dan nilai. Data dapat diperbarui otomatis melalui koneksi realtime.

Gunakan **Refresh** jika data belum muncul. Gunakan **Bersihkan** hanya untuk mengosongkan tampilan sementara.

---

## 9. Penanganan Masalah

| Masalah | Tindakan |
|---|---|
| Tidak bisa login | Periksa email/username, password, koneksi internet, dan status akun. |
| Username tidak ditemukan | Gunakan email atau minta administrator memastikan username sudah aktif. |
| Profil tidak dapat dimuat | Keluar lalu login kembali. Jika berulang, hubungi administrator. |
| Tugas tidak tampil | Refresh halaman, periksa koneksi, dan pastikan tugas memang ditujukan untuk jurusan Anda. |
| File ditolak | Pastikan format didukung dan ukuran tidak lebih dari 50 MiB. |
| Deadline sudah lewat | Pengumpulan tidak dapat dikirim setelah deadline. Hubungi guru untuk kebijakan lanjutan. |
| Nilai belum tampil | Pastikan guru sudah menyimpan penilaian, lalu refresh halaman. |
| Tidak dapat mengubah role | Pastikan akun adalah Superadmin dan target bukan Superadmin. |
| Audit log gagal dimuat | Refresh dan pastikan akun memiliki izin Superadmin. |
| Aplikasi menampilkan error koneksi | Pastikan internet aktif dan coba lagi. Jika tetap gagal, catat pesan error dan hubungi operator. |

Saat melapor, sertakan nama pengguna, waktu kejadian, menu yang sedang dibuka, serta pesan error yang tampil. Jangan mengirim password atau kunci keamanan kepada siapa pun.

---

## 10. Praktik Keamanan

- Gunakan akun sendiri dan jangan meminjamkan akun.
- Ganti password awal setelah login pertama.
- Jangan membagikan password, kode pemulihan, atau tautan undangan.
- Periksa kembali jurusan, deadline, file, dan nilai sebelum menyimpan.
- Gunakan perangkat dan jaringan yang terpercaya.
- Keluar dari aplikasi setelah selesai pada perangkat bersama.
- Admin dan Superadmin hanya boleh mengubah data sesuai kewenangannya.
- Jangan menaruh kredensial Supabase atau service-role key di perangkat pengguna.

---

## 11. Checklist Pengguna

### Siswa

- [ ] Akun berhasil dibuat atau diaktifkan.
- [ ] Login berhasil.
- [ ] Password awal sudah diganti.
- [ ] Profil dan username sudah benar.
- [ ] Tugas dan deadline sudah diperiksa.
- [ ] Jawaban atau file sudah dikirim sebelum deadline.
- [ ] Status pengumpulan dan nilai sudah diperiksa.

### Guru/Admin

- [ ] Akun staf sudah aktif.
- [ ] Tugas dibuat dengan jurusan dan deadline yang benar.
- [ ] Pengumpulan siswa sudah diperiksa.
- [ ] Nilai berada pada rentang 0-100.
- [ ] Feedback sudah ditulis jika diperlukan.
- [ ] Tugas lama sudah diarsipkan, bukan dihapus sembarangan.

### Superadmin

- [ ] Akun pengguna dicari berdasarkan nama atau email yang benar.
- [ ] Perubahan role dilakukan dengan persetujuan yang sesuai.
- [ ] Role Superadmin tidak diubah melalui menu biasa.
- [ ] Audit log diperiksa untuk aktivitas penting.
- [ ] Informasi keamanan tidak dibagikan kepada pengguna umum.

---

**Akhir dokumen**
