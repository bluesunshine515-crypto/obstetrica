-- ============================================================
-- Obstetrica · v1.8 Step 1 migration
-- Per-rotation exam_sessions schema：
--   1. exam_sessions 新增 rotation_title / rotation_title_normalized 欄位
--   2. normalize_rotation_title() function（全形→半形 + 折疊空白 + lower）
--   3. trg_normalize_rotation_title() trigger function
--   4. BEFORE INSERT/UPDATE trigger 掛上 exam_sessions
--   5. 兩個 btree index（rotation_title_normalized 部分 + phase）
--   6. 既有 row 的 rotation_title_normalized backfill
--
-- 範圍說明：
--   v1.7（admin Tab 1–5）的 commit 不含 SQL —— 純前端讀既有表。
--   但 v1.7 期間實際在 DB 上手動加過 idx_exam_sessions_phase（admin 用 phase
--   篩選 session）。為了讓 schema.sql + migrations 加總 = DB 真實狀態，
--   把那個 index 一起補在本檔。
--
-- 依賴：v1 schema.sql 已先跑過（exam_sessions 表存在）
-- 重複執行安全（add column if not exists / create or replace / drop+create trigger）
-- ============================================================

-- ----- 1. Columns -----
alter table public.exam_sessions
  add column if not exists rotation_title            text;
alter table public.exam_sessions
  add column if not exists rotation_title_normalized text;

-- ----- 2. Normalize function -----
-- 行為：
--   - NULL / 純空白 → NULL
--   - 全形英數轉半形（注意：全形大寫 Ａ-Ｚ 也對應到半形「小寫」a-z，所以
--     最後的 LOWER 對英文字而言是冗餘但無害）
--   - 多重空白（含全形空白 '　'）折疊成單一半形空白
-- 用途：rotation pre/post 配對的 key —
--   「Rotation A」「rotation　Ａ」「ＲＯＴＡＴＩＯＮ a」 → 全部 normalize 為 'rotation a'，
--   被視為同一個 rotation。
create or replace function public.normalize_rotation_title(input text)
returns text
language plpgsql
immutable
as $function$
begin
  if input is null or trim(input) = '' then
    return null;
  end if;

  return lower(
    regexp_replace(
      trim(
        translate(
          input,
          '　ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ０１２３４５６７８９',
          ' abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz0123456789'
        )
      ),
      '\s+',
      ' ',
      'g'
    )
  );
end;
$function$;

-- ----- 3. Trigger function -----
create or replace function public.trg_normalize_rotation_title()
returns trigger
language plpgsql
as $function$
begin
  new.rotation_title_normalized := normalize_rotation_title(new.rotation_title);
  return new;
end;
$function$;

-- ----- 4. Trigger (BEFORE INSERT OR UPDATE) -----
drop trigger if exists exam_sessions_normalize_rotation on public.exam_sessions;
create trigger exam_sessions_normalize_rotation
  before insert or update on public.exam_sessions
  for each row execute function public.trg_normalize_rotation_title();

-- ----- 5. Indexes -----
create index if not exists idx_exam_sessions_rotation_normalized
  on public.exam_sessions (rotation_title_normalized)
  where rotation_title_normalized is not null;

create index if not exists idx_exam_sessions_phase
  on public.exam_sessions (phase);

-- ----- 6. Backfill -----
-- trigger 只在 INSERT/UPDATE 時觸發。若有既有 row 已寫 rotation_title 但
-- rotation_title_normalized 仍是 NULL（例：column 比 trigger 早建），
-- 強制 self-update 一次讓 trigger 把 normalize 值算回來。
-- 在當前 DB 上應為 0 row 命中（v1.6 seed 的三筆 rotation_title 本來就是 NULL）。
update public.exam_sessions
set    rotation_title = rotation_title
where  rotation_title is not null
  and  rotation_title_normalized is null;

-- ----- Done -----
select 'v1.8 Step 1 migration applied (rotation_title columns + normalize trigger + indexes)' as status;
