<#
.SYNOPSIS
    ממיר תוכן שיעור (HTML) לקובץ Word מעוצב, בעברית RTL.

.DESCRIPTION
    עוטף את התוכן בעיצוב קבוע, פותח ב-Word ושומר כ-.docx אמיתי.
    דורש Microsoft Word מותקן (נבדק: Word 16).
    לא דורש Python ולא Node.js.

.EXAMPLE
    .\tools\lesson-to-docx.ps1 -ContentPath .\tmp\body.html `
        -Title "שיעור 1 — מי זה Claude" `
        -OutPath .\docs\learning\lessons\01-claude.docx
#>
param(
    [Parameter(Mandatory = $true)][string]$ContentPath,
    [Parameter(Mandatory = $true)][string]$Title,
    [Parameter(Mandatory = $true)][string]$OutPath
)

$ErrorActionPreference = 'Stop'

$ContentPath = [System.IO.Path]::GetFullPath($ContentPath)
$OutPath     = [System.IO.Path]::GetFullPath($OutPath)

if (-not (Test-Path $ContentPath)) { throw "לא נמצא קובץ תוכן: $ContentPath" }

$outDir = Split-Path $OutPath -Parent
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force $outDir | Out-Null }

$body = Get-Content -Path $ContentPath -Raw -Encoding UTF8

# ---------- העיצוב ----------
# Word מייבא CSS בסיסי בלבד: גופנים, צבעים, גבולות, רקעים, טבלאות.
# בכוונה אין כאן flexbox / grid / border-radius — Word מתעלם מהם.
$css = @'
body { font-family:"Segoe UI",Arial,sans-serif; font-size:11.5pt; color:#1a1a1a;
       line-height:1.7; direction:rtl; text-align:right; }
h1   { font-size:22pt; color:#0f2b46; border-bottom:2.5pt solid #c9a227;
       padding-bottom:6pt; margin-bottom:4pt; }
h2   { font-size:15pt; color:#0f2b46; margin-top:20pt; margin-bottom:6pt; }
h3   { font-size:12.5pt; color:#3d5a73; margin-top:14pt; margin-bottom:4pt; }
p    { margin:6pt 0; }
ul,ol { margin:6pt 24pt 6pt 0; }
li   { margin:3pt 0; }
table { border-collapse:collapse; width:100%; margin:10pt 0; font-size:10.5pt; }
th   { background:#0f2b46; color:#ffffff; border:0.75pt solid #0f2b46;
       padding:6pt 8pt; text-align:right; font-weight:bold; }
td   { border:0.75pt solid #c4cdd5; padding:6pt 8pt; text-align:right;
       vertical-align:top; }
tr.alt td { background:#f4f6f8; }
code { font-family:Consolas,"Courier New",monospace; font-size:10pt;
       background:#eef1f4; color:#0f2b46; padding:1pt 3pt; direction:ltr; }
pre  { font-family:Consolas,"Courier New",monospace; font-size:10pt;
       background:#f4f6f8; border-right:3pt solid #c9a227; padding:8pt 10pt;
       direction:ltr; text-align:left; }
.box { background:#fdf8e8; border:0.75pt solid #c9a227; padding:9pt 12pt;
       margin:10pt 0; }
.box-title { font-weight:bold; color:#8a6d1a; }
.task { background:#eaf3ea; border:0.75pt solid #4a7c4a; padding:9pt 12pt;
        margin:10pt 0; }
.task-title { font-weight:bold; color:#2f5d2f; }
.meta { color:#6b7a86; font-size:9.5pt; margin-top:0; }
.en  { direction:ltr; unicode-bidi:embed; }
'@

$htmlTemplate = @'
<!DOCTYPE html>
<html dir="rtl" lang="he"><head><meta charset="utf-8">
<title>__TITLE__</title><style>__CSS__</style></head>
<body dir="rtl">
__BODY__
</body></html>
'@

$html = $htmlTemplate.Replace('__TITLE__', $Title).Replace('__CSS__', $css).Replace('__BODY__', $body)

$tempHtml = Join-Path ([System.IO.Path]::GetTempPath()) ("lesson_" + [guid]::NewGuid().ToString('N') + ".html")
[System.IO.File]::WriteAllText($tempHtml, $html, (New-Object System.Text.UTF8Encoding $true))

$word = $null
$doc  = $null
try {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $word.DisplayAlerts = 0

    $doc = $word.Documents.Open($tempHtml, [ref]$false, [ref]$false)

    # שוליים נוחים לקריאה ולהדפסה
    $doc.PageSetup.TopMargin    = 56
    $doc.PageSetup.BottomMargin = 56
    $doc.PageSetup.LeftMargin   = 56
    $doc.PageSetup.RightMargin  = 56

    # 16 = wdFormatDocumentDefault (.docx)
    $doc.SaveAs2($OutPath, 16)
    $doc.Close(0)
    $doc = $null

    Write-Output "OK: $OutPath"
}
finally {
    if ($doc)  { try { $doc.Close(0) } catch {} }
    if ($word) { try { $word.Quit() } catch {} ;
                 [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) }
    if (Test-Path $tempHtml) { Remove-Item $tempHtml -Force -ErrorAction SilentlyContinue }
}
