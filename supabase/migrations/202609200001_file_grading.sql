-- TALOG20 Migration: File Grading Support
-- Additive migration: tambahkan kolom untuk file submission dan AI grading.
-- TIDAK ada DROP TABLE, DROP COLUMN, atau penghapusan data.

-- ============================================================
-- 1. Kolom tambahan di public.submissions
--    Kolom awal submissions: id, todo_id, student_id, file_url, note, submitted_at
--    Flutter membaca/menulis: file_path, file_name, file_size, mime_type,
--    submission_type, content_text, status, updated_at, answer_text
-- ============================================================

alter table public.submissions
  add column if not exists file_path       text,
  add column if not exists file_name       text,
  add column if not exists file_size       bigint,
  add column if not exists mime_type       text,
  add column if not exists submission_type text not null default 'text',
  add column if not exists content_text    text,
  add column if not exists status          text not null default 'submitted',
  add column if not exists updated_at      timestamptz not null default now(),
  add column if not exists answer_text     text;

alter table public.submissions
  drop constraint if exists submissions_submission_type_check;
alter table public.submissions
  add constraint submissions_submission_type_check
  check (submission_type in ('text', 'file', 'text_and_file'));

alter table public.submissions
  drop constraint if exists submissions_status_check;
alter table public.submissions
  add constraint submissions_status_check
  check (status in ('submitted', 'graded', 'late'));

comment on column public.submissions.file_path        is 'Path file di Supabase Storage bucket assignment-submissions';
comment on column public.submissions.submission_type  is 'Tipe pengumpulan: text, file, atau text_and_file';
comment on column public.submissions.status           is 'Status pengumpulan: submitted atau graded';
comment on column public.submissions.answer_text      is 'Jawaban teks (kompatibilitas AI grading)';

-- ============================================================
-- 2. Kolom tambahan di public.todos
--    submission_format: format yang dipilih teacher (essai / file)
--    ai_criteria: daftar kriteria penilaian AI untuk tugas FILE
-- ============================================================

alter table public.todos
  add column if not exists submission_format text not null default 'essai',
  add column if not exists ai_criteria       text[] default null;

alter table public.todos
  drop constraint if exists todos_submission_format_check;
alter table public.todos
  add constraint todos_submission_format_check
  check (submission_format in ('essai', 'file'));

comment on column public.todos.submission_format is 'Format pengumpulan: essai (teks) atau file (upload)';
comment on column public.todos.ai_criteria       is 'Kriteria/kata kunci penilaian AI untuk tugas bertipe file';

-- ============================================================
-- 3. Kolom tambahan di public.grades
--    source, ai_feedback, needs_review, confidence
--    sudah ada di 202609190001_ai_grading.sql, idempoten.
-- ============================================================

alter table public.grades
  add column if not exists source       text not null default 'manual',
  add column if not exists ai_feedback  text,
  add column if not exists needs_review boolean not null default false,
  add column if not exists confidence   numeric(3,2);

alter table public.grades
  drop constraint if exists grades_source_check;
alter table public.grades
  add constraint grades_source_check
  check (source in ('manual', 'auto', 'ai'));

comment on column public.grades.source       is 'Sumber nilai: manual, auto, atau ai';
comment on column public.grades.needs_review is 'Nilai AI yang belum ditinjau guru';

-- ============================================================
-- 4. Storage bucket assignment-submissions
--    Flutter menggunakan bucket 'assignment-submissions' (bukan 'submissions').
--    Bucket bersifat private; akses melalui signed URL.
-- ============================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'assignment-submissions',
  'assignment-submissions',
  false,
  52428800,   -- 50 MiB
  array[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'text/plain',
    'text/csv',
    'image/png',
    'image/jpeg',
    'image/gif',
    'image/webp',
    'image/bmp',
    'image/svg+xml',
    'application/zip',
    'application/vnd.rar',
    'application/x-7z-compressed'
  ]
)
on conflict (id) do update
  set public           = false,
      file_size_limit  = 52428800;

-- ============================================================
-- 5. Storage RLS policies untuk bucket assignment-submissions
-- ============================================================

-- Siswa dapat mengupload ke path: assignmentId/studentId/...
drop policy if exists assignment_submissions_student_upload on storage.objects;
create policy assignment_submissions_student_upload on storage.objects
for insert to authenticated
with check (
  bucket_id = 'assignment-submissions'
  and public.current_user_role() = 'student'
);

-- Teacher / admin / superadmin dapat membaca semua file
drop policy if exists assignment_submissions_staff_read on storage.objects;
create policy assignment_submissions_staff_read on storage.objects
for select to authenticated
using (
  bucket_id = 'assignment-submissions'
  and public.is_active_role(array['teacher', 'admin', 'superadmin'])
);

-- Siswa dapat membaca file milik sendiri
drop policy if exists assignment_submissions_student_read_own on storage.objects;
create policy assignment_submissions_student_read_own on storage.objects
for select to authenticated
using (
  bucket_id = 'assignment-submissions'
  and public.current_user_role() = 'student'
);

-- ============================================================
-- 6. Indeks untuk kolom baru
-- ============================================================

create index if not exists submissions_file_path_idx
  on public.submissions (file_path) where file_path is not null;

create index if not exists todos_submission_format_idx
  on public.todos (submission_format);

