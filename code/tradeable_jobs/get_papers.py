#!/usr/bin/env python3
"""Download the Venables tradeable-jobs papers and turn them into readable markdown.

Run from the repo root:

    python3 -I code/tradeable_jobs/get_papers.py

Everything is written to local/tradeable_jobs/ (gitignored). The papers are
copyright (Oxford Research Archive terms of use, CEP "all rights reserved"), so
neither the PDFs nor the converted text are committed to this public repo.

    local/tradeable_jobs/papers_raw/<slug>/<file>.pdf   the PDF, one folder each
    local/tradeable_jobs/text/<slug>.txt                pdftotext -layout output
    local/tradeable_jobs/papers_md/<slug>.md            readable markdown
    local/tradeable_jobs/papers_md/img/<slug>_pN.png    pages with figures

Needs curl, pdftotext and pdftoppm (poppler). The CEPR copies of two of the
papers sit behind a Cloudflare check, so the Oxford working paper versions are
used instead (same papers, pre-publication versions).
"""

import re
import subprocess
import sys
import unicodedata
from pathlib import Path

PAPERS = [
    {
        "slug": "venables2020_left_behind",
        "file": "oxf_wp903.pdf",
        "url": "https://ora.ox.ac.uk/objects/uuid:da9c3785-8864-441b-91fe-52e851dad948/files/stt44pn34z",
        "record": "https://ora.ox.ac.uk/objects/uuid:da9c3785-8864-441b-91fe-52e851dad948",
        "title": "Why some places are left-behind: urban adjustment to trade and policy shocks",
        "authors": "Anthony J. Venables",
        "version": "Oxford Department of Economics Discussion Paper 903, February 2020. "
                   "Published as Oxford Review of Economic Policy 36(3), 604-620 (2020); also CEPR DP14474.",
        "licence": "ORA terms and conditions of use; copyright the author.",
        "drop_from": None,
    },
    {
        "slug": "venables2018_urban_polarisation",
        "file": "dp1707.pdf",
        "url": "https://cep.lse.ac.uk/pubs/download/dp1707.pdf",
        "record": "https://cep.lse.ac.uk/_NEW/PUBLICATIONS/abstract.asp?index=7153",
        "title": "Globalisation and urban polarisation",
        "authors": "Anthony J. Venables",
        "version": "CEP Discussion Paper 1707, July 2020. "
                   "Published as Review of International Economics 26(5), 981-996 (2018); also CEPR DP12877.",
        "licence": "CEP: all rights reserved, no reproduction without permission.",
        "drop_from": r"CENTRE FOR ECONOMIC PERFORMANCE",
    },
    {
        "slug": "rice_venables2023_tradability",
        "file": "oxf_wp996.pdf",
        "url": "https://ora.ox.ac.uk/objects/uuid:64b4d773-5ebb-4c1a-984d-dae7886a231c/files/sm900nv79n",
        "record": "https://ora.ox.ac.uk/objects/uuid:64b4d773-5ebb-4c1a-984d-dae7886a231c",
        "title": "Tradability, productivity, and regional disparities: theory and UK evidence",
        "authors": "Patricia G. Rice and Anthony J. Venables",
        "version": "Oxford Department of Economics Discussion Paper 996, January 2023. "
                   "Also CEPR DP17806 (2023) and, in an earlier version, The Productivity Institute WP 021 (2022).",
        "licence": "ORA terms and conditions of use.",
        "drop_from": None,
    },
]

# Adobe Symbol font, as pdftotext leaves it: private-use code points U+F020 to U+F0FE.
# The 2018 paper's equations use this font, so without the map its =, -, theta etc. vanish.
SYMBOL = {
    0x20: " ", 0x21: "!", 0x22: "∀", 0x23: "#", 0x24: "∃", 0x25: "%", 0x26: "&", 0x27: "∋",
    0x28: "(", 0x29: ")", 0x2A: "∗", 0x2B: "+", 0x2C: ",", 0x2D: "−", 0x2E: ".", 0x2F: "/",
    0x3A: ":", 0x3B: ";", 0x3C: "<", 0x3D: "=", 0x3E: ">", 0x3F: "?", 0x40: "≅",
    0x41: "Α", 0x42: "Β", 0x43: "Χ", 0x44: "Δ", 0x45: "Ε", 0x46: "Φ", 0x47: "Γ", 0x48: "Η",
    0x49: "Ι", 0x4A: "ϑ", 0x4B: "Κ", 0x4C: "Λ", 0x4D: "Μ", 0x4E: "Ν", 0x4F: "Ο", 0x50: "Π",
    0x51: "Θ", 0x52: "Ρ", 0x53: "Σ", 0x54: "Τ", 0x55: "Υ", 0x56: "ς", 0x57: "Ω", 0x58: "Ξ",
    0x59: "Ψ", 0x5A: "Ζ", 0x5B: "[", 0x5C: "∴", 0x5D: "]", 0x5E: "⊥", 0x5F: "_", 0x60: "",
    0x61: "α", 0x62: "β", 0x63: "χ", 0x64: "δ", 0x65: "ε", 0x66: "φ", 0x67: "γ", 0x68: "η",
    0x69: "ι", 0x6A: "ϕ", 0x6B: "κ", 0x6C: "λ", 0x6D: "μ", 0x6E: "ν", 0x6F: "ο", 0x70: "π",
    0x71: "θ", 0x72: "ρ", 0x73: "σ", 0x74: "τ", 0x75: "υ", 0x76: "ϖ", 0x77: "ω", 0x78: "ξ",
    0x79: "ψ", 0x7A: "ζ", 0x7B: "{", 0x7C: "|", 0x7D: "}", 0x7E: "∼",
    0xA1: "ϒ", 0xA2: "′", 0xA3: "≤", 0xA4: "⁄", 0xA5: "∞", 0xA6: "ƒ", 0xAB: "↔", 0xAC: "←",
    0xAD: "↑", 0xAE: "→", 0xAF: "↓", 0xB0: "°", 0xB1: "±", 0xB2: "″", 0xB3: "≥", 0xB4: "×",
    0xB5: "∝", 0xB6: "∂", 0xB7: "•", 0xB8: "÷", 0xB9: "≠", 0xBA: "≡", 0xBB: "≈", 0xBC: "…",
    0xC4: "⊗", 0xC5: "⊕", 0xC6: "∅", 0xC7: "∩", 0xC8: "∪", 0xCE: "∈", 0xCF: "∉", 0xD1: "∇",
    0xD5: "∏", 0xD6: "√", 0xD7: "⋅", 0xD8: "¬", 0xD9: "∧", 0xDA: "∨", 0xDE: "⇒", 0xE5: "∑",
    0xE6: "⎛", 0xE7: "⎜", 0xE8: "⎝", 0xE9: "⎡", 0xEA: "⎢", 0xEB: "⎣", 0xEC: "⎧", 0xED: "⎨",
    0xEE: "⎩", 0xEF: "⎪", 0xF2: "∫", 0xF6: "⎞", 0xF7: "⎟", 0xF8: "⎠", 0xF9: "⎤", 0xFA: "⎥",
    0xFB: "⎦", 0xFC: "⎫", 0xFD: "⎬", 0xFE: "⎭",
}
for d in range(10):
    SYMBOL[0x30 + d] = str(d)


def fix_chars(text):
    """Map Symbol-font private-use characters and maths italic letters to plain Unicode."""
    out = []
    for ch in text:
        cp = ord(ch)
        if 0xF020 <= cp <= 0xF0FF:
            out.append(SYMBOL.get(cp - 0xF000, ""))
        elif 0x1D400 <= cp <= 0x1D7FF:  # 𝑤 -> w, 𝜃 -> θ: easier to read and to search
            out.append(unicodedata.normalize("NFKC", ch))
        else:
            out.append(ch)
    return "".join(out)


BIG_GAP = re.compile(r"\S {4,}\S")
HEADING = re.compile(r"^(\d+(\.\d+)?[.:]?\s+[A-Z]|Appendix\b|References\b|Abstract\b)")
FIGURE = re.compile(r"^\s*Figure\s+[A-Z]?\d+\s*:")
NUMBER_ONLY = re.compile(r"^\s*\d{1,3}\s*$")


def is_prose(line, prev_prose):
    s = line.strip()
    if not s or BIG_GAP.search(s):
        return False
    return len(s) >= 40 or prev_prose


def render_page(pdf, page, png):
    png.parent.mkdir(parents=True, exist_ok=True)
    if not png.exists():
        subprocess.run(["pdftoppm", "-f", str(page), "-l", str(page), "-r", "110", "-png",
                        "-singlefile", str(pdf), str(png.with_suffix(""))], check=True)


def to_markdown(paper, pdf, pages, img_dir):
    md = [f"# {paper['title']}", "",
          f"**{paper['authors']}**", "",
          f"- **Version converted:** {paper['version']}",
          f"- **Source:** <{paper['url']}> (record: <{paper['record']}>)",
          f"- **Licence:** {paper['licence']} This copy is for private reading and stays in the gitignored `local/` folder.",
          "- **Conversion:** automatic, by `code/tradeable_jobs/get_papers.py`. Prose is reflowed. "
          "Equations and tables are kept in fixed-width blocks as `pdftotext -layout` placed them, so "
          "subscripts and superscripts can sit on the line above or below. Pages with figures are "
          "shown as images instead of their axis labels. Check equations against the PDF; the model "
          "equations are written out properly in `docs/chunks/tradeable_jobs/tradeable_jobs_plan.md`.",
          ""]
    para, block = [], []
    footnotes = []  # (number, [lines]) held until the paragraph that spans the page break ends
    pending_page = None
    shown_pages = set()

    def join(pieces):
        text = ""
        for piece in pieces:
            if text.endswith("-"):
                text += piece
            else:
                text = f"{text} {piece}" if text else piece
        return text

    def flush_para():
        nonlocal pending_page
        if para:
            md.extend([join(para), ""])
            para.clear()
        for num, lines in footnotes:
            md.extend([f"> **[fn {num}]** {join(lines)}", ""])
        footnotes.clear()
        if pending_page is not None:
            md.extend([f"*[PDF page {pending_page}]*", ""])
            pending_page = None

    def flush_block():
        while block and not block[-1].strip():
            block.pop()
        if block:
            indent = min(len(l) - len(l.lstrip()) for l in block if l.strip())
            md.append("```")
            md.extend(l[indent:].rstrip() for l in block)
            md.extend(["```", ""])
            block.clear()

    for pno, page in enumerate(pages, start=1):
        lines = page.split("\n")
        nonblank = [i for i, l in enumerate(lines) if l.strip()]
        if not nonblank:
            continue
        last = nonblank[-1]
        if NUMBER_ONLY.match(lines[last]):  # page number at the foot of the page
            lines = lines[:last]
        pending_page = pno if pending_page is None else pending_page
        prev_prose, skip_figure, in_footnotes = False, False, False
        for i, line in enumerate(lines):
            s = line.strip()
            before_blank = i == 0 or not lines[i - 1].strip()
            after_blank = i + 1 >= len(lines) or not lines[i + 1].strip()
            heading = (before_blank and len(s) < 90 and HEADING.match(s) and not BIG_GAP.search(s)
                       and (after_blank or s.endswith(":")))
            if NUMBER_ONLY.match(line) and not skip_figure:
                # A number alone on a line that isn't the page number starts a footnote;
                # the rest of the page is footnote area.
                in_footnotes = True
                footnotes.append((s, []))
                continue
            if in_footnotes:
                if s:
                    footnotes[-1][1].append(s)
                continue
            if FIGURE.match(line):
                flush_block(); flush_para()
                png = img_dir / f"{paper['slug']}_p{pno}.png"
                md.append(f"**{s}**")
                if pno in shown_pages:
                    md.extend(["", "(Same page image as the figure above.)", ""])
                else:
                    render_page(pdf, pno, png)
                    md.extend(["", f"![{s}](img/{png.name})", ""])
                    shown_pages.add(pno)
                skip_figure, prev_prose = True, False
                continue
            if skip_figure:  # axis labels and legend text: the page image shows them
                if heading or (is_prose(line, False) and len(s) >= 60):
                    skip_figure = False
                else:
                    continue
            if not s:
                # Keep a paragraph open across the gap before the footnotes, the page
                # break and the top margin of the next page.
                rest = [l for l in lines[i + 1:] if l.strip()]
                at_page_edge = i < nonblank[0] or not rest or NUMBER_ONLY.match(rest[0])
                if para and not at_page_edge:
                    flush_para()
                prev_prose = prev_prose and at_page_edge
                continue
            if heading:
                flush_block(); flush_para()
                md.extend([f"## {s}", ""])
                prev_prose = False
                continue
            if is_prose(line, prev_prose):
                flush_block()
                para.append(s)
                prev_prose = True
            else:
                flush_para()
                block.append(line)
                prev_prose = False
        flush_block()
    flush_para()
    flush_block()
    return "\n".join(md).rstrip() + "\n"


def main():
    root = Path.cwd()
    if not (root / "code" / "tradeable_jobs").is_dir():
        sys.exit("Run this from the repo root.")
    base = root / "local" / "tradeable_jobs"
    text_dir, md_dir = base / "text", base / "papers_md"
    text_dir.mkdir(parents=True, exist_ok=True)
    (md_dir / "img").mkdir(parents=True, exist_ok=True)

    for paper in PAPERS:
        pdf_dir = base / "papers_raw" / paper["slug"]
        pdf_dir.mkdir(parents=True, exist_ok=True)
        pdf = pdf_dir / paper["file"]
        if not pdf.exists():
            subprocess.run(["curl", "-sL", "--max-time", "120", "-A", "Mozilla/5.0 (research script)",
                            "-o", str(pdf), paper["url"]], check=True)
        if pdf.read_bytes()[:5] != b"%PDF-":
            pdf.unlink()
            sys.exit(f"{paper['slug']}: download is not a PDF (blocked or moved?): {paper['url']}")

        raw = subprocess.run(["pdftotext", "-layout", str(pdf), "-"], check=True,
                             capture_output=True, text=True).stdout
        text = fix_chars(raw)
        if paper["drop_from"]:
            cut = re.search(paper["drop_from"], text)
            if cut:
                text = text[:text.rfind("\f", 0, cut.start()) + 1]
        (text_dir / f"{paper['slug']}.txt").write_text(text, encoding="utf-8")

        md = to_markdown(paper, pdf, text.split("\f"), md_dir / "img")
        (md_dir / f"{paper['slug']}.md").write_text(md, encoding="utf-8")
        print(f"{paper['slug']}: {len(text.split(chr(12)))} pages -> {md_dir / (paper['slug'] + '.md')}")


if __name__ == "__main__":
    main()
