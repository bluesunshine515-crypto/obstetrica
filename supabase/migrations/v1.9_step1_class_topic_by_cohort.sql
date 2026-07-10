-- ============================================================
-- Obstetrica · v1.9 Step 1 migration
-- v_class_topic_stats_by_cohort — 班級 topic stats 加 cohort 維度
--
-- 動機：
--   原 v_class_topic_stats 是全班全時間（含 practice）的彙整，
--   老師沒辦法問「11506 這梯的弱項是什麼」。本 view 補上 cohort_code 維度。
--
-- 設計對齊 v1.8 Step 3：
--   - cohort_code = substring(rotation_title_normalized from '\d{3,}')
--   - 過濾 rotation_title_normalized IS NOT NULL（排除 v1.7 舊共享 session）
--   - 過濾 phase IN ('pretest','posttest')（practice 不算梯次評估）
--   - 過濾 category IS NOT NULL（無分類的 attempts 無法歸到 topic）
--   - WITH (security_invoker = true) — view 用 caller 權限跑，底層 RLS 才會生效
--
-- 欄位對齊原 v_class_topic_stats（admin 端 normalize 邏輯可複用）：
--   major_topic / sub_topic / total_attempts / correct / class_accuracy / unique_students
--   多加：cohort_code（前端 filter 用）
--
-- 重複執行安全：CREATE OR REPLACE VIEW
-- 依賴：v1 schema + v1.8 Step 1 (rotation_title_columns) 已先跑過
-- ============================================================

create or replace view public.v_class_topic_stats_by_cohort
with (security_invoker = true) as
select
  substring(s.rotation_title_normalized from '\d{3,}')          as cohort_code,
  split_part(a.category, '-', 1)                                as major_topic,
  split_part(a.category, '-', 2)                                as sub_topic,
  count(*)::int                                                 as total_attempts,
  count(*) filter (where a.is_correct)::int                     as correct,
  round(
    100.0 * count(*) filter (where a.is_correct) / nullif(count(*), 0),
    2
  )                                                             as class_accuracy,
  count(distinct a.student_id)::int                             as unique_students
from   public.exam_sessions s
join   public.attempts      a on a.session_id = s.id
where  s.rotation_title_normalized is not null
  and  s.phase in ('pretest', 'posttest')
  and  a.category is not null
group by 1, 2, 3;

comment on view public.v_class_topic_stats_by_cohort is
  'v1.9 Step 1: cohort × major_topic × sub_topic 三維班級 topic stats。'
  '排除 v1.7 舊共享 session、practice phase、無 category 的 attempts。'
  'sub_topic 取 split_part(category, ''-'', 2)，若原 v_class_topic_stats 用別的拆法可調整。';

-- ----- Done -----
select 'v1.9 Step 1 migration applied (v_class_topic_stats_by_cohort)' as status;
