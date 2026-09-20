-- TALOG20 Migration: AI Grading Schema (aditif)
-- Semua perubahan bersifat aditif. Tidak ada DROP, tidak ada ALTER TYPE.

-- ============================================================
-- 1. Tabel answer_keys
-- ============================================================
create table if not exists public.answer_keys (
  id             uuid         primary key default gen_random_uuid(),
  todo_id        uuid         not null unique references public.todos(id) on delete cascade,
  created_by     uuid         not null references public.profiles(id),
  question_type  text         not null check (question_type in ('multiple_choice','short_answer','essay')),
  answer_key     jsonb        not null default '{}'::jsonb,
  rubric         text,
  max_score      numeric(5,2) not null default 100,
  created_at     timestamptz  not null default now(),
  updated_at     timestamptz  not null default now()
);

create index if not exists answer_keys_todo_id_idx on public.answer_keys (todo_id);

-- ============================================================
-- 2. Kolom tambahan di submissions
-- ============================================================
alter table public.submissions
  add column if not exists answer_text text;

-- ============================================================
-- 3. Kolom tambahan di grades
-- ============================================================
alter table public.grades
  add column if not exists source text not null default 'manual';

alter table public.grades
  add column if not exists ai_feedback text;

alter table public.grades
  add column if not exists needs_review boolean not null default false;

alter table public.grades
  add column if not exists confidence numeric(3,2);

alter table public.grades
  drop constraint if exists grades_source_check;

alter table public.grades
  add constraint grades_source_check
  check (source in ('manual','auto','ai'));

-- ============================================================
-- 4. RLS untuk answer_keys
-- KRITIKAL: siswa TIDAK BOLEH membaca answer_keys
-- ============================================================
alter table public.answer_keys enable row level security;

drop policy if exists answer_keys_staff_all on public.answer_keys;
create policy answer_keys_staff_all on public.answer_keys
for all to authenticated
using (
  public.current_user_role() in ('teacher', 'admin', 'superadmin')
)
with check (
  public.current_user_role() in ('teacher', 'admin', 'superadmin')
);

-- ============================================================
-- 5. RPC auto_grade_submission
-- ============================================================
create or replace function public.auto_grade_submission(p_submission_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_submission  record;
  v_answer_key  record;
  v_student_answer text;
  v_correct_answer text;
  v_score       numeric(5,2) := 0;
  v_total       integer := 0;
  v_correct     integer := 0;
  v_key_item    record;
  v_now         timestamptz := now();
  v_grader_id   uuid;
begin
  select s.id, s.todo_id as s_todo_id, s.answer_text as student_answer_text
  into v_submission
  from public.submissions s
  where s.id = p_submission_id;

  if not found then
    return jsonb_build_object('status', 'error', 'message', 'Submission tidak ditemukan');
  end if;

  select * into v_answer_key
  from public.answer_keys ak
  where ak.todo_id = v_submission.s_todo_id;

  if not found then
    return jsonb_build_object('status', 'skipped', 'message', 'Kunci jawaban belum tersedia');
  end if;

  if v_answer_key.question_type = 'essay' then
    return jsonb_build_object(
      'status', 'needs_ai',
      'message', 'Tipe esai membutuhkan penilaian AI',
      'submission_id', p_submission_id
    );
  end if;

  v_grader_id := v_answer_key.created_by;

  for v_key_item in
    select key, value #>> '{}' as correct
    from jsonb_each(v_answer_key.answer_key)
  loop
    v_total := v_total + 1;
    v_student_answer := coalesce(v_submission.student_answer_text, '');

    begin
      if v_submission.student_answer_text is not null and
         left(trim(v_submission.student_answer_text), 1) = '{' then
        v_student_answer := coalesce(
          (v_submission.student_answer_text::jsonb ->> v_key_item.key), ''
        );
      end if;
    exception when others then
      v_student_answer := coalesce(v_submission.student_answer_text, '');
    end;

    v_student_answer := lower(trim(regexp_replace(v_student_answer, '\s+', ' ', 'g')));
    v_correct_answer := lower(trim(regexp_replace(v_key_item.correct, '\s+', ' ', 'g')));

    if v_student_answer = v_correct_answer then
      v_correct := v_correct + 1;
    end if;
  end loop;

  if v_total > 0 then
    v_score := round((v_correct::numeric / v_total::numeric) * v_answer_key.max_score, 2);
  else
    v_score := 0;
  end if;

  insert into public.grades (
    submission_id, grader_user_id, score, feedback,
    graded_at, source, needs_review
  )
  values (
    p_submission_id, v_grader_id, v_score,
    format('Auto-graded: %s/%s jawaban benar', v_correct, v_total),
    v_now, 'auto', false
  )
  on conflict (submission_id) do update set
    score          = excluded.score,
    feedback       = excluded.feedback,
    graded_at      = excluded.graded_at,
    source         = 'auto',
    needs_review   = false,
    grader_user_id = excluded.grader_user_id;

  update public.submissions
  set status = 'graded', updated_at = v_now
  where id = p_submission_id;

  return jsonb_build_object(
    'status', 'graded',
    'submission_id', p_submission_id,
    'score', v_score,
    'correct', v_correct,
    'total', v_total
  );
end;
$$;

-- ============================================================
-- 6. RPC auto_grade_todo
-- ============================================================
create or replace function public.auto_grade_todo(p_todo_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sub      record;
  v_result   jsonb;
  v_graded   integer := 0;
  v_skipped  integer := 0;
  v_needs_ai integer := 0;
  v_errors   integer := 0;
  v_details  jsonb   := '[]'::jsonb;
begin
  for v_sub in
    select id from public.submissions where todo_id = p_todo_id
  loop
    begin
      v_result := public.auto_grade_submission(v_sub.id);
      case v_result->>'status'
        when 'graded'   then v_graded   := v_graded   + 1;
        when 'skipped'  then v_skipped  := v_skipped  + 1;
        when 'needs_ai' then v_needs_ai := v_needs_ai + 1;
        else                 v_errors   := v_errors   + 1;
      end case;
      v_details := v_details || v_result;
    exception when others then
      v_errors  := v_errors + 1;
      v_details := v_details || jsonb_build_object(
        'status', 'error',
        'submission_id', v_sub.id,
        'message', sqlerrm
      );
    end;
  end loop;

  return jsonb_build_object(
    'todo_id',  p_todo_id,
    'graded',   v_graded,
    'skipped',  v_skipped,
    'needs_ai', v_needs_ai,
    'errors',   v_errors,
    'details',  v_details
  );
end;
$$;

grant execute on function public.auto_grade_submission(uuid) to authenticated;
grant execute on function public.auto_grade_todo(uuid) to authenticated;
