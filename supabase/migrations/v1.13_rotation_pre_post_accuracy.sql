-- ============================================================
-- Obstetrica · v1.13 migration — 梯次前後測正確率分離
--
-- 問題：
--   v_rotation_cohort_overview 的 overall_accuracy 用 avg() 對整個梯次的
--   所有 attempts 取平均，把 pretest 和 posttest 揉在一起，看不出學生有沒有
--   進步——而這正是前後測的全部意義。前後測場次常不對等（例：11507 前測 8
--   場 vs 後測 3 場），混合平均會被場次多的一方拉走，數字沒有教學意義。
--
-- 修法：
--   沿用本 view 既有的 FILTER pattern，把正確率依 phase 分離，
--   並新增 delta_accuracy（後測 − 前測）。
--
-- ⚠️ 重要：CREATE OR REPLACE VIEW 只能在欄位清單「尾端」追加新欄，
--         不可在中間插入或改變既有欄位順序（否則 PG 報 42P16）。
--         故所有新欄位一律置於最後，原有 13 欄順序原封不動。
--
-- 新增欄位（全部在尾端）：
--   pretest_attempts / posttest_attempts   各階段答題數
--   pretest_accuracy / posttest_accuracy   各階段正確率（無資料為 NULL）
--   delta_accuracy                         進步幅度（正值 = 進步；任一方缺 → NULL）
--
-- 保留 overall_accuracy（向後相容；但不建議再用於教學判讀）
--
-- ⚠️ 已知限制（待 Step 1b-1/1b-4 處理）：
--   目前無 attempt_no，若學生重測，同階段多次作答會被 avg() 混算。
--   依團隊決議（方案 B：pretest 取最早、posttest 取最晚），待 exam_sessions
--   加上 student_id + attempt_no 後，本 view 需再改為「明確取單次」。
--
-- 依賴：v1.8
-- 註：保留 security_invoker（此 view 原本就有，勿遺漏）
-- ============================================================

create or replace view public.v_rotation_cohort_overview
with (security_invoker = true) as
select
  -- ===== 原有 13 欄，順序不可更動 =====
  s.rotation_title_normalized                                   as rotation_key,
  substring(s.rotation_title_normalized, '\d{3,}'::text)        as cohort_code,
  min(s.rotation_title)                                         as rotation_title_display,
  count(distinct a.student_id)                                  as student_count,
  count(distinct s.id)                                          as session_count,
  count(distinct s.id) filter (where s.phase = 'pretest')       as pretest_session_count,
  count(distinct s.id) filter (where s.phase = 'posttest')      as posttest_session_count,
  count(a.*)                                                    as total_attempts,
  round(avg(case when a.is_correct then 1.0 else 0::numeric end) * 100::numeric, 2)
                                                                as overall_accuracy,
  round(avg(a.time_spent_sec), 2)                               as avg_time_spent_sec,
  min(a.attempted_at)                                           as first_attempt_at,
  max(a.attempted_at)                                           as last_attempt_at,

  -- ===== 以下為 v1.13 新增，一律置於尾端 =====
  count(a.*) filter (where s.phase = 'pretest')                 as pretest_attempts,
  count(a.*) filter (where s.phase = 'posttest')                as posttest_attempts,

  round(
    avg(case when a.is_correct then 1.0 else 0::numeric end)
      filter (where s.phase = 'pretest') * 100::numeric, 2
  )                                                             as pretest_accuracy,
  round(
    avg(case when a.is_correct then 1.0 else 0::numeric end)
      filter (where s.phase = 'posttest') * 100::numeric, 2
  )                                                             as posttest_accuracy,

  round(
    avg(case when a.is_correct then 1.0 else 0::numeric end)
      filter (where s.phase = 'posttest') * 100::numeric
    -
    avg(case when a.is_correct then 1.0 else 0::numeric end)
      filter (where s.phase = 'pretest') * 100::numeric, 2
  )                                                             as delta_accuracy

from exam_sessions s
  join attempts a on a.session_id = s.id
where s.rotation_title_normalized is not null
  and s.phase = any (array['pretest'::text, 'posttest'::text])
group by s.rotation_title_normalized;

-- ----- 套用後檢視 -----
select
  cohort_code,
  student_count,
  pretest_attempts,  pretest_accuracy,
  posttest_attempts, posttest_accuracy,
  delta_accuracy,
  overall_accuracy
from public.v_rotation_cohort_overview
order by cohort_code;
-- 預期：11505/11506 的 posttest_accuracy 與 delta 為 NULL（尚無後測資料）
--       11507 可看到真實的 pretest / posttest / delta
