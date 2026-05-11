# 🧭 Obstetrica 開發工作流 SOP

> 困惑時的隨身查詢手冊
> 作者：Dr. Chen-Yu Wang (Amos) · TSGH OB/GYN
> 版本：v1.0 · 2026-05

---

## 📑 目錄

1. [心智模型：三個工具的角色](#-part-1心智模型三個工具的角色)
2. [黃金 5 步驟工作流](#-part-2黃金-5-步驟工作流)
3. [從關機到開工：5 分鐘啟動流程](#-part-3從關機到開工5-分鐘啟動流程)
4. [跟 Claude Code 溝通的黃金公式](#-part-4跟-claude-code-溝通的黃金公式)
5. [一鍵部署：deploy.ps1 全流程](#-part-5一鍵部署deployps1-全流程)
6. [常見場景對照表](#-part-6常見場景對照表)
7. [五大鐵律](#-part-7五大鐵律)
8. [困惑時的決策樹](#-part-8困惑時的決策樹)
9. [卡住了？常見救援指令](#-part-9卡住了常見救援指令)
10. [完整劇本：加一個新功能](#-part-10完整劇本加一個新功能)
11. [給未來自己的 4 個提醒](#-part-11給未來自己的-4-個提醒)
12. [快速指令參考](#-part-12快速指令參考)

---

## 🎯 Part 1：心智模型 — 三個工具的角色

### 三劍客分工

```
🤖 Claude Code              ← 「思考者 / 寫程式碼的人」
     │                        - 規劃、分析、寫程式
     │                        - 不能跑互動式指令
     │                        - 不能看你的瀏覽器
     ▼

⚡ PowerShell               ← 「執行者 / 司機」
     │                        - 跑指令、執行腳本
     │                        - 跟你互動 (y/N、輸入)
     │                        - 操作本地檔案 + git
     ▼

🌐 瀏覽器 + Supabase        ← 「驗收者 / 用戶」
                              - 開 Supabase Dashboard
                              - 開 GitHub 看 repo
                              - 測試網站運作
```

### 一句話記住

> **Claude Code 動腦寫東西，PowerShell 動手做事，瀏覽器看結果**

### 詳細能力對照

| 工具 | ✅ 能做 | ❌ 不能做 |
|---|---|---|
| **Claude Code** | 讀寫檔案、規劃架構、寫 JS/SQL/HTML、git 操作 | 跑互動腳本（會卡住）、看你的瀏覽器、點按鈕、輸密碼 |
| **PowerShell** | 跑 `.\deploy.ps1`、git pull/push、和你互動 (y/N)、本地檔案操作 | 寫複雜程式邏輯、看網站 UI 對不對、查 Supabase 資料 |
| **瀏覽器 + Supabase** | 看網站長怎樣、F12 看錯誤、Supabase Dashboard、跑 SQL 查資料 | 改原始碼、自動部署、處理多檔案任務 |

---

## 📋 Part 2：黃金 5 步驟工作流

### 標準流程

```
   ┌─────────────────────────────────────────────────┐
   │  Step 1: 想清楚要做什麼（你 + 紙筆）              │
   │     ↓                                            │
   │  Step 2: 跟 Claude Code 規劃 + 寫程式碼          │
   │     ↓                                            │
   │  Step 3: 在 PowerShell 執行 .\deploy.ps1         │
   │     ↓                                            │
   │  Step 4: 在瀏覽器驗證網站正常                    │
   │     ↓                                            │
   │  Step 5: 在 Supabase 驗證資料正確（如有改 DB）   │
   └─────────────────────────────────────────────────┘
```

### 每個步驟的時間預期

| Step | 時間 | 工具 |
|---|---|---|
| 1. 想清楚 | 5-10 min | 紙筆 / 備忘錄 |
| 2. Claude Code 開發 | 15-30 min | Claude Code |
| 3. 部署 | 2-5 min | PowerShell |
| 4. 驗證網站 | 5-10 min | 無痕視窗 |
| 5. 驗證資料 | 3-5 min | Supabase Dashboard |

**總計：約 30-60 分鐘**完成一個小功能。

### 核心原則

> 每一步都有明確工具，不要跨界。「想清楚」省下「Claude Code 對話 30 分鐘」。

---

## 🌅 Part 3：從關機到開工 — 5 分鐘啟動流程

### Phase 1：開機準備

#### Step 1：打開 4 個工具

```
1. PowerShell      ← 執行者
2. 瀏覽器          ← 驗證者（建議 Edge 或 Chrome）
3. Claude Code     ← 思考者
4. VS Code         ← 看程式碼（可選）
```

#### Step 2：在 PowerShell 進專案

```powershell
cd C:\Users\88691\obstetrica-site
```

#### Step 3：拉最新 + 確認狀態

```powershell
# 拉遠端最新版本
git pull origin main

# 看工作區狀態
git status

# 看最近 5 個 commit
git log --oneline -5
```

**預期看到**：
```
On branch main
Your branch is up to date with 'origin/main'.
nothing to commit, working tree clean
```

✅ 看到這個 → 可以開工
⚠️ 有錯誤 → 看 [Part 9 救援指令](#-part-9卡住了常見救援指令)

---

## 💬 Part 4：跟 Claude Code 溝通的黃金公式

### 5 個必填欄位

| 欄位 | 解釋 |
|---|---|
| **【現況】** | 目前在做什麼，相關檔案 |
| **【目標】** | 我想達成什麼結果 |
| **【限制】** | 不能動到什麼、必須相容什麼 |
| **【驗收】** | 怎麼知道完成了（具體指標） |
| **【兩段式】** | 先規劃 → 等我同意 → 再 code，不要直接動手 |

### 完整範例

```
【現況】
obstetrica-admin.html 已有 3 個圖表，用 Chart.js + Supabase JS

【目標】
加橫向 bar chart 顯示 difficulty_ratings 平均星等 top 10

【限制】
不改 Supabase schema、不動 index.html、RLS 不變

【驗收】
admin 頁面看到圖表、空資料時顯示提示、不影響原功能

【請先規劃，不要動 code】
1. 讀檔分析現況
2. 提 2-3 個方案 + 優劣比較
3. 等我選方案後才開始 code
4. code 完不要 commit，我會用 .\deploy.ps1 自己部署
```

### 為什麼要「兩段式」？

- ❌ 直接讓 Claude Code 動手 → 它可能改錯方向，浪費時間
- ✅ 先規劃 → 你 review → 確定方向再 code → 一次到位

---

## 🚀 Part 5：一鍵部署 — deploy.ps1 全流程

### 9 個自動執行步驟

```
1. 環境檢查（git / gh / supabase CLI）
2. 偵測工作區變更
3. 顯示 diff 摘要
5. git add → commit → push
7. 偵測 SQL migration（如有）
8. 等待 GitHub Pages rebuild
9. 驗證網址 HTTP 200
```

### 4 個你需要回答的互動點

| 問題 | 答案 | 提示 |
|---|---|---|
| Step 4：確定要部署嗎？ | `y` / `N` | 看完 diff 摘要再答 |
| Commit message 類型 | `1`=feat / `2`=fix / `3`=自訂 | 新功能用 feat |
| Step 7：偵測到新 SQL | `y` / `N` | 改 schema 才答 y |
| Step 9：要打開瀏覽器？ | `y` / `N` | 建議 y 立即驗證 |

### 平均耗時

從跑指令到網站 HTTP 200，約 **2 分鐘**（GitHub Pages rebuild 約 50-90 秒）。

### 使用範例

```powershell
# 標準部署
cd C:\Users\88691\obstetrica-site
.\deploy.ps1

# 預演模式（看會做什麼但不真的執行）
.\deploy.ps1 -DryRun

# 雙擊版本（不用打字）
# 在檔案總管雙擊 deploy.bat
```

---

## 📊 Part 6：常見場景對照表

我想做某件事 → 該用哪個工具？

| 場景 | Claude Code | PowerShell | 瀏覽器 | Supabase |
|---|---|---|---|---|
| 改網頁文字 / 加按鈕 | 改 HTML | `.\deploy.ps1` | 無痕視窗看 | — |
| 加一個新統計圖表到後台 | 改 admin.html + 寫 JS | `.\deploy.ps1` | F12 看 Console | 驗證 query |
| 加新 DB 表 / 改 schema | 寫 .sql migration | `deploy.ps1` (Step 7) | — | Table Editor 看 |
| 看學生實際使用情況 | — | — | Dashboard | SQL Editor |
| 修 bug | 分析 → 改 → review | `.\deploy.ps1` | 重現確認 | 如有清資料 |
| Rollback 出意外的版本 | — | `git revert` + deploy | 確認回到舊版 | schema 另處理 |
| 看 commit 歷史 | — | `git log` | 或 GitHub | — |
| 加新環境變數 | — | 改 .env (本地) | — | Dashboard 設定 |
| 升級 Supabase schema | 寫 migration | `supabase db push` | — | SQL Editor 驗證 |

> **Tip**：85% 的工作會落在「Claude Code 寫 → PowerShell 部署 → 瀏覽器看」這個鐵三角。

---

## 🛡 Part 7：五大鐵律

### 1️⃣ 分工明確

- Claude Code 寫程式、PowerShell 部署
- ❌ 別叫 Claude Code 跑 `.\deploy.ps1`（會卡）
- ❌ 別在 PowerShell 寫長程式（用 Claude Code）

### 2️⃣ 永遠先看再做

- Claude Code 改完 → 你跑 `git diff` 看改動
- PowerShell 部署前 → 看「偵測到的變更」摘要
- Supabase 跑 SQL 前 → 看 SQL 內容

### 3️⃣ 用無痕視窗驗證

- 一般視窗會快取舊版本
- 無痕視窗看到的就是 GitHub Pages 上**最新版**
- 快捷鍵：**Ctrl + Shift + N**（Chrome / Edge）

### 4️⃣ 小步前進

- ❌ 一次叫 Claude Code 改 5 個功能 → 出錯難 debug
- ✅ 一次改 1 個功能 → 部署 → 驗證 → 再改下一個

### 5️⃣ 錯誤訊息先讀

- 紅字錯誤 90% 都直接告訴你問題
- 看不懂 → 截圖貼給 Claude / Claude Code

---

## 🌳 Part 8：困惑時的決策樹

```
我想做某件事，但不知道用哪個工具？
                  │
                  ▼
       ┌─── 是要寫程式碼嗎？ ──┐
       │  YES                   NO │
       ▼                            ▼
  🤖 Claude Code              是要執行已寫好的東西嗎？
                                    │
                              YES   │   NO
                              ▼     ▼
                         ⚡ PowerShell   是要看結果嗎？
                                          │
                                          ▼
                                    🌐 瀏覽器
                                    (網站) 或
                                    🗄 Supabase Dashboard
                                    (資料)
```

### 範例對照

| 你的想法 | 用哪個工具 |
|---|---|
| 「我想加個按鈕」 | 🤖 寫 → ⚡ 部署 → 🌐 看 |
| 「我想看學生答對率」 | 🗄 Supabase SQL Editor |
| 「我想升級到 v1.7」 | 🤖 規劃 → 🤖 寫 → ⚡ 部署 |
| 「我想 backup 資料」 | 🌐 Supabase Dashboard → Backups |
| 「我想看程式碼歷史」 | ⚡ git log，或 🌐 GitHub |
| 「我想改 SQL 表結構」 | 🤖 寫 migration → ⚡ deploy.ps1 |
| 「我想分享給學生」 | 🌐 把網址貼給他 |

---

## 🆘 Part 9：卡住了？常見救援指令

### 情境 1：git pull 報錯「changes would be overwritten」

```powershell
git stash             # 暫存本地修改
git pull origin main  # 再拉一次
git stash pop         # 把暫存的拿回來
```

> **原因**：本地有未 commit 修改 → 暫存後再拉

### 情境 2：Claude Code 改錯地方，還沒 commit 想還原

```powershell
git restore <檔案>    # 還原單一檔案
# 或還原全部：
git restore .
```

> **原因**：丟棄工作區的修改，回到上次 commit

### 情境 3：已 commit 但還沒 push，想撤銷

```powershell
git reset HEAD~1            # 保留檔案修改
git reset --hard HEAD~1     # 完全回退（謹慎用！）
```

> **原因**：回到前一個 commit 點

### 情境 4：已 push 出去發現有問題

```powershell
git revert <commit-hash>    # 開新 commit 抵銷
.\deploy.ps1                # 部署
```

> **原因**：新開一個 commit 抵銷前面的，最安全

### 情境 5：deploy.ps1 跑到一半卡住 / 失敗

```powershell
git push origin main         # 手動推
gh run list --limit 5        # 看 GitHub Actions
```

> **原因**：通常是網路或 Pages rebuild 延遲

### 情境 6：網頁看不到新功能

```
Ctrl+F5             # 強制重新整理
Ctrl+Shift+N        # 開無痕視窗
```

> **原因**：瀏覽器快取舊版本

### 情境 7：PowerShell 不能跑 .ps1

```powershell
# 一次性設定（只做一次）
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

> **原因**：PowerShell 預設禁止執行未簽章腳本

### 情境 8：忘記昨天做到哪

```powershell
git log --oneline -10                # 看 commit 歷史
git log --since="yesterday" --stat   # 看昨天改了什麼
gh issue list                        # 看你開的 issue
```

---

## 🎬 Part 10：完整劇本 — 加一個新功能

### 60 分鐘從關機到上線的旅程

```
0-5 min    Phase 1: 開機準備
           PowerShell 進專案 + git pull

5-15 min   Phase 2: 寫清需求
           紙筆 / 備忘錄寫：要做什麼 + 驗收

15-35 min  Phase 3: Claude Code 開發
           規劃 → 選方案 → 寫 → review

35-40 min  Phase 4: 部署
           .\deploy.ps1 互動式部署

40-50 min  Phase 5: 驗證
           無痕視窗 + Supabase 查資料

50-60 min  Phase 6: 收工
           確認 clean + 記錄 + 關閉
```

### 完成後成果

- ✅ GitHub repo 多一個 commit
- ✅ GitHub Pages 自動部署完成
- ✅ 新功能線上可用 (HTTP 200)
- ✅ Supabase 資料正確寫入 / 讀取
- 🎉 你的 Obstetrica 又進步一版

---

## 💡 Part 11：給未來自己的 4 個提醒

### 1️⃣ 保持自動化習慣

每次都用 `.\deploy.ps1`，不要手動 `git push`。
腳本會自動 review、防呆、驗證。

### 2️⃣ 敏感資訊永不 commit

❌ Supabase `service_role` key、密碼、API token 絕對不能進 GitHub repo（即使是 private）。

正確做法：
- 用 `.env` 檔案存敏感資訊
- `.env` 加進 `.gitignore`
- 線上服務用 Supabase Dashboard 設定 env vars

### 3️⃣ 優化前先收 feedback

邀請 5-10 個住院醫師試用，再決定優化方向。
別憑想像加功能。

### 4️⃣ 每改一次就 commit

小步前進、頻繁 commit，比一次大改安全 100 倍。
出錯時 `git revert` 一個 commit 就回去。

---

## ⚡ Part 12：快速指令參考

### PowerShell 常用指令

```powershell
# 進專案
cd C:\Users\88691\obstetrica-site

# 看狀態
git status
git log --oneline -5

# 同步
git pull origin main

# 部署
.\deploy.ps1                  # 標準部署
.\deploy.ps1 -DryRun          # 預演

# 看遠端 GitHub
gh repo view --web            # 開 repo 網頁
gh run list --limit 5         # 看 Actions
```

### Git 常用指令

```powershell
# 看改動
git diff                      # 工作區 vs 上次 commit
git diff --stat               # 改動統計
git diff <檔案>               # 單一檔案

# 還原
git restore <檔案>            # 還原單一檔案
git restore .                 # 還原全部
git stash                     # 暫存
git stash pop                 # 取回暫存

# 撤銷
git reset HEAD~1              # 撤銷上一個 commit (保留檔案)
git revert <hash>             # 安全撤銷（建議）

# 看歷史
git log --oneline -10         # 最近 10 個
git log --since="yesterday"   # 昨天的
git show <hash>               # 看特定 commit
```

### Supabase SQL 常用查詢

```sql
-- 看所有表
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public';

-- 看表的資料量
SELECT schemaname, tablename, n_live_tup AS rows
FROM pg_stat_user_tables
WHERE schemaname = 'public';

-- v1.6 新表的資料統計
SELECT
  (SELECT COUNT(*) FROM public.notes) AS notes,
  (SELECT COUNT(*) FROM public.bookmarks) AS bookmarks,
  (SELECT COUNT(*) FROM public.difficulty_ratings) AS ratings;

-- 最多人標難 Top 10
SELECT
  question_id,
  ROUND(AVG(stars)::numeric, 2) AS avg_difficulty,
  COUNT(*) AS rating_count
FROM public.difficulty_ratings
GROUP BY question_id
ORDER BY avg_difficulty DESC
LIMIT 10;

-- 最近 24 小時答題統計
SELECT COUNT(*) AS attempts_24h
FROM public.attempts
WHERE attempted_at > NOW() - INTERVAL '24 hours';
```

### 重要網址

```
線上網站：https://bluesunshine515-crypto.github.io/obstetrica/
GitHub：https://github.com/bluesunshine515-crypto/obstetrica
Supabase：https://supabase.com/dashboard
```

### 重要檔案路徑

```
專案根目錄：C:\Users\88691\obstetrica-site\
學生端 HTML：index.html
老師後台：obstetrica-admin.html
SQL migrations：supabase\migrations\
部署腳本：deploy.ps1 / deploy.bat
```

---

## 🏗 Part 13：版本設計決策

> 把「規格沒寫、但實作上有取捨」的設計決策記下來，避免未來重做或踩同樣坑。
> 每個版本的關鍵 design call 都應該在這裡留一段。

### v1.8 — 學生端 rotation 寫入 DB

#### 1️⃣ rotation 模式採用「每次答題建獨立 session」（策略 A）

**問題背景**：v1.7 之前 `obstetrica.html` 對 `exam_sessions` 只有 `loadSessionMap()` 一個 SELECT，全班學生所有 pretest attempts 塞同一筆共享 session，rotation_title 完全沒進 DB。本次 Step 2 不是「加一個欄位」這麼簡單，是**新增整個 session 建立流程**。

**兩個可選策略**：
- **A. 每次 rotation 答題都 INSERT 新 session**（採用）
- **B. 每個 (rotation_title_normalized, phase) 共用一筆 session**

**選 A 的理由**：
- 簡單：`startQuiz()` 一個 INSERT，不用先 query 再判斷
- 無 race condition：兩個學生同時點「開始」各自建自己的 row
- `attempts` 表本就有 `unique(student_id, session_id, question_id)` 約束，cohort 級分析靠 `GROUP BY rotation_title_normalized` 即可達成
- DB row 數線性成長但可控（7 學生 × 2 phase × N rotation/月，每月 ~28 rows）

#### 2️⃣ rotationName (client) ↔ rotation_title (DB) 命名 mapping

| 層 | 命名 |
|---|---|
| DOM id / client 變數 | `rotationName`（既有，不動） |
| DB 欄位 | `exam_sessions.rotation_title` |
| DB 欄位（trigger 算） | `rotation_title_normalized` |

INSERT 時 mapping：`rotation_title: rotationName`。`rotation_title_normalized` 由 DB trigger 自動算，前端不送。

⚠️ 後續若想把 client 變數改成 `rotationTitle` 對齊 DB：`rotationName` 散在 `quizState` / `record` / `localStorage.obg_history` / 多處 UI string，全 rename 風險高，不建議動。

#### 3️⃣ 新舊 attempts 在 view 層用 rotation_title_normalized 區分

v1.8 部署後 DB 會有兩種 session：
- **舊 session**（v1.7 之前共享的 2~3 筆）：`rotation_title IS NULL`
- **新 session**（v1.8 起每次 rotation 建立）：`rotation_title_normalized IS NOT NULL`

Step 3 寫新 view 時用 `WHERE rotation_title_normalized IS NOT NULL` 過濾掉舊資料。

**v1.7 既有 5 個 view 刻意不動**：admin Tab 1 的 `sessions_count` 預期會變大（從 2~3 → 每位學生實際答過的 rotation 次數），這是 feature not bug ─ session 粒度對齊「學習單元」更貼近教學語意。

#### 4️⃣ Step 3 — Rotation cohort 分析三支 view + cohort_code

**為何拆 3 支不包成 1 支**：
- `v_rotation_cohort_overview`（rotation 一 row）= admin 端做總覽表 + 排序
- `v_rotation_pre_post_pair`（學生×rotation 一 row）= 同學生跨梯次成長、個別前後測對比
- `v_rotation_topic_stats`（rotation × phase × category）= 弱項主題定位

拆 3 支邏輯各自單純、admin 端 section 可獨立 query、未來改一支不影響另兩支。一張大 view 把 3 個 group 維度塞同層級會難讀也難維護。

**RLS 必加 `WITH (security_invoker = true)`**（PG 15+ flag）：

PG 預設 view 用 view owner（在 Supabase = `postgres` superuser）權限跑底層查詢，會 bypass 所有 RLS。如果 view 給學生 query 用，會洩漏全班資料。`security_invoker = true` 讓 view 用 caller 權限跑，`attempts` / `students` 的 RLS 才會生效（學生只看自己、老師看全部）。

v1.7 既有 5 個 view 沒設這個 flag（admin 端只給老師用所以 bypass 不洩漏，但本身是隱性風險）。Step 3 view 設計時就考慮未來可能給學生端用，直接補上去。

⚠️ 改回 `security_invoker = false`（預設）會破壞 RLS，未經評估不要動。

**為何用 view 不用 materialized view**：
- 資料量極小：7 學員 × 月 2~3 rotation × 2 phase ≈ 月 ~28 row exam_sessions、~1500 attempts
- query 即時算夠快、不需 refresh 機制
- materialized view 一旦資料有更新延遲，老師上 dashboard 會看到舊資料的疑慮成本 > 算力節省

**cohort_code 抽取規則**：`substring(rotation_title_normalized from '\d{3,}')` 取第一段 ≥3 位連續數字。設計動機：
- `11501` / `11502` 是台灣民國年+月份習慣編碼，本來就是純數字
- 抽出來給 admin 端 `ORDER BY cohort_code` 用，non-numeric rotation（例 `rotation a`）抽出 NULL 自然排到尾
- 不在學生端輸入時 parse，是因為 normalize 規則想留在 DB 層集中管（client 不重複實作）

**過濾範圍**：
```sql
WHERE rotation_title_normalized IS NOT NULL
  AND phase IN ('pretest', 'posttest')
  -- v_rotation_topic_stats 另加 AND category IS NOT NULL
```

排除三類資料：
- v1.7 之前的舊共享 session（`rotation_title_normalized IS NULL`）
- `phase = 'practice'`（自由練習不算梯次評估）
- `category IS NULL` 的 attempts（只影響 topic_stats）

**配套：學生端 5 位數字限制**：

`obstetrica.html → index.html` 第 2435 行 rotation input 加 `pattern="\d{5}"` + `maxlength="5"` + `inputmode="numeric"`；`startQuiz()` 內加 `/^\d{5}$/.test()` JS 檢查（HTML pattern 不可靠，JS 才會真的擋）。

⚠️ 副作用：之前學生用過的非數字 rotation（例 `TEST_v18_Step2`）的舊 attempts 還在 DB，但 `cohort_code` 是 NULL，會在 view 內排到最後/被 filter 排除。歷史資料不會壞，但新規定下不能再產生非數字 rotation。

#### 5️⃣ exam_sessions INSERT 採 fail-open

INSERT 失敗時不擋學生答題，退回 v1.7 sharedMap 行為：

```js
// startQuiz 內：
try {
  const { data, error } = await supa.from('exam_sessions').insert({...}).select('id').single();
  if (error) console.warn('exam_sessions insert failed, fallback to sharedMap:', error);
  else rotationSessionId = data?.id || null;
} catch (e) { console.warn(...); }

// uploadAttempts 內：
const session_id = record.session_id || sessionMap[phase];
```

行為矩陣：
- INSERT 成功 → attempts 寫到新 session（rotation_title 落地）
- INSERT 失敗 → attempts 仍寫入但掛在舊共享 session（rotation_title 失蹤、題目不流失）
- 舊 localStorage record 重 upload → 走 fallback（向後相容，舊資料不會壞）

監控建議：上線後一段時間 grep client console 看 `exam_sessions insert failed` 出現頻率，>1% 就要改 fail-closed。

---

## 📝 版本歷史

| 版本 | 日期 | 更新內容 |
|---|---|---|
| v1.0 | 2026-05 | 初版：完整 SOP，含 12 個 Part |
| v1.1 | 2026-05 | 加 Part 13 版本設計決策（v1.8 rotation 落地） |
| v1.2 | 2026-05 | Part 13 補 v1.8 Step 3（3 支 rotation view + cohort_code + 學生端 5 位數字限制） |

---

## 🤝 維護建議

這份文件應該**隨工作流演進而更新**：

- 發現新的常見錯誤 → 加進 Part 9
- 學會新的快捷指令 → 加進 Part 12
- 工作流有大調整 → 更新對應 Part + 升版號
- 至少每 3 個月 review 一次內容是否還準確

---

> **記住核心**：
> Claude Code 動腦寫東西，
> PowerShell 動手做事，
> 瀏覽器看結果。
>
> 困惑時翻 [Part 8 決策樹](#-part-8困惑時的決策樹) 或 [Part 6 場景對照表](#-part-6常見場景對照表)。

— Built with Claude Code · TSGH OB/GYN
