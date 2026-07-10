-- ============================================================
-- Obstetrica · v1.11 migration — Secure legacy views (RLS fix)
--
-- 🔴 修補現在進行式的資料外洩。
--
-- 問題：v1.10 backfill 的 5 支 view 缺 security_invoker，預設以 owner 權限
--       執行、bypass 呼叫者 RLS。任何登入學生打 REST API 即可讀到全班資料。
--       （2026-XX-XX 實測：reloptions 為 null 確認 flag 未套用。）
--
-- 修法：用 ALTER VIEW ... SET 直接補上 security_invoker，不重寫定義。
--       這比 CREATE OR REPLACE 更精準——只動選項、零風險改到 SELECT 邏輯。
--
-- 為什麼不會弄壞後台（已核對 schema.sql RLS）：
--   base table 雙軌政策——學生只看自己(auth.uid()=student_id)、
--   老師看全部(current_user_is_teacher(), security definer)。
--   flag 打開後：學生查→只見自己(洞補起)、老師查→見全班(後台照常)。
--
-- 依賴：v1.10（5 支 view 需已存在）
-- 重複執行安全：ALTER ... SET 對已設定者為 no-op
-- ============================================================

alter view public.v_question_stats         set (security_invoker = true);
alter view public.v_class_topic_stats       set (security_invoker = true);
alter view public.v_student_topic_stats     set (security_invoker = true);
alter view public.v_student_overview        set (security_invoker = true);
alter view public.v_misconception_hotspots  set (security_invoker = true);

-- ----- 立即自我驗證：五支 reloptions 應皆含 security_invoker=true -----
select c.relname, c.reloptions
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('v_question_stats','v_class_topic_stats',
                    'v_student_topic_stats','v_student_overview',
                    'v_misconception_hotspots')
order by 1;

-- ============================================================
-- 套用後回歸測試（務必兩種身分各跑一次）
-- ============================================================
-- 【學生視角】用真學生 JWT（見下方對話說明的 set local 方法）：
--     count(*) from v_student_overview  → 期望 = 1
-- 【老師視角】老師帳號登入後台 Tab 1 → 期望：仍見全班
-- ============================================================
