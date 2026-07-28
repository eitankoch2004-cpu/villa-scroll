# preview.ps1 - שרת תצוגה מקומית לאתר Glowora
#
# למה זה קיים:
#   כדי לראות שינוי באתר מיד, בלי להעלות ל-GitHub ובלי לחכות.
#   כולל צפייה מהטלפון, כל עוד הטלפון מחובר לאותו Wi-Fi.
#
# איך מריצים:
#   .\tools\preview.ps1
#   לעצירה: Ctrl+C
#
# אין צורך ב-Python או Node.js. רק PowerShell שכבר מותקן ב-Windows.

param(
    [int]$Port = 8080
)

$ErrorActionPreference = 'Stop'

# בלי זה העברית בחלון הטרמינל יוצאת ג'יבריש
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch { }

$root = Split-Path -Parent $PSScriptRoot

$mime = @{
    '.html' = 'text/html; charset=utf-8'
    '.htm'  = 'text/html; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.js'   = 'application/javascript; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'
    '.svg'  = 'image/svg+xml'
    '.webp' = 'image/webp'
    '.jpg'  = 'image/jpeg'
    '.jpeg' = 'image/jpeg'
    '.png'  = 'image/png'
    '.gif'  = 'image/gif'
    '.ico'  = 'image/x-icon'
    '.mp4'  = 'video/mp4'
    '.webm' = 'video/webm'
    '.woff' = 'font/woff'
    '.woff2'= 'font/woff2'
    '.txt'  = 'text/plain; charset=utf-8'
}

# מוצא את כתובת ה-Wi-Fi של המחשב, כדי שאפשר יהיה להיכנס מהטלפון
$lanIp = $null
try {
    $lanIp = (Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.InterfaceAlias -notmatch 'Loopback|vEthernet|WSL' -and
            $_.IPAddress -notmatch '^169\.254'
        } |
        Select-Object -First 1).IPAddress
} catch { }

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $Port)
try {
    $listener.Start()
} catch {
    Write-Host ""
    Write-Host "  לא הצלחתי לפתוח את הפורט $Port." -ForegroundColor Red
    Write-Host "  כנראה השרת כבר רץ בחלון אחר. סגור אותו, או הרץ:" -ForegroundColor Yellow
    Write-Host "     .\tools\preview.ps1 -Port 8081" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "  ================================================" -ForegroundColor DarkGray
Write-Host "   Glowora - שרת תצוגה מקומית" -ForegroundColor Cyan
Write-Host "  ================================================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "   במחשב:  " -NoNewline; Write-Host "http://localhost:$Port" -ForegroundColor Green
if ($lanIp) {
    Write-Host "   בטלפון: " -NoNewline; Write-Host "http://${lanIp}:$Port" -ForegroundColor Green
    Write-Host "            (הטלפון חייב להיות על אותו Wi-Fi)" -ForegroundColor DarkGray
}
Write-Host ""
Write-Host "   תיקייה: $root" -ForegroundColor DarkGray
Write-Host "   לעצירה: Ctrl+C" -ForegroundColor DarkGray
Write-Host ""

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $client.ReceiveTimeout = 3000
            $client.SendTimeout    = 15000
            $stream = $client.GetStream()

            # קריאת שורת הבקשה
            $buffer = New-Object byte[] 8192
            $read = $stream.Read($buffer, 0, $buffer.Length)
            if ($read -le 0) { continue }
            $request = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $read)
            $firstLine = ($request -split "`r?`n")[0]
            $parts = $firstLine -split ' '
            if ($parts.Count -lt 2) { continue }

            $urlPath = $parts[1]
            $urlPath = ($urlPath -split '\?')[0]      # מסיר query string
            $urlPath = [System.Uri]::UnescapeDataString($urlPath)
            if ($urlPath -eq '/') { $urlPath = '/index.html' }

            # מניעת יציאה מהתיקייה (directory traversal)
            $relative = $urlPath.TrimStart('/').Replace('/', '\')
            $fullPath = Join-Path $root $relative
            $resolved = $null
            try { $resolved = (Resolve-Path -LiteralPath $fullPath -ErrorAction Stop).Path } catch { }

            $status = '404 Not Found'
            $body   = $null
            $type   = 'text/html; charset=utf-8'

            if ($resolved -and $resolved.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
                if (Test-Path -LiteralPath $resolved -PathType Container) {
                    $indexFile = Join-Path $resolved 'index.html'
                    if (Test-Path -LiteralPath $indexFile) { $resolved = $indexFile }
                }
                if (Test-Path -LiteralPath $resolved -PathType Leaf) {
                    $status = '200 OK'
                    $body   = [System.IO.File]::ReadAllBytes($resolved)
                    $ext    = [System.IO.Path]::GetExtension($resolved).ToLower()
                    if ($mime.ContainsKey($ext)) { $type = $mime[$ext] }
                    else { $type = 'application/octet-stream' }
                }
            }

            if ($null -eq $body) {
                $html = "<!doctype html><meta charset=utf-8>" +
                        "<body style='background:#0B0E11;color:#D4DCE2;font-family:sans-serif;padding:60px;text-align:center'>" +
                        "<h1 style='color:#C08A3E'>404</h1><p>הקובץ לא נמצא:</p><code>$urlPath</code></body>"
                $body = [System.Text.Encoding]::UTF8.GetBytes($html)
                Write-Host "   404  $urlPath" -ForegroundColor DarkRed
            }

            $headers = "HTTP/1.1 $status`r`n" +
                       "Content-Type: $type`r`n" +
                       "Content-Length: $($body.Length)`r`n" +
                       "Cache-Control: no-store`r`n" +
                       "Connection: close`r`n`r`n"
            $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($headers)

            $stream.Write($headerBytes, 0, $headerBytes.Length)
            $stream.Write($body, 0, $body.Length)
            $stream.Flush()
        } catch {
            # בקשה בודדת נכשלה - ממשיכים לבקשה הבאה
        } finally {
            if ($client) { $client.Close() }
        }
    }
} finally {
    $listener.Stop()
    Write-Host ""
    Write-Host "   השרת נעצר." -ForegroundColor DarkGray
    Write-Host ""
}
