# ============================================================
#  Obstetrica 自動化部署腳本
#  使用：.\deploy.ps1            正式部署
#        .\deploy.ps1 -DryRun    模擬執行（不實際操作）
# ============================================================

[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$startTime = Get-Date

# ---------- 設定 ----------
$ProjectRoot = 'C:\Users\88691\obstetrica-site'
$SiteUrl     = 'https://bluesunshine515-crypto.github.io/obstetrica/'
$RepoOwner   = 'bluesunshine515-crypto'
$RepoName    = 'obstetrica'
$Branch      = 'main'
$SensitivePatterns = @('\.env', 'config\.toml', 'auth', 'secret', 'credential', 'service[-_]?role')

# ---------- 工具函式 ----------
function Write-Title($text) {
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "  $text" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
}

function Write-Step($text) {
    Write-Host ""
    Write-Host "▶ $text" -ForegroundColor Yellow
}

function Write-Ok($text)    { Write-Host "  ✓ $text" -ForegroundColor Green }
function Write-Warn($text)  { Write-Host "  ⚠ $text" -ForegroundColor Yellow }
function Write-Err($text)   { Write-Host "  ✗ $text" -ForegroundColor Red }
function Write-Info($text)  { Write-Host "  • $text" -ForegroundColor Gray }

function Stop-WithError($msg, $rescue) {
    Write-Host ""
    Write-Host "═══════════ 部署失敗 ═══════════" -ForegroundColor Red
    Write-Err $msg
    if ($rescue) {
        Write-Host ""
        Write-Host "💡 建議救援指令：" -ForegroundColor Magenta
        Write-Host "   $rescue" -ForegroundColor White
    }
    Write-Host ""
    exit 1
}

function Confirm-Action($question, $defaultYes = $false) {
    $hint = if ($defaultYes) { '(Y/n)' } else { '(y/N)' }
    $resp = Read-Host "$question $hint"
    if ([string]::IsNullOrWhiteSpace($resp)) {
        return $defaultYes
    }
    return $resp.Trim().ToLower() -eq 'y'
}

function Test-Command($name) {
    $null = Get-Command $name -ErrorAction SilentlyContinue
    return $?
}

# ============================================================
#  Step 0：標題
# ============================================================
Clear-Host
Write-Host ""
Write-Host "  🚀 Obstetrica 自動部署" -ForegroundColor Cyan
Write-Host "  ───────────────────────" -ForegroundColor DarkCyan
Write-Host "  時間：$($startTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
if ($DryRun) {
    Write-Host "  模式：🧪 DRY RUN（不會實際變更任何東西）" -ForegroundColor Magenta
}

# ============================================================
#  Step 1：環境檢查
# ============================================================
Write-Step "Step 1：環境檢查"

if (-not (Test-Path $ProjectRoot)) {
    Stop-WithError "找不到專案資料夾：$ProjectRoot" "請確認路徑是否正確"
}
Set-Location $ProjectRoot
Write-Ok "工作目錄：$ProjectRoot"

if (-not (Test-Path '.git')) {
    Stop-WithError "目前資料夾不是 git repo" "git init 然後 git remote add origin <URL>"
}
Write-Ok "Git repo 存在"

foreach ($cmd in @('git', 'gh')) {
    if (-not (Test-Command $cmd)) {
        Stop-WithError "找不到指令：$cmd" "請先安裝 $cmd"
    }
    Write-Ok "$cmd 已安裝"
}

# supabase 是 optional，但若有 migrations 才會用到
$hasSupabaseCli = Test-Command 'supabase'
if ($hasSupabaseCli) {
    Write-Ok "supabase CLI 已安裝"
} else {
    Write-Warn "supabase CLI 未安裝（若有 SQL migration 會跳過自動 push）"
}

# gh auth 檢查
$ghAuthOutput = & gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Stop-WithError "gh 未登入或 token 失效" "gh auth login"
}
Write-Ok "gh CLI 已登入"

# ============================================================
#  Step 2：當前狀態
# ============================================================
Write-Step "Step 2：檢查工作區狀態"

$statusLines = git status --porcelain
if (-not $statusLines) {
    Write-Host ""
    Write-Host "  ✓ 工作區乾淨，沒有東西要部署" -ForegroundColor Green
    Write-Host ""
    exit 0
}

$changedFiles = $statusLines | ForEach-Object {
    $line = $_
    [PSCustomObject]@{
        Status = $line.Substring(0, 2).Trim()
        Path   = $line.Substring(3).Trim('"')
    }
}

Write-Info "變更檔案數：$($changedFiles.Count)"
foreach ($f in $changedFiles) {
    $color = switch -Regex ($f.Status) {
        '^A'  { 'Green' }
        '^M'  { 'Yellow' }
        '^D'  { 'Red' }
        '\?\?' { 'Gray' }
        default { 'White' }
    }
    Write-Host ("    [{0}] {1}" -f $f.Status.PadRight(2), $f.Path) -ForegroundColor $color
}

# ============================================================
#  Step 3：改動 Review
# ============================================================
Write-Step "Step 3：改動 Review"

Write-Host ""
Write-Host "  --- git diff --stat ---" -ForegroundColor DarkGray
git diff --stat HEAD
Write-Host ""

# .html 版本號變化
$htmlFiles = $changedFiles | Where-Object { $_.Path -match '\.html$' -and $_.Status -ne 'D' }
foreach ($h in $htmlFiles) {
    Write-Info "HTML：$($h.Path) — 偵測版本號變化"
    $diffOut = git diff HEAD -- $h.Path 2>$null | Select-String -Pattern '(?i)version|v\d+\.\d+'
    if ($diffOut) {
        foreach ($line in $diffOut | Select-Object -First 6) {
            Write-Host "      $line" -ForegroundColor DarkYellow
        }
    } else {
        Write-Host "      （未偵測到版本號變化）" -ForegroundColor DarkGray
    }
}

# .sql 檔顯示前 20 行
$sqlFiles = $changedFiles | Where-Object { $_.Path -match '\.sql$' -and $_.Status -ne 'D' }
foreach ($s in $sqlFiles) {
    Write-Info "SQL：$($s.Path)（前 20 行）"
    if (Test-Path $s.Path) {
        Get-Content -LiteralPath $s.Path -TotalCount 20 | ForEach-Object {
            Write-Host "      $_" -ForegroundColor DarkCyan
        }
    }
}

# 敏感檔案警告
$sensitiveHits = @()
foreach ($f in $changedFiles) {
    foreach ($pattern in $SensitivePatterns) {
        if ($f.Path -match $pattern) {
            $sensitiveHits += $f.Path
            break
        }
    }
}
if ($sensitiveHits.Count -gt 0) {
    Write-Host ""
    Write-Warn "⚠️ 警告：偵測到敏感檔案變更"
    foreach ($s in $sensitiveHits) {
        Write-Host "      → $s" -ForegroundColor Red
    }
    Write-Host "      請務必確認沒有把 secrets / token commit 進去！" -ForegroundColor Red
}

# ============================================================
#  Step 4：確認對話
# ============================================================
Write-Step "Step 4：確認部署"
if (-not (Confirm-Action "確定要部署嗎？" $false)) {
    Write-Host ""
    Write-Host "  已取消部署。" -ForegroundColor Gray
    exit 0
}

# ============================================================
#  Step 5：Commit 訊息
# ============================================================
Write-Step "Step 5：撰寫 Commit 訊息"

Write-Host "  選擇格式：" -ForegroundColor White
Write-Host "    [1] feat: <描述>" -ForegroundColor Gray
Write-Host "    [2] fix:  <描述>" -ForegroundColor Gray
Write-Host "    [3] 自訂完整訊息" -ForegroundColor Gray
$choice = Read-Host "  請輸入 1 / 2 / 3 (預設 1)"
if ([string]::IsNullOrWhiteSpace($choice)) { $choice = '1' }

switch ($choice.Trim()) {
    '1' {
        $desc = Read-Host "  描述（中英文皆可）"
        $commitMsg = "feat: $desc"
    }
    '2' {
        $desc = Read-Host "  描述（中英文皆可）"
        $commitMsg = "fix: $desc"
    }
    '3' {
        $commitMsg = Read-Host "  完整 commit 訊息"
    }
    default {
        $desc = Read-Host "  描述"
        $commitMsg = "feat: $desc"
    }
}

if ([string]::IsNullOrWhiteSpace($commitMsg) -or $commitMsg -match '^(feat|fix):\s*$') {
    Stop-WithError "Commit 訊息不能空白" "重新執行 .\deploy.ps1"
}

$timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm')
$fullMsg = "$commitMsg`n`nDeployed via deploy.ps1 at $timestamp"

Write-Host ""
Write-Host "  最終 commit message：" -ForegroundColor White
Write-Host "  ┌────────────────────────────" -ForegroundColor DarkGray
$fullMsg -split "`n" | ForEach-Object { Write-Host "  │ $_" -ForegroundColor Cyan }
Write-Host "  └────────────────────────────" -ForegroundColor DarkGray

# ============================================================
#  Step 6：Git 操作
# ============================================================
Write-Step "Step 6：Git add / commit / push"

if ($DryRun) {
    Write-Warn "[DryRun] 跳過：git add -A"
    Write-Warn "[DryRun] 跳過：git commit"
    Write-Warn "[DryRun] 跳過：git push origin $Branch"
    $commitHash = '(dry-run-no-hash)'
} else {
    & git add -A
    if ($LASTEXITCODE -ne 0) {
        Stop-WithError "git add 失敗" "git status 看狀態"
    }
    Write-Ok "git add -A 完成"

    & git commit -m $fullMsg
    if ($LASTEXITCODE -ne 0) {
        Stop-WithError "git commit 失敗" "git status / git diff --cached 檢查"
    }
    $commitHash = (git rev-parse --short HEAD).Trim()
    Write-Ok "Commit 建立：$commitHash"

    Write-Info "推送到 origin/$Branch ..."
    & git push origin $Branch
    if ($LASTEXITCODE -ne 0) {
        Stop-WithError "git push 失敗" "git pull --rebase origin $Branch 後再試一次（不要直接 force push）"
    }
    Write-Ok "Push 完成"
}

# ============================================================
#  Step 7：Supabase migration
# ============================================================
Write-Step "Step 7：Supabase migration 偵測"

$migrationDir = Join-Path $ProjectRoot 'supabase\migrations'
$migrationRan = $false
$migrationResult = '未執行'

if (Test-Path $migrationDir) {
    $newSqlInCommit = $changedFiles | Where-Object {
        $_.Path -match '^supabase/migrations/.*\.sql$' -and $_.Status -match 'A|\?\?|M'
    }

    if ($newSqlInCommit.Count -gt 0) {
        Write-Info "偵測到 migration 變更："
        $newSqlInCommit | ForEach-Object { Write-Host "      → $($_.Path)" -ForegroundColor Yellow }

        if (-not $hasSupabaseCli) {
            Write-Warn "supabase CLI 未安裝，請手動執行：supabase db push"
            $migrationResult = '需手動執行（CLI 未安裝）'
        } elseif (Confirm-Action "  要執行 supabase db push 嗎？" $false) {
            if ($DryRun) {
                Write-Warn "[DryRun] 跳過：supabase db push"
                $migrationResult = 'DryRun 跳過'
            } else {
                & supabase db push
                if ($LASTEXITCODE -eq 0) {
                    Write-Ok "supabase db push 成功"
                    $migrationRan = $true
                    $migrationResult = '✅ 成功'
                } else {
                    Write-Err "supabase db push 失敗"
                    $migrationResult = '❌ 失敗'
                    Write-Host "  💡 救援：supabase db push --debug 看詳細錯誤" -ForegroundColor Magenta
                }
            }
        } else {
            Write-Info "已跳過 migration"
            $migrationResult = '使用者跳過'
        }
    } else {
        Write-Info "本次無 SQL migration 變更"
        $migrationResult = '本次無變更'
    }
} else {
    Write-Info "無 supabase/migrations 目錄"
}

# ============================================================
#  Step 8：等待 GitHub Pages
# ============================================================
Write-Step "Step 8：等待 GitHub Pages 部署"

if ($DryRun) {
    Write-Warn "[DryRun] 跳過：監聽 GitHub Pages"
} else {
    Write-Info "查詢最新 workflow run..."
    Start-Sleep -Seconds 3

    $maxWaitSec = 180
    $intervalSec = 10
    $elapsed = 0
    $spinChars = @('⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏')
    $spinIdx = 0
    $finalStatus = $null

    while ($elapsed -lt $maxWaitSec) {
        $runJson = & gh run list --limit 1 --json databaseId,status,conclusion,name,headSha 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $runJson) {
            Write-Warn "無法查詢 workflow（可能 GitHub Pages 用 branch 直接部署，沒有 Actions）"
            $finalStatus = 'no-workflow'
            break
        }

        $runs = $runJson | ConvertFrom-Json
        if ($runs.Count -eq 0) {
            Write-Warn "查無任何 workflow run"
            $finalStatus = 'no-runs'
            break
        }

        $run = $runs[0]
        $spin = $spinChars[$spinIdx % $spinChars.Count]
        $spinIdx++

        Write-Host ("`r  $spin 等待中... 狀態：{0}  耗時：{1}s  ({2})" -f `
            $run.status, $elapsed, $run.name) -NoNewline -ForegroundColor Yellow

        if ($run.status -eq 'completed') {
            Write-Host ""
            $finalStatus = $run.conclusion
            break
        }

        Start-Sleep -Seconds $intervalSec
        $elapsed += $intervalSec
    }

    Write-Host ""
    if ($finalStatus -eq 'success') {
        Write-Ok "✅ Pages 已部署"
    } elseif ($finalStatus -in @('no-workflow','no-runs')) {
        Write-Info "未使用 GitHub Actions（branch deploy mode），跳過監聽"
    } elseif ($null -eq $finalStatus) {
        Write-Warn "等待超過 $maxWaitSec 秒仍未完成，請到 GitHub 上手動確認"
    } else {
        Write-Warn "Workflow 結束狀態：$finalStatus"
    }
}

# ============================================================
#  Step 9：驗證網址
# ============================================================
Write-Step "Step 9：驗證線上網站"

$siteOk = $false
if ($DryRun) {
    Write-Warn "[DryRun] 跳過：HTTP 檢查"
} else {
    try {
        Start-Sleep -Seconds 5
        $resp = Invoke-WebRequest -Uri $SiteUrl -UseBasicParsing -TimeoutSec 30
        if ($resp.StatusCode -eq 200) {
            Write-Ok "✅ 網站運作正常（HTTP 200）"
            $siteOk = $true
        } else {
            Write-Warn "HTTP 狀態：$($resp.StatusCode)"
        }
    } catch {
        Write-Warn "無法連線到網站：$($_.Exception.Message)"
        Write-Info "可能 Pages 還在 propagate，稍後手動開啟："
        Write-Info "  $SiteUrl"
    }
}

# ============================================================
#  Step 10：完成總結
# ============================================================
$endTime = Get-Date
$duration = $endTime - $startTime

Write-Host ""
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║         🎉  部署完成 ！                  ║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  📌 Commit ：$commitHash" -ForegroundColor White
Write-Host "  📝 訊息   ：$commitMsg" -ForegroundColor White
Write-Host "  🌐 網址   ：$SiteUrl" -ForegroundColor White
Write-Host "  🗄️  Migration：$migrationResult" -ForegroundColor White
Write-Host ("  ⏱  總耗時 ：{0:N0} 秒" -f $duration.TotalSeconds) -ForegroundColor White
if ($DryRun) {
    Write-Host "  🧪 模式   ：DRY RUN（沒有實際變更）" -ForegroundColor Magenta
}
Write-Host ""

if (-not $DryRun) {
    if (Confirm-Action "要打開瀏覽器測試嗎？" $false) {
        $edge = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
        $chrome = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
        if (Test-Path $edge) {
            Start-Process $edge -ArgumentList "-inprivate", $SiteUrl
            Write-Ok "已開啟 Edge 無痕視窗"
        } elseif (Test-Path $chrome) {
            Start-Process $chrome -ArgumentList "--incognito", $SiteUrl
            Write-Ok "已開啟 Chrome 無痕視窗"
        } else {
            Start-Process $SiteUrl
            Write-Ok "已用預設瀏覽器開啟"
        }
    }
}

Write-Host ""
exit 0
