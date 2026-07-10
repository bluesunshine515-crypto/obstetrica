-- ============================================================
-- Obstetrica · v1.10 migration — Backfill legacy views
--
-- 目的：把「線上 DB 已存在、但 repo 從未記錄」的 5 支 view 補進版本控制。
--
-- 背景：
--   v1.7 期間（admin Tab 1–5）在 Supabase 手動建了以下 5 支 view，
--   但當時的 commit 只有前端、沒有對應 SQL。導致 repo 的 schema.sql +
--   migrations 加總 ≠ DB 真實狀態。哪天要重建 DB 或換環境，後台會整個掛掉。
--
--   本檔的定義 = 2026-XX-XX 用 pg_get_viewdef() 從線上 DB 原樣 dump 出來的，
--   逐字對齊。**本檔不做任何行為變更**（不加 security_invoker、不改欄位、
--   不 filter phase）——那些修正在 v1.11 之後另開檔處理，以便出問題時能隔離。
--
-- ⚠️ 已知問題（不在本檔修，只記錄）：
--   1. 五支皆缺 security_invoker → 學生可繞過 RLS 讀到全班資料。→ v1.11 修
--   2. sub_topic 拆法與 v1.9 by_cohort 版不一致（此處存完整 category）。→ 後續統一
--   3. 皆 FROM attempts 未 filter phase → practice 資料混入統計，正確率被高估。→ 後續處理
--
-- 依賴：v1 schema.sql（attempts / students 表）
-- 建立順序：v_question_stats 必須先於 v_misconception_hotspots（後者 FROM 前者）
-- 重複執行安全：全部用 CREATE OR REPLACE VIEW
-- ============================================================

-- ----- 1. v_question_stats（以「題目」為單位聚合，是 misconception 的基礎） -----
create or replace view public.v_question_stats as
select
  question_id,
  category,
  exam,
  correct_answer,
  count(*)                                                as total_attempts,
  count(distinct student_id)                              as unique_students,
  count(*) filter (where is_correct)                      as correct_count,
  round(count(*) filter (where is_correct)::numeric
        / count(*)::numeric * 100::numeric, 1)            as class_accuracy,
  count(*) filter (where selected_answer = 'A'::text)     as chose_a,
  count(*) filter (where selected_answer = 'B'::text)     as chose_b,
  count(*) filter (where selected_answer = 'C'::text)     as chose_c,
  count(*) filter (where selected_answer = 'D'::text)     as chose_d,
  count(*) filter (where selected_answer = 'E'::text)     as chose_e
from attempts
group by question_id, category, exam, correct_answer;

-- ----- 2. v_class_topic_stats（全班 · 依 major_topic × 完整 category） -----
create or replace view public.v_class_topic_stats as
select
  split_part(category, '-'::text, 1)                      as major_topic,
  category                                                as sub_topic,
  count(*)                                                as total_attempts,
  count(distinct student_id)                              as unique_students,
  count(*) filter (where is_correct)                      as correct,
  round(count(*) filter (where is_correct)::numeric
        / count(*)::numeric * 100::numeric, 1)            as class_accuracy
from attempts
group by split_part(category, '-'::text, 1), category;

-- ----- 3. v_student_topic_stats（單一學生 · 依 major_topic × 完整 category） -----
create or replace view public.v_student_topic_stats as
select
  student_id,
  split_part(category, '-'::text, 1)                      as major_topic,
  category                                                as sub_topic,
  count(*)                                                as total,
  count(*) filter (where is_correct)                      as correct,
  round(count(*) filter (where is_correct)::numeric
        / count(*)::numeric * 100::numeric, 1)            as accuracy_rate
from attempts a
group by student_id, split_part(category, '-'::text, 1), category;

-- ----- 4. v_student_overview（單一學生 · 全域彙整） -----
create or replace view public.v_student_overview as
select
  s.id                                                    as student_id,
  s.email,
  coalesce(s.name, split_part(s.email, '@'::text, 1))     as display_name,
  s.year,
  s.role,
  count(a.id)                                             as total_attempts,
  count(a.id) filter (where a.is_correct)                 as correct_count,
  count(a.id) filter (where not a.is_correct)             as wrong_count,
  round(coalesce(count(a.id) filter (where a.is_correct)::numeric
        / nullif(count(a.id), 0)::numeric * 100::numeric, 0::numeric), 1) as accuracy_rate,
  count(distinct a.session_id)                            as sessions_count,
  max(a.attempted_at)                                     as last_activity,
  round(avg(a.time_spent_sec), 1)                         as avg_time_per_q
from students s
  left join attempts a on a.student_id = s.id
where s.role = 'student'::text
group by s.id, s.email, s.name, s.year, s.role;

-- ----- 5. v_misconception_hotspots（難題 + 最強誘答；FROM v_question_stats） -----
create or replace view public.v_misconception_hotspots as
select
  question_id,
  category,
  exam,
  correct_answer,
  total_attempts,
  unique_students,
  correct_count,
  class_accuracy,
  chose_a, chose_b, chose_c, chose_d, chose_e,
  case
    when correct_answer <> 'A'::text and chose_a >= greatest(
      case when correct_answer <> 'B'::text then chose_b else 0::bigint end,
      case when correct_answer <> 'C'::text then chose_c else 0::bigint end,
      case when correct_answer <> 'D'::text then chose_d else 0::bigint end,
      case when correct_answer <> 'E'::text then chose_e else 0::bigint end)
      and chose_a > 0 then 'A'::text
    when correct_answer <> 'B'::text and chose_b >= greatest(
      case when correct_answer <> 'A'::text then chose_a else 0::bigint end,
      case when correct_answer <> 'C'::text then chose_c else 0::bigint end,
      case when correct_answer <> 'D'::text then chose_d else 0::bigint end,
      case when correct_answer <> 'E'::text then chose_e else 0::bigint end)
      and chose_b > 0 then 'B'::text
    when correct_answer <> 'C'::text and chose_c >= greatest(
      case when correct_answer <> 'A'::text then chose_a else 0::bigint end,
      case when correct_answer <> 'B'::text then chose_b else 0::bigint end,
      case when correct_answer <> 'D'::text then chose_d else 0::bigint end,
      case when correct_answer <> 'E'::text then chose_e else 0::bigint end)
      and chose_c > 0 then 'C'::text
    when correct_answer <> 'D'::text and chose_d >= greatest(
      case when correct_answer <> 'A'::text then chose_a else 0::bigint end,
      case when correct_answer <> 'B'::text then chose_b else 0::bigint end,
      case when correct_answer <> 'C'::text then chose_c else 0::bigint end,
      case when correct_answer <> 'E'::text then chose_e else 0::bigint end)
      and chose_d > 0 then 'D'::text
    when correct_answer <> 'E'::text and chose_e > 0 then 'E'::text
    else null::text
  end as top_distractor,
  round(coalesce(greatest(
      case when correct_answer <> 'A'::text then chose_a else 0::bigint end,
      case when correct_answer <> 'B'::text then chose_b else 0::bigint end,
      case when correct_answer <> 'C'::text then chose_c else 0::bigint end,
      case when correct_answer <> 'D'::text then chose_d else 0::bigint end,
      case when correct_answer <> 'E'::text then chose_e else 0::bigint end)::numeric
    / nullif(total_attempts - correct_count, 0)::numeric * 100::numeric, 0::numeric), 1)
    as distractor_concentration
from v_question_stats qs
where total_attempts >= 2 and class_accuracy < 70::numeric;

-- ----- Done -----
select 'v1.10 backfill applied · 5 legacy views now in version control' as status;
