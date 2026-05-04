-- ============================================================
-- Obstetrica · v1.6 migration
-- per-student annotations: notes / bookmarks / difficulty_ratings
--
-- 在 Supabase Dashboard → SQL Editor → New query 貼上後按 Run
-- 重複執行安全（drop + create）
-- 依賴：v1 schema.sql 已先跑過（students, current_user_is_teacher）
-- ============================================================

-- ----- 0. Clean slate -----
-- 注意：DROP TRIGGER IF EXISTS 需要 table 存在（PostgreSQL 怪癖），
-- 所以先 DROP TABLE CASCADE，會自動把 trigger 一起拉掉。
drop table    if exists public.notes              cascade;
drop table    if exists public.bookmarks          cascade;
drop table    if exists public.difficulty_ratings cascade;
drop function if exists public.touch_updated_at() cascade;

-- ----- 1. Tables -----
create table public.notes (
  student_id   uuid not null references public.students(id) on delete cascade,
  question_id  text not null,
  body         text not null,
  updated_at   timestamptz not null default now(),
  primary key (student_id, question_id)
);
create index notes_student_idx on public.notes(student_id);

create table public.bookmarks (
  student_id   uuid not null references public.students(id) on delete cascade,
  question_id  text not null,
  created_at   timestamptz not null default now(),
  primary key (student_id, question_id)
);
create index bookmarks_student_idx on public.bookmarks(student_id);

create table public.difficulty_ratings (
  student_id   uuid not null references public.students(id) on delete cascade,
  question_id  text not null,
  stars        smallint not null check (stars between 1 and 5),
  updated_at   timestamptz not null default now(),
  primary key (student_id, question_id)
);
create index difficulty_student_idx on public.difficulty_ratings(student_id);

-- ----- 2. updated_at auto-touch -----
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger notes_touch
  before update on public.notes
  for each row execute function public.touch_updated_at();

create trigger difficulty_touch
  before update on public.difficulty_ratings
  for each row execute function public.touch_updated_at();

-- ----- 3. Row Level Security -----
alter table public.notes              enable row level security;
alter table public.bookmarks          enable row level security;
alter table public.difficulty_ratings enable row level security;

-- notes: 學生對自己的 row 有 ALL 權；老師唯讀
create policy notes_self_all           on public.notes for all
  using (auth.uid() = student_id) with check (auth.uid() = student_id);
create policy notes_teacher_select     on public.notes for select
  using (public.current_user_is_teacher());

-- bookmarks
create policy bookmarks_self_all       on public.bookmarks for all
  using (auth.uid() = student_id) with check (auth.uid() = student_id);
create policy bookmarks_teacher_select on public.bookmarks for select
  using (public.current_user_is_teacher());

-- difficulty_ratings
create policy difficulty_self_all       on public.difficulty_ratings for all
  using (auth.uid() = student_id) with check (auth.uid() = student_id);
create policy difficulty_teacher_select on public.difficulty_ratings for select
  using (public.current_user_is_teacher());

-- ----- Done -----
select 'v1.6 annotations migration applied' as status;
