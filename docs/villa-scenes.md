# תסריט הווילה — Glowora

ארבע סצנות. **חייבות להיראות כמו אותו בית**, ולכן כל פרומפט נבנה
על אותו "תנ"ך סגנון" ומשתנה רק בחדר ובמנורה.

---

## 🎨 תנ״ך הסגנון — נכנס בכל פרומפט, בלי שינוי

```
Modern exotic luxury villa. Materials: warm travertine stone, dark walnut
wood, floor-to-ceiling glass, brushed black metal. Tropical garden and
infinity pool visible through the glass. Golden hour, warm 3000K interior
lighting, soft shadows. Cinematic architectural cinematography, shallow
depth of field, no people, no text, no logos. Slow steady forward dolly
movement. 4K, photorealistic.
```

⚠️ **אסור לשנות את הבלוק הזה בין סצנות.** ברגע שמשנים חומרים או שעה,
החדרים מפסיקים להיראות כמו אותו בית — וזו בדיוק התקלה של סרטוני הסטוק.

---

## סצנה 1 — הכניסה · הדלת נפתחת

**מנורות:** אין. זו סצנת האווירה.

```
Slow forward dolly toward the entrance of a modern exotic villa at golden
hour. A long infinity pool runs along the left, reflecting the sky. Wide
travertine steps lead to a tall dark walnut pivot door with a slim black
vertical handle. Tropical palms and monstera flank the path. The door
slowly swings open as the camera reaches it, revealing warm amber light
inside. Cinematic, photorealistic, 4K, no people.
```

**למה זה עובד:** הדלת שנפתחת בסוף היא הרגע שהגולש "נכנס" — הגלילה
מסתיימת בדיוק שם, והחדר הבא מתחיל מבפנים.

---

## סצנה 2 — הסלון

**מנורה:** מנורה עומדת / תלויה מרכזית (עוד לא נבחרה)

```
Slow forward dolly into the living room of a modern exotic villa. Low
linen sofas around a stone coffee table, floor-to-ceiling glass wall
opening to an infinity pool and tropical garden. Dark walnut ceiling
beams, travertine floor. Warm amber light. Golden hour. Cinematic,
photorealistic, 4K, no people.
```

---

## סצנה 3 — המטבח ⭐ החדר שמוכר

**מנורה:** לינאה — שלושה מוטות שחורים דקים באורכים מדורגים

```
Slow forward dolly toward a long monolithic travertine kitchen island in
a modern exotic villa. Above the island hang three slim black cylindrical
rod pendant lights at staggered heights, glowing warm amber 3000K. Dark
walnut cabinetry, glass wall to a tropical garden behind. Golden hour.
Cinematic, photorealistic, 4K, no people.
```

⚠️ **התיאור של המנורות חייב להיות מדויק** — `three slim black cylindrical
rod pendants at staggered heights`. זו המנורה שאנחנו מוכרים בפועל.

---

## סצנה 4 — פינת האוכל

**מנורה:** אופק — פס אופקי אחד 80 ס״מ

```
Slow forward dolly toward a long dark walnut dining table in a modern
exotic villa. A single slim horizontal black linear LED bar pendant hangs
above the table, glowing warm amber. Travertine floor, glass wall to the
pool. Golden hour. Cinematic, photorealistic, 4K, no people.
```

---

## 📋 סדר הבנייה

| # | סצנה | מנורה | סטטוס |
|---|---|---|---|
| 1 | הכניסה | — | ממתין לקרדיטים |
| 2 | הסלון | טרם נבחרה | ממתין |
| 3 | המטבח | לינאה ₪690 | ממתין |
| 4 | פינת האוכל | אופק ₪890 | ממתין |

**להתחיל מ-3 (המטבח).** אם המטבח יוצא ברמה — ממשיכים. אם לא —
מכווננים את הפרומפט על סצנה אחת במקום על ארבע.

---

## אחרי שכל סצנה מאושרת

```
.\tools\frames.ps1 -Video "<הסרטון>" -Name kitchen -Quality 66
```

הכלי גוזר לבד את מספר הפריימים מהסרטון. אחר כך מעדכנים את `count`
ב-[data.js](../data.js).
