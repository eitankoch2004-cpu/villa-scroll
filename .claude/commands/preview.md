---
description: מפעיל שרת תצוגה מקומית כדי לראות את האתר במחשב ובטלפון
allowed-tools: PowerShell, Bash, Read
---

הפעל את שרת התצוגה המקומית של הפרויקט.

## מה לעשות

1. בדוק אם השרת כבר רץ:
   ```
   Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*preview.ps1*' }
   ```
   אם הוא כבר רץ — אל תפעיל עוד אחד. פשוט הצג לאיתן את הכתובות.

2. אם הוא לא רץ, הפעל אותו ברקע:
   ```
   Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','tools\preview.ps1' -WindowStyle Hidden
   ```

3. חכה 2 שניות ואמת שהוא באמת עונה:
   ```
   Invoke-WebRequest 'http://localhost:8080/' -UseBasicParsing -TimeoutSec 10
   ```
   **אל תגיד שהשרת עובד לפני שהבדיקה הזו החזירה 200.**

4. מצא את כתובת ה-Wi-Fi הנוכחית (היא משתנה בין רשתות):
   ```
   Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'Loopback|vEthernet|WSL' -and $_.IPAddress -notmatch '^169\.254' }
   ```

## מה להציג לאיתן

בעברית, קצר:

- **במחשב:** `http://localhost:8080`
- **בטלפון:** `http://<כתובת ה-Wi-Fi>:8080` — והזכר לו שהטלפון חייב להיות על אותו Wi-Fi
- לעצירה: לסגור את החלון, או לבקש ממני "עצור את השרת"

אם Windows מציג חלון של חומת אש בפעם הראשונה — תגיד לו ללחוץ **Allow access**
ולוודא ש-**Private networks** מסומן. בלי זה הטלפון לא יצליח להתחבר.

## הערה חשובה
השרת מגיש קבצים מהדיסק בכל רענון, עם `Cache-Control: no-store`.
כלומר: אחרי כל שינוי בקוד — מספיק לרענן את הדף. אין צורך להפעיל מחדש.
