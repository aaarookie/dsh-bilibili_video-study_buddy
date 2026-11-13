#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
md2docx.py —— 把学习笔记 Markdown 转成 Word (.docx)

专为"网课笔记"设计，支持：
  * 标题 / 段落 / 粗体 / 行内代码
  * 代码块（等宽 + 浅灰底 + 保留缩进）
  * 表格（含表头加粗）
  * 图片（相对 md 所在目录解析，自动限宽）
  * 超链接（可点击，蓝色下划线）
  * 引用块（缩进 + 斜体）
  * 有序/无序列表

用法：
  py md2docx.py 笔记.md
  py md2docx.py 笔记.md -o 输出.docx
  py md2docx.py 笔记.md --font "Microsoft YaHei" --max-image-width 15
"""
import argparse
import os
import re
import sys

from docx import Document
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

LINK_COLOR = "0563C1"
CODE_BG = "F2F2F2"
QUOTE_COLOR = RGBColor(0x55, 0x55, 0x55)


# ---------------------------------------------------------------- 低层工具
def set_east_asian_font(run, font_name):
    rPr = run._element.get_or_add_rPr()
    rFonts = rPr.find(qn('w:rFonts'))
    if rFonts is None:
        rFonts = OxmlElement('w:rFonts')
        rPr.append(rFonts)
    rFonts.set(qn('w:eastAsia'), font_name)
    rFonts.set(qn('w:ascii'), font_name)
    rFonts.set(qn('w:hAnsi'), font_name)


def shade_paragraph(paragraph, fill=CODE_BG):
    pPr = paragraph._p.get_or_add_pPr()
    shd = OxmlElement('w:shd')
    shd.set(qn('w:val'), 'clear')
    shd.set(qn('w:color'), 'auto')
    shd.set(qn('w:fill'), fill)
    pPr.append(shd)


def add_hyperlink(paragraph, url, text, font_name):
    part = paragraph.part
    r_id = part.relate_to(
        url,
        "http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink",
        is_external=True,
    )
    hyperlink = OxmlElement('w:hyperlink')
    hyperlink.set(qn('r:id'), r_id)

    new_run = OxmlElement('w:r')
    rPr = OxmlElement('w:rPr')

    rFonts = OxmlElement('w:rFonts')
    rFonts.set(qn('w:eastAsia'), font_name)
    rFonts.set(qn('w:ascii'), font_name)
    rFonts.set(qn('w:hAnsi'), font_name)
    rPr.append(rFonts)

    color = OxmlElement('w:color')
    color.set(qn('w:val'), LINK_COLOR)
    rPr.append(color)

    u = OxmlElement('w:u')
    u.set(qn('w:val'), 'single')
    rPr.append(u)

    new_run.append(rPr)
    t = OxmlElement('w:t')
    t.set(qn('xml:space'), 'preserve')
    t.text = text
    new_run.append(t)
    hyperlink.append(new_run)
    paragraph._p.append(hyperlink)


# ---------------------------------------------------------------- 行内解析
INLINE_RE = re.compile(
    r'(`[^`]+`)'                 # 1 行内代码
    r'|(\*\*[^*]+\*\*)'          # 2 粗体
    r'|(\[[^\]]+\]\([^)]+\))'    # 3 链接
    r'|(<https?://[^>\s]+>)'     # 4 自动链接 <url>
)


def add_inline(paragraph, text, font_name, base_bold=False, base_italic=False, size=None):
    """把一行里的 **粗体** / `代码` / [链接](url) 拆成多个 run"""
    pos = 0
    for m in INLINE_RE.finditer(text):
        if m.start() > pos:
            run = paragraph.add_run(text[pos:m.start()])
            run.bold = base_bold
            run.italic = base_italic
            if size:
                run.font.size = size
            set_east_asian_font(run, font_name)

        token = m.group(0)
        if token.startswith('`'):
            run = paragraph.add_run(token[1:-1])
            run.font.name = 'Consolas'
            run.font.size = Pt(size.pt if size else 10)
            run.font.color.rgb = RGBColor(0xC7, 0x25, 0x4E)
            set_east_asian_font(run, 'Consolas')
        elif token.startswith('**'):
            run = paragraph.add_run(token[2:-2])
            run.bold = True
            if size:
                run.font.size = size
            set_east_asian_font(run, font_name)
        elif token.startswith('<'):
            url = token[1:-1]
            add_hyperlink(paragraph, url, url, font_name)
        else:
            lm = re.match(r'\[([^\]]+)\]\(([^)]+)\)', token)
            label, url = lm.group(1), lm.group(2).strip('<>').strip()
            add_hyperlink(paragraph, url, label, font_name)

        pos = m.end()

    if pos < len(text):
        run = paragraph.add_run(text[pos:])
        run.bold = base_bold
        run.italic = base_italic
        if size:
            run.font.size = size
        set_east_asian_font(run, font_name)


# ---------------------------------------------------------------- 表格
def is_table_line(line):
    s = line.strip()
    return s.startswith('|') and s.count('|') >= 2


def parse_table_row(line):
    s = line.strip()
    if s.startswith('|'):
        s = s[1:]
    if s.endswith('|'):
        s = s[:-1]
    return [c.strip() for c in s.split('|')]


def is_separator_row(cells):
    return all(re.fullmatch(r':?-{2,}:?', c.strip()) for c in cells if c.strip() != '') and any(cells)


# ---------------------------------------------------------------- 主转换
def convert(md_path, out_path=None, font_name="Microsoft YaHei",
            max_img_width_cm=15.0, body_size_pt=10.5):
    md_path = os.path.abspath(md_path)
    if not os.path.isfile(md_path):
        sys.exit(f"找不到文件: {md_path}")
    base_dir = os.path.dirname(md_path)

    if out_path is None:
        out_path = os.path.splitext(md_path)[0] + ".docx"

    with open(md_path, 'r', encoding='utf-8') as f:
        lines = f.read().splitlines()

    doc = Document()

    # 页面与正文样式
    for section in doc.sections:
        section.left_margin = Cm(2.2)
        section.right_margin = Cm(2.2)

    normal = doc.styles['Normal']
    normal.font.name = font_name
    normal.font.size = Pt(body_size_pt)
    normal._element.rPr.rFonts.set(qn('w:eastAsia'), font_name)

    for lvl in range(1, 4):
        st = doc.styles[f'Heading {lvl}']
        st.font.name = font_name
        st._element.rPr.rFonts.set(qn('w:eastAsia'), font_name)

    i = 0
    n = len(lines)
    in_code = False
    code_lang = ''
    code_buf = []
    first_heading_done = False

    while i < n:
        line = lines[i]
        stripped = line.strip()

        # --- 代码块
        if stripped.startswith('```'):
            if not in_code:
                in_code = True
                code_lang = stripped[3:].strip()
                code_buf = []
            else:
                # 输出代码块
                for cl in code_buf:
                    p = doc.add_paragraph()
                    p.paragraph_format.space_before = Pt(0)
                    p.paragraph_format.space_after = Pt(0)
                    p.paragraph_format.line_spacing = 1.0
                    run = p.add_run(cl if cl else ' ')
                    run.font.name = 'Consolas'
                    run.font.size = Pt(9)
                    set_east_asian_font(run, 'Consolas')
                    shade_paragraph(p, CODE_BG)
                if code_lang:
                    cap = doc.add_paragraph()
                    cr = cap.add_run(f"[{code_lang}]")
                    cr.font.size = Pt(7.5)
                    cr.font.color.rgb = RGBColor(0x99, 0x99, 0x99)
                in_code = False
            i += 1
            continue

        if in_code:
            code_buf.append(line.rstrip())
            i += 1
            continue

        # --- 空行
        if stripped == '':
            i += 1
            continue

        # --- 分隔线
        if re.fullmatch(r'-{3,}|\*{3,}|_{3,}', stripped):
            p = doc.add_paragraph()
            pPr = p._p.get_or_add_pPr()
            pbdr = OxmlElement('w:pBdr')
            bottom = OxmlElement('w:bottom')
            bottom.set(qn('w:val'), 'single')
            bottom.set(qn('w:sz'), '6')
            bottom.set(qn('w:color'), 'CCCCCC')
            pbdr.append(bottom)
            pPr.append(pbdr)
            i += 1
            continue

        # --- 表格
        if is_table_line(line):
            block = []
            while i < n and is_table_line(lines[i]):
                block.append(lines[i])
                i += 1
            rows = [parse_table_row(b) for b in block]
            rows = [r for r in rows if not is_separator_row(r)]
            if rows:
                cols = max(len(r) for r in rows)
                table = doc.add_table(rows=len(rows), cols=cols)
                table.style = 'Table Grid'
                table.alignment = WD_TABLE_ALIGNMENT.CENTER
                for ri, row in enumerate(rows):
                    for ci in range(cols):
                        cell = table.cell(ri, ci)
                        cell.text = ''
                        p = cell.paragraphs[0]
                        txt = row[ci] if ci < len(row) else ''
                        add_inline(p, txt, font_name,
                                   base_bold=(ri == 0),
                                   size=Pt(9.5))
                doc.add_paragraph()
            continue

        # --- 标题
        hm = re.match(r'^(#{1,6})\s+(.*)$', stripped)
        if hm:
            level = min(len(hm.group(1)), 4)
            text = hm.group(2).strip()
            h = doc.add_heading(level=level)
            add_inline(h, text, font_name)
            if not first_heading_done:
                first_heading_done = True
            i += 1
            continue

        # --- 图片（独占一行）
        im = re.match(r'^!\[([^\]]*)\]\(([^)]+)\)\s*$', stripped)
        if im:
            alt, src = im.group(1), im.group(2).strip().strip('<>').strip()
            img_path = src if os.path.isabs(src) else os.path.join(base_dir, src)
            if os.path.isfile(img_path):
                try:
                    doc.add_picture(img_path, width=Cm(max_img_width_cm))
                    doc.paragraphs[-1].alignment = WD_ALIGN_PARAGRAPH.CENTER
                    if alt:
                        cap = doc.add_paragraph()
                        cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
                        cr = cap.add_run(alt)
                        cr.font.size = Pt(8.5)
                        cr.font.color.rgb = RGBColor(0x88, 0x88, 0x88)
                        set_east_asian_font(cr, font_name)
                except Exception as e:
                    p = doc.add_paragraph()
                    r = p.add_run(f"[图片嵌入失败: {alt} -> {src} ({e})]")
                    r.font.color.rgb = RGBColor(0xCC, 0x00, 0x00)
            else:
                p = doc.add_paragraph()
                r = p.add_run(f"[图片缺失: {src}]")
                r.font.color.rgb = RGBColor(0xCC, 0x00, 0x00)
            i += 1
            continue

        # --- 引用
        if stripped.startswith('>'):
            buf = []
            while i < n and lines[i].strip().startswith('>'):
                buf.append(re.sub(r'^\s*>\s?', '', lines[i]))
                i += 1
            p = doc.add_paragraph()
            p.paragraph_format.left_indent = Cm(0.6)
            for bi, bl in enumerate(buf):
                if bi > 0:
                    p.add_run('\n')
                add_inline(p, bl.strip(), font_name, base_italic=True)
            for run in p.runs:
                run.font.color.rgb = QUOTE_COLOR
                run.font.size = Pt(body_size_pt - 0.5)
            continue

        # --- 无序列表
        lm = re.match(r'^(\s*)[-*+]\s+(.*)$', line)
        if lm:
            indent = len(lm.group(1)) // 2
            p = doc.add_paragraph(style='List Bullet')
            p.paragraph_format.left_indent = Cm(0.75 + 0.6 * indent)
            add_inline(p, lm.group(2), font_name)
            i += 1
            continue

        # --- 有序列表
        om = re.match(r'^(\s*)(\d+)[.)]\s+(.*)$', line)
        if om:
            indent = len(om.group(1)) // 2
            p = doc.add_paragraph(style='List Number')
            p.paragraph_format.left_indent = Cm(0.75 + 0.6 * indent)
            add_inline(p, om.group(3), font_name)
            i += 1
            continue

        # --- 复选框（- [ ] / - [x]）
        cm = re.match(r'^\s*-\s+\[([ xX])\]\s+(.*)$', line)
        if cm:
            mark = '☑' if cm.group(1).lower() == 'x' else '☐'
            p = doc.add_paragraph()
            p.paragraph_format.left_indent = Cm(0.75)
            add_inline(p, f"{mark} {cm.group(2)}", font_name)
            i += 1
            continue

        # --- 普通段落
        p = doc.add_paragraph()
        p.paragraph_format.space_after = Pt(4)
        add_inline(p, stripped, font_name)
        i += 1

    doc.save(out_path)
    return out_path


def main():
    ap = argparse.ArgumentParser(description="Markdown 学习笔记 -> Word (.docx)")
    ap.add_argument("md", help="输入的 Markdown 文件")
    ap.add_argument("-o", "--out", help="输出的 .docx 路径（默认同目录同名）")
    ap.add_argument("--font", default="Microsoft YaHei", help="中文字体")
    ap.add_argument("--max-image-width", type=float, default=15.0,
                    help="图片最大宽度（厘米）")
    args = ap.parse_args()

    out = convert(args.md, args.out, args.font, args.max_image_width)
    size_kb = os.path.getsize(out) / 1024
    print(f"OK  {out}  ({size_kb:.1f} KB)")


if __name__ == "__main__":
    main()
