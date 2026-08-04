# דוח ה-AI היומי — אינדקס

כל יום ב-12:00 (שעון ישראל) סוכן ענן מחפש חמישה פרסומים חזקים בתחום ה-AI,
כותב אותם בעברית, מוסיף עשר מילים באנגלית ברמת בסיס, ושומר הכול כקובץ Word
בתיקייה הזו.

**הקובץ של היום:** `docs/daily-ai/YYYY-MM-DD.docx`
**קישור הורדה:** `https://github.com/eitankoch2004-cpu/villa-scroll/raw/main/docs/daily-ai/YYYY-MM-DD.docx`

הטבלה למטה היא הזיכרון של הסוכן. הוא קורא אותה לפני כל ריצה כדי לא לחזור
על אותו מחקר ולא ללמד אותה מילה פעמיים. **אל תמחק שורות ממנה.**

---

## היסטוריה

| תאריך | איך נשלח | המחקרים | המילים | שיעור Claude Code |
|---|---|---|---|---|
| 2026-07-29 | ידני, מ-VS Code | — | need, because, enough, remember, fight, friend, hide, protect, open, free, fast, build, answer, help, learn, money, week, easy | skill |
| 2026-08-02 | ידני, מ-VS Code | GDM Alignment — סיכום שנתיים + Gemma Scope 2 · FLI AI Safety Index Summer 2026 · שחרור Claude Opus 5 | bring, wait, carry, choose, climb, break, hungry, quiet, later, between | 1. איפה Claude Code רץ |

| 2026-08-03 | ידני, מ-VS Code | OpenAI Astra — עשר בעיות מתמטיות פתוחות עם הוכחות Lean · Anthropic — Agentic Misalignment Summer 2026 · Anthropic — AI Organizations, צוות סוכנים פחות מיושר | borrow, return, heavy, light, early, tired, together, maybe, almost, change | 2. slash command |

| 2026-08-04 | **GitHub Actions** ✅ | חוק ה-AI האירופי סעיף 50 — סימון תוכן AI · Google DeepMind — Gemini Robotics 2 · סיכום: התבנית של השבועיים | already, decide, forget, listen, next, other, place, ready, sure, until | 3. CLAUDE.md |

**לא נשלחו כלל:** 30.7, 31.7, 1.8 — הרוטינה בענן ירתה ולא הפיקה פלט.

## למה הרוטינה בענן לא עובדת — נסגר 2.8.2026
הסביבה בענן עוברת דרך proxy עם רשימת דומיינים מותרים.
`api.telegram.org` **לא ברשימה** → `curl: (56) CONNECT tunnel failed, response 403`.
גם WebFetch מקבל 403. `github.com` ו-`pypi.org` **כן** ברשימה.
מסקנה: הענן לא יכול לשלוח לטלגרם. הפתרון המתוכנן — הענן דוחף קובץ ל-GitHub,
ו-GitHub Actions שולח אותו לטלגרם.
