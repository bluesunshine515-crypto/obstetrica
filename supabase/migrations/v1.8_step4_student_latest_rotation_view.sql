-- ============================================================
-- Obstetrica · v1.8 Step 4 migration
-- v_student_latest_rotation：每個學生最近一筆 rotation attempt 的 cohort_code
--
-- 用途：admin Tab 1（班級總覽）多一欄「最近梯次」，老師可以快速看到每位學員
--      目前是哪一梯（11505 等）。
--
-- 設計：
--   - DISTINCT ON (student_id) 取 attempted_at 最新的那筆 attempt 對應的 session
--   - WITH (security_invoker = true)：學生只看自己、老師看全部
--   - 沿用 Step 3 共用過濾條件（rotation_title_normalized IS NOT NULL、phase pretest/posttest）
--
-- 重複執行安全：CREATE OR REPLACE VIEW
-- 依賴：v1 schema + v1.8 Step 1 + v1.8 Step 3
-- ============================================================

create or replace view public.v_student_latest_rotation
with (security_invoker = true) as
select distinct on (a.student_id)
  a.student_id,
  s.rotation_title_normalized                              as rotation_key,
  substring(s.rotation_title_normalized from '\d{3,}')     as cohort_code,
  s.rotation_title                                         as rotation_title_display,
  s.phase,
  a.attempted_at                                           as last_attempt_at
from   public.attempts      a
join   public.exam_sessions s on s.id = a.session_id
where  s.rotation_title_normalized is not null
  and  s.phase in ('pretest', 'posttest')
order by a.student_id, a.attempted_at desc;

comment on view public.v_student_latest_rotation is
  'v1.8 Step 4: 每位學生最近一筆 rotation attempt 對應的 cohort 資訊。DISTINCT ON + attempted_at DESC 取最新。';

select 'v1.8 Step 4 migration applied (v_student_latest_rotation view)' as status;
