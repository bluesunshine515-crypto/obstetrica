-- ============================================================
-- Obstetrica · v1.12 migration — Cleanup unrecoverable NULL sessions
--
-- 目的：清除第一版第一梯遺留、無法歸位的髒資料。
--
-- 背景：
--   早期 fail-open 邏輯把「無梯次」的作答導向兩個 seed 共享 session
--   （name = '2026 住院醫師 · 前測/後測'，rotation_title = NULL）。
--   其中前測 session 累積了 6 位學生共 171 筆作答，因所有 rotation view
--   皆 filter rotation_title_normalized IS NOT NULL，這 171 筆已從分析中消失。
--
--   經查證無法可靠歸位：這 6 人 cohort_code 皆為 null，且同時段無任何
--   正常梯次 session 可當錨點比對。經團隊決定：此為第一梯實驗性資料，割捨。
--
-- 範圍（已用 dry-run 確認，2026-XX-XX）：
--   pretest  session e6a4d5d9... → 171 attempts, 6 students
--   posttest session 20f579ad... → 0 attempts（空殼）
--   ※ practice 共享 session（300 筆）不在此範圍，保留。
--
-- 安全設計：刪除前先完整複製進 DB 內備份表，可稽核／可還原。
-- 依賴：v1 schema
-- ============================================================

begin;

-- ----- 1. 建備份表（若不存在），完整保留待刪資料 -----
create table if not exists public._deleted_null_sessions_backup_v1_12 (
  backup_at    timestamptz not null default now(),
  source_table text        not null,
  row_data     jsonb       not null
);

-- 1a. 備份即將刪除的 attempts（171 筆）
insert into public._deleted_null_sessions_backup_v1_12 (source_table, row_data)
select 'attempts', to_jsonb(a)
from public.attempts a
join public.exam_sessions s on s.id = a.session_id
where s.phase in ('pretest','posttest')
  and s.rotation_title_normalized is null;

-- 1b. 備份即將刪除的 exam_sessions（2 筆）
insert into public._deleted_null_sessions_backup_v1_12 (source_table, row_data)
select 'exam_sessions', to_jsonb(s)
from public.exam_sessions s
where s.phase in ('pretest','posttest')
  and s.rotation_title_normalized is null;

-- ----- 2. 驗證備份筆數（跑起來心裡有數）-----
select
  source_table,
  count(*) as backed_up
from public._deleted_null_sessions_backup_v1_12
where backup_at > now() - interval '1 minute'
group by source_table;
-- 期望：attempts = 171, exam_sessions = 2

-- ----- 3. 刪除 attempts（先刪子表，避免 FK 問題）-----
delete from public.attempts a
using public.exam_sessions s
where a.session_id = s.id
  and s.phase in ('pretest','posttest')
  and s.rotation_title_normalized is null;

-- ----- 4. 刪除空殼 / NULL session（2 個）-----
delete from public.exam_sessions s
where s.phase in ('pretest','posttest')
  and s.rotation_title_normalized is null;

-- ----- 5. 收尾驗證：這兩類 NULL session 應已歸零 -----
select
  count(*) as remaining_null_prepost_sessions
from public.exam_sessions
where phase in ('pretest','posttest')
  and rotation_title_normalized is null;
-- 期望：0

commit;

-- ============================================================
-- 還原方式（萬一需要）：
--   待刪資料完整存於 public._deleted_null_sessions_backup_v1_12。
--   可用 jsonb_populate_record 從 row_data 還原回原表。
--   確認長期不需要後，可 drop 該備份表釋放空間。
-- ============================================================
