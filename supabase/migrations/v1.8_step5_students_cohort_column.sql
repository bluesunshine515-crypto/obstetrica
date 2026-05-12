-- ============================================================
-- Obstetrica · v1.8 Step 5 migration
-- 在 students 表加 cohort_code column（學生自己宣告的「我這梯是 X」）
--
-- 設計：
--   - 5 位數字 text（與 exam_sessions.rotation_title 同格式）
--   - CHECK constraint 確保 NULL 或 ^\d{5}$
--   - 學生 login 時 profile modal 填寫，可隨時透過「✏️ 編輯」修改
--   - admin Tab 1 直接從這欄抓 cohort（不再從 v_student_latest_rotation 反推）
--
-- 兩個 source of truth 共存：
--   - students.cohort_code = 「學生宣告」當前梯次
--   - v_student_latest_rotation.cohort_code = 「實際答題」反推的梯次
--   未來可做「宣告 vs 實際」差異 audit。
--
-- 重複執行安全：ADD COLUMN IF NOT EXISTS / DROP CONSTRAINT IF EXISTS
-- 依賴：v1 schema（students 表存在）
-- ============================================================

alter table public.students
  add column if not exists cohort_code text;

-- 用 DROP + ADD 確保 constraint 可重跑（PG 沒有 ADD CONSTRAINT IF NOT EXISTS）
alter table public.students
  drop constraint if exists students_cohort_format;

alter table public.students
  add constraint students_cohort_format
  check (cohort_code is null or cohort_code ~ '^\d{5}$');

comment on column public.students.cohort_code is
  'v1.8 Step 5: 學生自己宣告的當前梯次（5 位數字）。NULL 表示尚未填寫。';

select 'v1.8 Step 5 migration applied (students.cohort_code column + CHECK constraint)' as status;
