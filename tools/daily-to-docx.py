#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Markdown-lite  ->  .docx      (pure stdlib: no pip, no Microsoft Word)

    python3 tools/daily-to-docx.py input.md output.docx

Why this exists
---------------
tools/lesson-to-docx.ps1 drives a real Word install through COM. That works on
Eitan's Windows machine but not inside the cloud routine that builds the daily
AI digest. A .docx is just a zip of XML parts, so we write those parts directly.

Supported syntax
----------------
    # / ## / ###        headings
    - item              bullet
    > note              callout paragraph
    | a | b |           table row (a |---|---| separator row is skipped)
    ---                 horizontal rule
    **bold**            bold run
    `code`              monospace run
    [text](url)         external hyperlink
    (anything else)     plain paragraph

Direction is decided per paragraph: a line containing any Hebrew letter is laid
out RTL and right-aligned, a Latin-only line is LTR and left-aligned. That keeps
the Hebrew research summaries and the English vocabulary sentences both readable
in the same document.
"""

import re
import sys
import zipfile

HEB = re.compile(r"[֐-׿]")
NS = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" ' \
     'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"'

# Page body width in twips: Letter/A4 minus 1 inch margins on both sides.
BODY_TWIPS = 9360


def esc(t):
    return t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")


def is_rtl(text):
    return bool(HEB.search(text))


# ---------------------------------------------------------------- inline runs

INLINE = re.compile(r"(\*\*.+?\*\*|`[^`]+`|\[[^\]]+\]\([^)]+\))")


def runs(text, rels, base_style=None):
    """Turn inline markdown into a list of <w:r> / <w:hyperlink> XML strings."""
    out = []
    for piece in INLINE.split(text):
        if not piece:
            continue
        if piece.startswith("**") and piece.endswith("**"):
            out.append(run_xml(piece[2:-2], bold=True, style=base_style))
        elif piece.startswith("`") and piece.endswith("`"):
            out.append(run_xml(piece[1:-1], code=True, style=base_style))
        elif piece.startswith("["):
            label, url = re.match(r"\[([^\]]+)\]\(([^)]+)\)", piece).groups()
            rid = rels.add(url)
            out.append('<w:hyperlink r:id="%s">%s</w:hyperlink>'
                       % (rid, run_xml(label, link=True, style=base_style)))
        else:
            out.append(run_xml(piece, style=base_style))
    return "".join(out) or run_xml("")


def run_xml(text, bold=False, code=False, link=False, style=None):
    props = []
    if code:
        props.append('<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:cs="Consolas"/>')
    if bold:
        props.append("<w:b/><w:bCs/>")
    if link:
        props.append('<w:color w:val="1155CC"/><w:u w:val="single"/>')
    if style == "meta":
        props.append('<w:color w:val="6B6B6B"/><w:sz w:val="19"/><w:szCs w:val="19"/>')
    if is_rtl(text):
        props.append("<w:rtl/>")
    rpr = "<w:rPr>%s</w:rPr>" % "".join(props) if props else ""
    return '<w:r>%s<w:t xml:space="preserve">%s</w:t></w:r>' % (rpr, esc(text))


# ---------------------------------------------------------------- paragraphs

def para(text, rels, style=None, indent=0, shade=None):
    rtl = is_rtl(text)
    props = []
    if style in ("Heading1", "Heading2", "Heading3"):
        props.append('<w:pStyle w:val="%s"/>' % style)
    if rtl:
        props.append("<w:bidi/>")
    if indent:
        side = "w:right" if rtl else "w:left"
        props.append('<w:ind %s="%d"/>' % (side, indent))
    if shade:
        props.append('<w:shd w:val="clear" w:fill="%s"/>' % shade)
    props.append('<w:spacing w:before="%d" w:after="%d" w:line="300" w:lineRule="auto"/>'
                 % (240 if style in ("Heading1", "Heading2") else 0, 120))
    props.append('<w:jc w:val="%s"/>' % ("right" if rtl else "left"))
    base = "meta" if style == "meta" else None
    return "<w:p><w:pPr>%s</w:pPr>%s</w:p>" % ("".join(props), runs(text, rels, base))


def rule():
    return ('<w:p><w:pPr><w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" '
            'w:color="D8D8D8"/></w:pBdr><w:spacing w:before="120" w:after="120"/>'
            "</w:pPr></w:p>")


# ---------------------------------------------------------------- tables

def table(rows, rels):
    ncols = max(len(r) for r in rows)
    rtl = any(is_rtl(c) for row in rows for c in row)
    width = BODY_TWIPS // ncols

    def borders():
        edges = ("top", "left", "bottom", "right", "insideH", "insideV")
        return "<w:tblBorders>%s</w:tblBorders>" % "".join(
            '<w:%s w:val="single" w:sz="4" w:space="0" w:color="C9C9C9"/>' % e for e in edges)

    def cell(text, header):
        shade = '<w:shd w:val="clear" w:fill="EFEFEF"/>' if header else ""
        body = text if not header else "**%s**" % text
        inner = para(body, rels)
        return ('<w:tc><w:tcPr><w:tcW w:w="%d" w:type="dxa"/>%s'
                '<w:vAlign w:val="center"/></w:tcPr>%s</w:tc>' % (width, shade, inner))

    xml = ['<w:tbl><w:tblPr><w:tblW w:w="5000" w:type="pct"/>%s%s</w:tblPr>'
           % ("<w:bidiVisual/>" if rtl else "", borders())]
    xml.append("<w:tblGrid>%s</w:tblGrid>" % ('<w:gridCol w:w="%d"/>' % width * ncols))
    for i, row in enumerate(rows):
        cells = list(row) + [""] * (ncols - len(row))
        trpr = '<w:trPr><w:tblHeader/></w:trPr>' if i == 0 else ""
        xml.append("<w:tr>%s%s</w:tr>" % (trpr, "".join(cell(c, i == 0) for c in cells)))
    xml.append("</w:tbl>")
    # Word needs a paragraph after a table, otherwise two tables glue together.
    xml.append('<w:p><w:pPr><w:spacing w:after="0"/></w:pPr></w:p>')
    return "".join(xml)


# ---------------------------------------------------------------- relationships

class Rels(object):
    def __init__(self):
        self.links = []

    def add(self, url):
        self.links.append(url)
        return "rId%d" % (100 + len(self.links))

    def xml(self):
        base = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
        items = ['<Relationship Id="rId1" Type="%s/styles" Target="styles.xml"/>' % base]
        for i, url in enumerate(self.links):
            items.append('<Relationship Id="rId%d" Type="%s/hyperlink" Target="%s" '
                         'TargetMode="External"/>' % (100 + i + 1, base, esc(url)))
        return ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
                '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/'
                'relationships">%s</Relationships>' % "".join(items))


# ---------------------------------------------------------------- parser

def convert(text, rels):
    body = []
    lines = text.replace("\r\n", "\n").split("\n")
    i = 0
    while i < len(lines):
        line = lines[i].rstrip()
        stripped = line.strip()

        if not stripped:
            i += 1
            continue

        if stripped.startswith("|"):
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                cells = [c.strip() for c in lines[i].strip().strip("|").split("|")]
                if not all(re.fullmatch(r":?-{2,}:?", c or "-") and set(c) <= set("-: ")
                           for c in cells):
                    rows.append(cells)
                i += 1
            if rows:
                body.append(table(rows, rels))
            continue

        if re.fullmatch(r"-{3,}", stripped):
            body.append(rule())
        elif stripped.startswith("### "):
            body.append(para(stripped[4:], rels, "Heading3"))
        elif stripped.startswith("## "):
            body.append(para(stripped[3:], rels, "Heading2"))
        elif stripped.startswith("# "):
            body.append(para(stripped[2:], rels, "Heading1"))
        elif stripped.startswith("> "):
            body.append(para(stripped[2:], rels, indent=240, shade="FFF8E1"))
        elif stripped.startswith("- "):
            body.append(para("•  " + stripped[2:], rels, indent=280))
        elif stripped.startswith("_") and stripped.endswith("_") and len(stripped) > 2:
            body.append(para(stripped[1:-1], rels, style="meta"))
        else:
            body.append(para(stripped, rels))
        i += 1

    return "".join(body)


# ---------------------------------------------------------------- parts

STYLES = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<w:styles ' + NS + ">"
          "<w:docDefaults><w:rPrDefault><w:rPr>"
          '<w:rFonts w:ascii="Segoe UI" w:hAnsi="Segoe UI" w:cs="Segoe UI"/>'
          '<w:sz w:val="23"/><w:szCs w:val="23"/><w:color w:val="1A1A1A"/>'
          "</w:rPr></w:rPrDefault></w:docDefaults>"
          '<w:style w:type="paragraph" w:default="1" w:styleId="Normal">'
          '<w:name w:val="Normal"/></w:style>'
          + "".join(
              '<w:style w:type="paragraph" w:styleId="Heading%d">'
              '<w:name w:val="heading %d"/><w:basedOn w:val="Normal"/>'
              '<w:pPr><w:outlineLvl w:val="%d"/>%s</w:pPr>'
              '<w:rPr><w:b/><w:bCs/><w:color w:val="%s"/><w:sz w:val="%d"/>'
              '<w:szCs w:val="%d"/></w:rPr></w:style>'
              % (lvl, lvl, lvl - 1, bdr, color, size, size)
              for lvl, color, size, bdr in (
                  (1, "0F2B46", 44, '<w:pBdr><w:bottom w:val="single" w:sz="18" '
                                    'w:space="4" w:color="C9A227"/></w:pBdr>'),
                  (2, "0F2B46", 30, ""),
                  (3, "44607A", 25, ""))) +
          "</w:styles>")

CONTENT_TYPES = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
                 '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
                 '<Default Extension="rels" ContentType="application/vnd.openxmlformats-'
                 'package.relationships+xml"/>'
                 '<Default Extension="xml" ContentType="application/xml"/>'
                 '<Override PartName="/word/document.xml" ContentType="application/vnd.'
                 'openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
                 '<Override PartName="/word/styles.xml" ContentType="application/vnd.'
                 'openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
                 "</Types>")

ROOT_RELS = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
             '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/'
             'relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.'
             'org/officeDocument/2006/relationships/officeDocument" Target="word/document.'
             'xml"/></Relationships>')

SECT_PR = ('<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
           '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" '
           'w:header="709" w:footer="709" w:gutter="0"/><w:bidi/></w:sectPr>')


def build(md_text, out_path):
    rels = Rels()
    body = convert(md_text, rels)
    document = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
                "<w:document " + NS + "><w:body>" + body + SECT_PR + "</w:body></w:document>")

    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml", CONTENT_TYPES)
        z.writestr("_rels/.rels", ROOT_RELS)
        z.writestr("word/document.xml", document)
        z.writestr("word/_rels/document.xml.rels", rels.xml())
        z.writestr("word/styles.xml", STYLES)


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: daily-to-docx.py <input.md> <output.docx>")
    src, dst = sys.argv[1], sys.argv[2]
    with open(src, "r", encoding="utf-8") as f:
        build(f.read(), dst)
    print("OK: " + dst)


if __name__ == "__main__":
    main()
