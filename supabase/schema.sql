-- ============================================================================
-- Database Sumber Daya RAB — Supabase schema
-- Jalankan file ini SEKALI di: Supabase Dashboard > SQL Editor > New query > Run
-- ============================================================================

-- 1) Tabel utama: menyimpan seluruh "overlay" data (harga, item custom, dsb)
--    sebagai satu baris JSON (id selalu = 1). Ini sesuai cara kerja index.html
--    (fungsi pullRemote / sbPush di dalam file tersebut).
create table if not exists public.bank_state (
  id integer primary key,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- 2) Tabel daftar editor: email yang boleh MENGUBAH data (tambah/edit/hapus/impor).
--    Selain yang ada di sini, user yang login hanya bisa LIHAT (read-only).
create table if not exists public.editors (
  email text primary key
);

-- 3) Baris awal id=1 supaya app langsung bisa "upsert" saat editor pertama menyimpan.
insert into public.bank_state (id, data)
values (1, '{}'::jsonb)
on conflict (id) do nothing;

-- ============================================================================
-- Row Level Security (RLS)
-- ============================================================================
alter table public.bank_state enable row level security;
alter table public.editors enable row level security;

-- editors: user yang sudah login hanya boleh cek statusnya SENDIRI
--          (dipakai app untuk "apakah email saya = editor?").
drop policy if exists "editors_select_self" on public.editors;
create policy "editors_select_self"
  on public.editors
  for select
  to authenticated
  using (email = auth.jwt() ->> 'email');

-- bank_state: siapa pun yang sudah login (punya akun) boleh membaca data.
drop policy if exists "bank_state_select_authenticated" on public.bank_state;
create policy "bank_state_select_authenticated"
  on public.bank_state
  for select
  to authenticated
  using (true);

-- bank_state: hanya email yang terdaftar di tabel editors yang boleh insert...
drop policy if exists "bank_state_insert_editors" on public.bank_state;
create policy "bank_state_insert_editors"
  on public.bank_state
  for insert
  to authenticated
  with check (
    exists (select 1 from public.editors e where e.email = auth.jwt() ->> 'email')
  );

-- ...dan update (dipakai saat upsert menyimpan perubahan).
drop policy if exists "bank_state_update_editors" on public.bank_state;
create policy "bank_state_update_editors"
  on public.bank_state
  for update
  to authenticated
  using (
    exists (select 1 from public.editors e where e.email = auth.jwt() ->> 'email')
  )
  with check (
    exists (select 1 from public.editors e where e.email = auth.jwt() ->> 'email')
  );

-- Catatan:
-- * Tabel `editors` sengaja TIDAK punya policy insert/update/delete untuk role
--   "authenticated" — supaya user biasa tidak bisa menjadikan dirinya editor
--   sendiri lewat aplikasi. Tambah/hapus editor lewat Table Editor di dashboard
--   Supabase (yang login sebagai kamu/admin otomatis bypass RLS di situ).
--
-- * Setelah menjalankan script ini, tambahkan minimal satu editor, contoh:
--   insert into public.editors (email) values ('emailkamu@gmail.com');
--
-- * User (viewer maupun editor) tetap harus dibuatkan AKUN LOGIN lewat
--   Authentication > Users > Add user di dashboard Supabase — aplikasi ini
--   tidak punya form "daftar/sign up" sendiri, jadi hanya login.
