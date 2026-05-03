-- ============================================================
-- Obstetrica · Supabase schema (v1)
-- 在 Supabase Dashboard → SQL Editor → New query 貼上後按 Run
-- 重複執行安全（drop + create）
-- ============================================================

-- ----- 0. Clean slate -----
drop trigger  if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user()        cascade;
drop function if exists public.current_user_is_teacher() cascade;
drop function if exists public.is_teacher(text)         cascade;
drop table    if exists public.attempts                 cascade;
drop table    if exists public.exam_sessions            cascade;
drop table    if exists public.students                 cascade;

-- ----- 1. Hard-coded teacher list -----
create or replace function public.is_teacher(email text)
returns boolean
language sql
immutable
as $$
  select lower(coalesce(email,'')) in (
    'bluesunshine515@gmail.com'
  );
$$;

-- ----- 2. Tables -----
create table public.students (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text not null unique,
  name        text,
  year        text,
  role        text not null default 'student' check (role in ('student','teacher')),
  created_at  timestamptz not null default now()
);

create table public.exam_sessions (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  phase       text not null check (phase in ('pretest','posttest','practice')),
  course      text not null default '住院醫師訓練 2026',
  created_at  timestamptz not null default now()
);

create table public.attempts (
  id              uuid primary key default gen_random_uuid(),
  student_id      uuid not null references public.students(id) on delete cascade,
  session_id      uuid not null references public.exam_sessions(id) on delete cascade,
  question_id     text not null,
  category        text,
  exam            text,
  selected_answer text,
  correct_answer  text,
  is_correct      boolean,
  time_spent_sec  integer,
  attempted_at    timestamptz not null default now(),
  unique (student_id, session_id, question_id)
);

create index attempts_session_idx  on public.attempts(session_id);
create index attempts_student_idx  on public.attempts(student_id);
create index attempts_category_idx on public.attempts(category);

-- ----- 3. Auto-provision student row on signup -----
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.students (id, email, role)
  values (
    new.id,
    new.email,
    case when public.is_teacher(new.email) then 'teacher' else 'student' end
  )
  on conflict (id) do update
    set email = excluded.email,
        role  = case when public.is_teacher(excluded.email) then 'teacher' else students.role end;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill: any auth.users that already exist (e.g. you signed up before running this)
insert into public.students (id, email, role)
select u.id, u.email,
       case when public.is_teacher(u.email) then 'teacher' else 'student' end
from   auth.users u
on conflict (id) do update
  set role = case when public.is_teacher(excluded.email) then 'teacher' else students.role end;

-- ----- 4. Role helper (used in RLS) -----
create or replace function public.current_user_is_teacher()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.students
    where id = auth.uid() and role = 'teacher'
  );
$$;

-- ----- 5. Row Level Security -----
alter table public.students      enable row level security;
alter table public.exam_sessions enable row level security;
alter table public.attempts      enable row level security;

-- students: self read + teacher read all + self update profile
create policy students_self_select    on public.students for select
  using (auth.uid() = id);
create policy students_teacher_select on public.students for select
  using (public.current_user_is_teacher());
create policy students_self_update    on public.students for update
  using (auth.uid() = id) with check (auth.uid() = id);

-- exam_sessions: any authenticated user can read; teacher can write
create policy sessions_auth_select    on public.exam_sessions for select
  using (auth.uid() is not null);
create policy sessions_teacher_write  on public.exam_sessions for all
  using (public.current_user_is_teacher())
  with check (public.current_user_is_teacher());

-- attempts: student sees/owns own rows; teacher sees all
create policy attempts_self_select    on public.attempts for select
  using (auth.uid() = student_id);
create policy attempts_teacher_select on public.attempts for select
  using (public.current_user_is_teacher());
create policy attempts_self_insert    on public.attempts for insert
  with check (auth.uid() = student_id);
create policy attempts_self_update    on public.attempts for update
  using (auth.uid() = student_id) with check (auth.uid() = student_id);

-- ----- 6. Seed sessions -----
insert into public.exam_sessions (name, phase, course) values
  ('2026 住院醫師 · 前測', 'pretest',  '住院醫師訓練 2026'),
  ('2026 住院醫師 · 後測', 'posttest', '住院醫師訓練 2026'),
  ('自由練習',             'practice', '住院醫師訓練 2026');

-- ----- Done -----
select 'schema applied · ' ||
       (select count(*) from public.exam_sessions) || ' sessions seeded' as status;
