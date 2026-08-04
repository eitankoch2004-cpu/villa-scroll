# frames.ps1 — הופך סרטון לרצף פריימים לאתר
#
# מה זה עושה:
#   לוקח קובץ סרטון, חותך אותו למספר קבוע של תמונות,
#   ומייצר שתי תיקיות: אחת לדסקטופ ואחת למובייל.
#   הכל בפורמט WebP, בשמות של 4 ספרות — בדיוק כמו שהאתר מצפה.
#
# איך מריצים:
#   .\tools\frames.ps1 -Video "C:\Users\User\Downloads\villa.mp4" -Name lobby
#
# התוצאה:
#   frames-lobby\0001.webp …   (דסקטופ, 1920x1080)
#   frames-lobby-m\0001.webp … (מובייל,  880x1100)

param(
    [Parameter(Mandatory=$true)][string]$Video,
    [Parameter(Mandatory=$true)][string]$Name,
    [int]$Count = 0,          # 0 = לגזור מהסרטון: כל פריים שקיים בו, בלי לזרוק תנועה
    [int]$Quality = 66,
    [ValidateSet('none','dusk','night')][string]$Grade = 'none',
    [double]$Start = 0,       # שנייה שממנה מתחילים לחתוך
    [double]$Length = 0       # כמה שניות לקחת. 0 = עד הסוף
)

# --- דירוגי צבע -------------------------------------------------------------
# "יום ללילה": מחשיך, מקרר את הצללים לכחול, ומחשיך את הפינות.
# עובד רק על צילום בלי שמיים שרופים בפריים.
$GRADES = @{
    'none'  = ''
    'dusk'  = 'eq=brightness=-0.04:contrast=1.08:saturation=0.72,colorbalance=rs=-0.04:bs=0.11:rm=-0.03:bm=0.08:rh=-0.01:bh=0.04,vignette=PI/7'
    'night' = 'eq=brightness=-0.30:contrast=1.28:saturation=0.38,colorbalance=rs=-0.12:bs=0.26:rm=-0.09:bm=0.18:rh=-0.06:bh=0.09,vignette=PI/3.5'
}

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$root = Split-Path -Parent $PSScriptRoot

# --- מציאת ffmpeg -----------------------------------------------------------
# אחרי התקנה ב-winget, חלון PowerShell ישן עדיין לא מכיר את הפקודה.
# לכן מחפשים גם בתיקיית ההתקנה.
function Find-Tool([string]$exe) {
    $cmd = Get-Command $exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $hit = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "$exe.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($hit) { return $hit.FullName }
    return $null
}

$ffmpeg  = Find-Tool ffmpeg
$ffprobe = Find-Tool ffprobe

if (-not $ffmpeg -or -not $ffprobe) {
    Write-Host ""
    Write-Host "  לא מצאתי את ffmpeg." -ForegroundColor Red
    Write-Host "  להתקנה:  winget install --id Gyan.FFmpeg --exact" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

if (-not (Test-Path -LiteralPath $Video)) {
    Write-Host ""
    Write-Host "  לא מצאתי את הסרטון: $Video" -ForegroundColor Red
    Write-Host "  טיפ: גרור את הקובץ לחלון הטרמינל כדי לקבל את הנתיב המדויק." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# --- אורך הסרטון, כדי לפרוס את הפריימים באופן אחיד -------------------------
$duration = [double](& $ffprobe -v error -show_entries format=duration -of csv=p=0 $Video)
if ($duration -le 0) {
    Write-Host "  לא הצלחתי לקרוא את אורך הסרטון." -ForegroundColor Red
    exit 1
}

# קצב הפריימים של המקור, כדי לחשב כמה פריימים יש בקטע שנבחר
$rate = & $ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 $Video
$srcFps = [double]($rate.Split('/')[0]) / [double]($rate.Split('/')[1])

# אם ביקשו קטע — האורך הרלוונטי הוא אורך הקטע, לא אורך הסרטון
if ($Length -gt 0) {
    $duration = [math]::Min($Length, $duration - $Start)
}
$native = [int][math]::Floor($duration * $srcFps)

if ($Count -le 0) {
    $Count = $native
    Write-Host "   (לא צוין מספר פריימים — לוקח את כל מה שיש בסרטון)" -ForegroundColor DarkGray
}
elseif ($Count -gt $native) {
    Write-Host "   ⚠ ביקשת $Count אבל בסרטון יש רק $native. יורד ל-$native." -ForegroundColor Yellow
    Write-Host "     מעל זה רק משכפל תמונות ומוסיף משקל בלי תנועה." -ForegroundColor DarkGray
    $Count = $native
}
elseif ($Count -lt $native) {
    $lost = [math]::Round((1 - $Count / $native) * 100)
    Write-Host "   ⚠ בסרטון יש $native פריימים. ב-$Count אתה מוותר על $lost% מהתנועה." -ForegroundColor Yellow
}

$fps = [math]::Round($Count / $duration, 6)

Write-Host ""
Write-Host "  ================================================" -ForegroundColor DarkGray
Write-Host "   סרטון -> פריימים" -ForegroundColor Cyan
Write-Host "  ================================================" -ForegroundColor DarkGray
Write-Host "   מקור:  $(Split-Path $Video -Leaf)"
Write-Host "   אורך:  $([math]::Round($duration,2)) שניות"
Write-Host "   יעד:   $Count פריימים  (קצב $fps לשנייה)"
Write-Host ""

# --- חילוץ ------------------------------------------------------------------
# force_original_aspect_ratio=increase + crop = "למלא ואז לחתוך",
# כדי שלא יופיעו פסים שחורים ביחס אחר.
# הרוחב נבחר לפי זיכרון, לא לפי "כמה שיותר גדול".
# פריים דסקטופ ב-1920x1080 עולה 8.3MB בזיכרון; ב-1600x900 רק 5.8MB.
# ההפרש הזה הוא ההבדל בין דפדפן חלק לדפדפן תקוע.
$jobs = @(
    @{ Dir = "frames-$Name";    W = 1600; H = 900;  Label = 'דסקטופ' },
    @{ Dir = "frames-$Name-m";  W = 880;  H = 1100; Label = 'מובייל ' }
)

foreach ($j in $jobs) {
    $out = Join-Path $root $j.Dir
    if (Test-Path $out) {
        Write-Host "   מנקה תיקייה קיימת: $($j.Dir)" -ForegroundColor DarkYellow
        Get-ChildItem "$out\*.webp" -ErrorAction SilentlyContinue | Remove-Item -Force
    } else {
        New-Item -ItemType Directory -Path $out | Out-Null
    }

    $vf = "fps=$fps,scale=$($j.W):$($j.H):force_original_aspect_ratio=increase,crop=$($j.W):$($j.H)"
    if ($GRADES[$Grade]) { $vf = $vf + ',' + $GRADES[$Grade] }

    Write-Host "   מייצר $($j.Label) ..." -NoNewline
    $args = @('-hide_banner','-loglevel','error','-y')
    if ($Start -gt 0) { $args += @('-ss', $Start) }
    $args += @('-i', $Video)
    if ($Length -gt 0) { $args += @('-t', $Length) }
    $args += @('-vf', $vf, '-frames:v', $Count,
               '-c:v','libwebp','-quality',$Quality,'-compression_level','6',
               (Join-Path $out '%04d.webp'))
    & $ffmpeg @args

    $made = @(Get-ChildItem "$out\*.webp" -ErrorAction SilentlyContinue)
    $mb   = [math]::Round((($made | Measure-Object Length -Sum).Sum / 1MB), 2)
    Write-Host "  $($made.Count) פריימים, $mb MB" -ForegroundColor Green
}

# --- סיכום ------------------------------------------------------------------
$final = @(Get-ChildItem (Join-Path $root "frames-$Name\*.webp") -ErrorAction SilentlyContinue).Count

Write-Host ""
Write-Host "  ================================================" -ForegroundColor DarkGray
Write-Host "   הצעד הבא — לעדכן את data.js:" -ForegroundColor Cyan
Write-Host ""
Write-Host "   { dir:'frames-$Name', dirM:'frames-$Name-m', count:$final," -ForegroundColor White
Write-Host "     label:'...', note:'...' }" -ForegroundColor White
Write-Host ""
Write-Host "   או פשוט תגיד לי \"הפריימים מוכנים\" ואני אעדכן." -ForegroundColor DarkGray
Write-Host ""
