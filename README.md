# Database Sumber Daya RAB — Panduan Setup (Supabase + GitHub + Netlify)

Ini adalah **duplikat** dari web "Database Sumber Daya RAB" yang sudah kamu buat. Strukturnya masih 1 file (`index.html`, HTML+CSS+JS jadi satu, tanpa build tool), dan logic untuk login/autentikasi serta sinkronisasi data ke server **sudah ada di dalamnya** — kamu tinggal menyambungkannya ke project Supabase kamu sendiri (bukan project lama), lalu deploy ke Netlify.

Setelah setup ini selesai, kamu bisa modifikasi tampilan/fitur di `index.html` kapan pun, commit, push — Netlify otomatis re-deploy.

## Cara kerja app ini (ringkas)

- **Auth**: login pakai email + password lewat Supabase Auth (`SB.auth.signInWithPassword`). Tidak ada form daftar sendiri — akun dibuat manual oleh kamu (admin) lewat dashboard Supabase.
- **Role**: semua yang bisa login = *viewer* (lihat data). Yang emailnya terdaftar di tabel `editors` = *editor* (boleh tambah/edit/hapus/impor data).
- **Data**: seluruh data (harga, item, disiplin, dsb) disimpan sebagai satu baris JSON di tabel `bank_state`, plus disalin ke `localStorage` browser sebagai cache offline.
- **Sync**: setiap editor menyimpan perubahan → otomatis `upsert` ke Supabase (`sbPush`). Viewer lain auto-poll setiap 25 detik + saat tab kembali aktif (`pullRemote`) supaya selalu lihat data terbaru — tanpa refresh manual.

Karena semua logic ini sudah jadi, **yang perlu kamu lakukan hanyalah menyediakan "server"-nya**: 1 project Supabase (auth + database) dan 1 site Netlify (hosting).

---

## Langkah 1 — Buat project Supabase baru

1. Buka [supabase.com](https://supabase.com) → sign in / daftar → **New project**.
2. Isi nama project (mis. `sbdy-database`), pilih region terdekat (Singapore), buat password database (simpan baik-baik, jarang dipakai langsung tapi penting).
3. Tunggu ~1-2 menit sampai project siap.

## Langkah 2 — Jalankan SQL setup

1. Di sidebar project, buka **SQL Editor** → **New query**.
2. Copy-paste seluruh isi file [`supabase/schema.sql`](./supabase/schema.sql) dari folder ini, lalu klik **Run**.
3. Script ini akan membuat:
   - tabel `bank_state` (penyimpanan data utama) + baris awal `id=1`
   - tabel `editors` (daftar email yang boleh edit)
   - Row Level Security (RLS): user login boleh baca, hanya editor boleh tulis.

## Langkah 3 — Tambahkan dirimu sebagai editor

1. Buka **Table Editor** → tabel `editors` → **Insert row** → isi kolom `email` dengan emailmu (harus sama persis dengan email akun login nanti) → Save.
2. Ulangi untuk setiap orang lain yang boleh mengedit data.

## Langkah 4 — Buat akun login (Auth Users)

App ini tidak punya form "daftar sendiri", jadi akun harus dibuat manual:

1. Buka **Authentication** → **Users** → **Add user** → **Create new user**.
2. Isi email + password, centang **Auto Confirm User** (supaya tidak perlu verifikasi email).
3. Buat akun untuk dirimu sendiri (editor) dan siapa pun yang butuh akses viewer.

> Tips: kalau nanti mau banyak viewer tanpa buat akun satu-satu, kamu bisa aktifkan magic link / OTP di **Authentication > Providers** — tapi itu perlu sedikit modifikasi UI gate di `index.html` (form login saat ini hanya email+password).

## Langkah 5 — Ambil URL & anon key

1. Buka **Project Settings** (ikon gear) → **API**.
2. Salin **Project URL** dan **anon public** key.
3. Buka `index.html` di folder ini, cari baris (sekitar baris 628):

   ```js
   const CLOUD={url:"GANTI_DENGAN_SUPABASE_PROJECT_URL",anonKey:"GANTI_DENGAN_SUPABASE_ANON_KEY"};
   ```

   Ganti dengan nilai dari dashboard, contoh:

   ```js
   const CLOUD={url:"https://xxxxxxxx.supabase.co",anonKey:"eyJhbGciOi...(anon key kamu)"};
   ```

   *(Catatan: `anon key` ini memang dimaksudkan untuk terlihat di sisi client/browser — keamanan ditangani oleh RLS di Langkah 2, bukan dengan menyembunyikan key ini.)*

4. Simpan file.

## Langkah 6 — Push ke GitHub

Dari terminal, di dalam folder ini:

```bash
git init                       # kalau belum
git add .
git commit -m "Initial setup: duplikat database sumber daya RAB"
```

Lalu buat repo baru di [github.com/new](https://github.com/new) (misal `sbdy-database-web`, boleh **Private**), kosongkan (jangan centang "Add README"), lalu:

```bash
git remote add origin https://github.com/USERNAME/sbdy-database-web.git
git branch -M main
git push -u origin main
```

## Langkah 7 — Deploy ke Netlify (via GitHub)

1. Buka [app.netlify.com](https://app.netlify.com) → **Add new site** → **Import an existing project** → pilih **GitHub** → authorize → pilih repo `sbdy-database-web`.
2. Build settings: kosongkan **Build command**, isi **Publish directory** dengan `.` (titik) — sudah otomatis terbaca dari `netlify.toml` yang ada di folder ini, jadi biasanya tinggal klik **Deploy site**.
3. Tunggu proses deploy (~30 detik untuk static site), lalu buka URL `*.netlify.app` yang diberikan.
4. (Opsional) **Site settings > Domain management** untuk pasang custom domain.

Setelah ini, **setiap kali kamu `git push` ke branch `main`, Netlify otomatis re-deploy** — jadi modifikasi berikutnya tinggal edit `index.html` → commit → push.

## Langkah 8 — Tes

1. Buka URL Netlify-nya. Harus muncul layar login ("Database Sumber Daya").
2. Login pakai akun editor yang dibuat di Langkah 4.
3. Coba tambah 1 item / harga → cek muncul di Supabase Table Editor > `bank_state` (kolom `data`).
4. Buka di browser/incognito lain, login dengan akun viewer lain (atau tunggu ~25 detik) → data seharusnya muncul otomatis tanpa perlu ditambahkan manual.

---

## Troubleshooting

| Gejala | Penyebab umum |
|---|---|
| "Konfigurasi CLOUD belum diisi" | `CLOUD.url` / `CLOUD.anonKey` di `index.html` masih placeholder — ulangi Langkah 5. |
| "Sistem login tidak bisa dimuat" | Dibuka langsung dari file lokal (`file://`) bukan lewat hosting, atau tidak ada koneksi internet. Harus diakses via URL Netlify (atau `netlify dev` / server lokal). |
| Login gagal, "Invalid login credentials" | Akun belum dibuat di Authentication > Users, atau **Auto Confirm User** tidak dicentang saat membuat akun. |
| Bisa login tapi tombol edit tidak muncul | Emailmu belum ada di tabel `editors`, atau email di tabel berbeda huruf besar/kecil / spasi dengan email akun login. |
| Data tidak sinkron ke user lain | Cek RLS policy `bank_state_select_authenticated` ada & aktif; cek juga tidak ada error di console (F12) saat `pullRemote`. |

## Modifikasi ke depan

Karena semuanya 1 file (`index.html`), untuk modifikasi tinggal:

```bash
# edit index.html sesuai kebutuhan
git add index.html
git commit -m "deskripsi perubahan"
git push
```

Netlify otomatis build ulang dalam hitungan detik. Kalau nanti perubahannya besar (mis. pisah jadi banyak file, tambah framework), struktur `netlify.toml` di sini tinggal disesuaikan (`publish` dir & `command`).
