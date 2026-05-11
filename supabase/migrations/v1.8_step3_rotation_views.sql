-- ============================================================
-- Obstetrica · v1.8 Step 3 migration
-- Rotation cohort 分析三支 view：
--   1. v_rotation_cohort_overview     — 每個 rotation 一 row（總覽）
--   2. v_rotation_pre_post_pair       — 學生 × rotation 一 row（前後測對比）
--   3. v_rotation_topic_stats         — rotation × phase × category 一 row（主題弱項）
--
-- 共用設計：
--   - 全部過濾 rotation_title_normalized IS NOT NULL（排除 v1.7 舊共享 session）
--   - 全部過濾 phase IN ('pretest','posttest')（排除 practice）
--   - cohort_code = 取 rotation_title_normalized 第一段 ≥3 位連續數字
--   - rotation_title_display = MIN(rotation_title)（同 normalized key 可能對應多種原始輸入）
--   - WITH (security_invoker = true)：view 用 caller 權限跑（PG 15+），讓底層
--     attempts / exam_sessions / students 的 RLS 真的生效。沒這個 flag view 預設
--     用 owner（postgres）權限跑會 bypass RLS，學生會看到全部學員資料。
--
-- 重複執行安全：用 CREATE OR REPLACE VIEW
-- 依賴：v1 schema + v1.8 Step 1 migration 已先跑過
-- ============================================================

-- ----- 1. v_rotation_cohort_overview -----
create or replace view public.v_rotation_cohort_overview
with (security_invoker = true) as
select
  s.rotation_title_normalized                                              as rotation_key,
  substring(s.rotation_title_normalized from '\d{3,}')                     as cohort_code,
  min(s.rotation_title)                                                    as rotation_title_display,
  count(distinct a.student_id)                                             as student_count,
  count(distinct s.id)                                                     as session_count,
  count(distinct s.id) filter (where s.phase = 'pretest')                  as pretest_session_count,
  count(distinct s.id) filter (where s.phase = 'posttest')                 as posttest_session_count,
  count(a.*)                                                               as total_attempts,
  round(avg(case when a.is_correct then 1.0 else 0 end) * 100, 2)          as overall_accuracy,
  round(avg(a.time_spent_sec)::numeric, 2)                                 as avg_time_spent_sec,
  min(a.attempted_at)                                                      as first_attempt_at,
  max(a.attempted_at)                                                      as last_attempt_at
from   public.exam_sessions s
join   public.attempts      a on a.session_id = s.id
where  s.rotation_title_normalized is not null
  and  s.phase in ('pretest', 'posttest')
group by s.rotation_title_normalized;

comment on view public.v_rotation_cohort_overview is
  'v1.8 Step 3: 每個 rotation 一 row 的總覽。filter rotation_title_normalized IS NOT NULL 排除 v1.7 舊共享 session。';

-- ----- 2. v_rotation_pre_post_pair -----
-- 學生 × rotation 一 row。同學生跨 rotation 會出現在多 row（不同 rotation_key）。
create or replace view public.v_rotation_pre_post_pair
with (security_invoker = true) as
select
  s.rotation_title_normalized                                                  as rotation_key,
  substring(s.rotation_title_normalized from '\d{3,}')                         as cohort_code,
  min(s.rotation_title)                                                        as rotation_title_display,
  a.student_id,
  st.name                                                                      as student_name,
  st.email                                                                     as student_email,
  count(*) filter (where s.phase = 'pretest')                                  as pretest_attempts,
  count(*) filter (where s.phase = 'pretest'  and a.is_correct)                as pretest_correct,
  round(
    100.0 * count(*) filter (where s.phase = 'pretest'  and a.is_correct)
         / nullif(count(*) filter (where s.phase = 'pretest'), 0),
    2
  )                                                                            as pretest_accuracy,
  count(*) filter (where s.phase = 'posttest')                                 as posttest_attempts,
  count(*) filter (where s.phase = 'posttest' and a.is_correct)                as posttest_correct,
  round(
    100.0 * count(*) filter (where s.phase = 'posttest' and a.is_correct)
         / nullif(count(*) filter (where s.phase = 'posttest'), 0),
    2
  )                                                                            as posttest_accuracy,
  -- delta = post - pre；任一邊為 NULL 時 delta 也是 NULL
  round(
    100.0 * count(*) filter (where s.phase = 'posttest' and a.is_correct)
         / nullif(count(*) filter (where s.phase = 'posttest'), 0)
  - 100.0 * count(*) filter (where s.phase = 'pretest'  and a.is_correct)
         / nullif(count(*) filter (where s.phase = 'pretest'),  0),
    2
  )                                                                            as delta_accuracy,
  (count(*) filter (where s.phase = 'pretest')  > 0)                           as has_pretest,
  (count(*) filter (where s.phase = 'posttest') > 0)                           as has_posttest,
  (count(*) filter (where s.phase = 'pretest')  > 0
   and count(*) filter (where s.phase = 'posttest') > 0)                       as has_both
from   public.exam_sessions s
join   public.attempts      a  on a.session_id = s.id
join   public.students      st on st.id        = a.student_id
where  s.rotation_title_normalized is not null
  and  s.phase in ('pretest', 'posttest')
group by s.rotation_title_normalized, a.student_id, st.name, st.email;

comment on view public.v_rotation_pre_post_pair is
  'v1.8 Step 3: 學生×rotation 一 row 的前後測對比。delta_accuracy 為 NULL 表示該學生在這 rotation 缺前測或後測。';

-- ----- 3. v_rotation_topic_stats -----
-- rotation × phase × category 一 row。category 取 attempts.category（原始主題分類）。
create or replace view public.v_rotation_topic_stats
with (security_invoker = true) as
select
  s.rotation_title_normalized                                                  as rotation_key,
  substring(s.rotation_title_normalized from '\d{3,}')                         as cohort_code,
  min(s.rotation_title)                                                        as rotation_title_display,
  s.phase,
  a.category,
  count(*)                                                                     as attempts_count,
  count(*) filter (where a.is_correct)                                         as correct_count,
  round(
    100.0 * count(*) filter (where a.is_correct) / nullif(count(*), 0),
    2
  )                                                                            as accuracy_pct,
  count(distinct a.student_id)                                                 as student_count,
  round(avg(a.time_spent_sec)::numeric, 2)                                     as avg_time_spent_sec
from   public.exam_sessions s
join   public.attempts      a on a.session_id = s.id
where  s.rotation_title_normalized is not null
  and  s.phase in ('pretest', 'posttest')
  and  a.category is not null
group by s.rotation_title_normalized, s.phase, a.category;

comment on view public.v_rotation_topic_stats is
  'v1.8 Step 3: rotation × phase × category 三維交叉統計。category IS NULL 的 attempts 被排除。';

-- ----- Done -----
select 'v1.8 Step 3 migration applied (3 rotation views + cohort_code column)' as status;
