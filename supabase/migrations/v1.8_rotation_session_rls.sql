-- ============================================================
-- Obstetrica · v1.8 RLS migration
-- 讓登入學生能為自己的 rotation 前/後測 INSERT 一筆 exam_sessions
--
-- 在 Supabase Dashboard → SQL Editor → New query 貼上後按 Run
-- 重複執行安全（drop + create）
--
-- 前置條件（已在 v1.7/v1.8 Step 1 手動 ALTER 完成，本檔不重複）：
--   - public.exam_sessions 已存在 column: rotation_title (text)
--   - public.exam_sessions 已存在 column: rotation_title_normalized (text)
--   - 對應的 normalize trigger 已建好
-- ============================================================

drop policy if exists sessions_student_insert_rotation on public.exam_sessions;

-- 學生只能 INSERT、且必須符合：
--   1. 已登入
--   2. phase 限定 pretest / posttest（不能塞 practice 或自訂值）
--   3. rotation_title 不可為 NULL 或空白
create policy sessions_student_insert_rotation
  on public.exam_sessions for insert
  with check (
    auth.uid() is not null
    and phase in ('pretest', 'posttest')
    and rotation_title is not null
    and length(trim(rotation_title)) > 0
  );

-- 注意：UPDATE / DELETE 仍維持「老師專屬」（既有 sessions_teacher_write policy）。
-- SELECT 維持「任何登入者可讀」（既有 sessions_auth_select policy）。

select 'v1.8 rotation session RLS migration applied' as status;
