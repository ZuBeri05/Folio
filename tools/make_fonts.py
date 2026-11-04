"""Build the two static, subsetted fonts the Switch port ships with.

Noto Sans SC is a variable font; stb_truetype only reads the default instance,
so we bake Regular and Bold first. The subset keeps Latin, kana, Hangul, CJK
punctuation and every Hanzi encodable in GB2312 (the characters a Chinese user
is realistically going to type into a chapter title).
"""
import os
import subprocess
import sys

from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "NotoSansSC.ttf")
OUT = os.path.join(HERE, "out_fonts")


def gb2312_chars():
    chars = set()
    for hi in range(0xB0, 0xF8):
        for lo in range(0xA1, 0xFF):
            try:
                chars.add(bytes([hi, lo]).decode("gb2312"))
            except UnicodeDecodeError:
                pass
    return chars


def ranges(codepoints):
    cps = sorted(codepoints)
    out = []
    start = prev = cps[0]
    for cp in cps[1:]:
        if cp == prev + 1:
            prev = cp
            continue
        out.append((start, prev))
        start = prev = cp
    out.append((start, prev))
    return out


def main():
    os.makedirs(OUT, exist_ok=True)

    cps = set()
    cps.update(range(0x20, 0x7F))          # ASCII
    cps.update(range(0xA0, 0x180))          # Latin-1 + Latin Extended-A
    cps.update(range(0x2000, 0x2070))       # general punctuation
    cps.update(range(0x20A0, 0x20C0))
    cps.update(range(0x2190, 0x2200))       # arrows
    cps.update(range(0x2500, 0x2580))       # box drawing
    cps.update(range(0x25A0, 0x2600))
    cps.update(range(0x3000, 0x3040))       # CJK punctuation
    cps.update(range(0x3040, 0x3100))       # kana
    cps.update(range(0xAC00, 0xD7A4))       # Hangul syllables
    cps.update(ord(c) for c in gb2312_chars())
    # A few characters the UI uses that live outside GB2312 ranges.
    cps.update(ord(c) for c in "·—–…‰′″€™✓✕×÷°§¶•→←↑↓※〇々ー")

    spec = ",".join("U+%04X-%04X" % (a, b) if a != b else "U+%04X" % a for a, b in ranges(cps))
    unicodes = os.path.join(HERE, "font_unicodes.txt")
    with open(unicodes, "w", encoding="utf-8") as f:
        f.write(spec)

    for name, wght in (("Regular", 400), ("Bold", 700)):
        var = TTFont(SRC)
        inst = instantiateVariableFont(var, {"wght": wght}, inplace=True, updateFontNames=False)
        # Drop the variable-specific tables so stb_truetype sees plain glyf outlines.
        for tag in ("fvar", "gvar", "HVAR", "MVAR", "avar", "STAT"):
            if tag in inst:
                del inst[tag]
        inst["head"].macStyle = 1 if wght >= 700 else 0
        path = os.path.join(OUT, "NotoSansSC-%s.ttf" % name)
        inst.save(path)

        sub = os.path.join(OUT, "NotoSansSC-%s.sub.ttf" % name)
        subprocess.run([
            sys.executable, "-m", "fontTools.subset", path,
            "--unicodes-file=" + unicodes,
            "--layout-features=*",
            "--no-hinting",
            "--drop-tables+=DSIG",
            "--output-file=" + sub,
        ], check=True)
        print(name, "full=%.1fMB" % (os.path.getsize(path) / 1e6),
              "subset=%.1fMB" % (os.path.getsize(sub) / 1e6))


if __name__ == "__main__":
    main()
