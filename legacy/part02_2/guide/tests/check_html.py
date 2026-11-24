#!/usr/bin/env python3
"""P2-11..20 course: adversarial, OFFLINE static distribution audit.

Checks all distributable HTML, CSS/JS assets, internal navigation, literal
source-code fidelity to archived chapters and 12.1-12.4 original lab code.
No claim of browser rendering, synthesized FPGA or physical board testing.
"""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlparse
import json
import re

ROOT = Path(__file__).resolve().parents[1]
CHAPTER_DIR = ROOT.parent
CONFIG = json.loads((ROOT / "course.json").read_text(encoding="utf-8"))
CHAPTERS = CONFIG["chapters"]

CHAPTER_ORIGINAL = [
    "P2_11_Study_Guide.html", "P2_12_Study_Guide.html",
    "P2_13_Study_Guide_v02.html", "P2_14_Study_Guide_v02.html",
] + [f"P2_{i}_Study_Guide_v01.html" for i in range(15, 21)]

LAB_ORIGINAL = [f"P2_12_{i}_Lab_v04.html" for i in range(1, 5)]
LAB_OUTPUT = [f"labs/P2_12_{i}_Lab_v06.html" for i in range(1, 5)]
SECRET = re.compile(
    r"(?i)ghp_[a-z0-9]{16,}|github_pat_[a-z0-9_]{16,}|"
    r"sk-[a-z0-9]{20,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"
)
USER_PATH = re.compile(r"(?i)/home/[a-z0-9_-]+/")
PRE = re.compile(r"<pre\b[^>]*>([\s\S]*?)</pre>", re.I)


def check(condition, why):
    if not condition:
        raise AssertionError(why)


class Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.ids = set()
        self.references = []
        self.elements = {}
        self.codebars = 0
        self.section_count = 0

    def handle_starttag(self, tag, attributes):
        a = dict(attributes)
        self.elements[tag] = self.elements.get(tag, 0) + 1
        if "id" in a:
            check(a["id"] not in self.ids, f"duplicate id: {a['id']}")
            self.ids.add(a["id"])
        if tag in ("a", "link") and a.get("href"):
            self.references.append(a["href"])
        if tag in ("img", "script", "iframe") and a.get("src"):
            self.references.append(a["src"])
        classes = (a.get("class") or "").split()
        if "codebar" in classes:
            self.codebars += 1
        if "section" in classes:
            self.section_count += 1


cache = {}


def parse_html(file):
    file = file.resolve()
    if file in cache:
        return cache[file]
    text = file.read_text(encoding="utf-8")
    check(text.lstrip().lower().startswith("<!doctype html>"),
          f"{file.name}: DOCTYPE")
    check(not SECRET.search(text), f"{file.name}: potential token/key")
    check(not USER_PATH.search(text), f"{file.name}: local user path")
    p = Page()
    p.feed(text)
    check(p.elements.get("html", 0) == 1, f"{file.name}: HTML root")
    check(p.elements.get("main", 0) == 1, f"{file.name}: MAIN count")
    cache[file] = (p, text)
    return p, text


def validate_references(file, page):
    for url in page.references:
        u = urlparse(url)
        check(u.scheme in ("", "https", "http", "mailto"),
              f"{file.name}: unsafe or unsupported URL scheme: {url}")
        if u.scheme or url.startswith("//"):
            continue
        path = unquote(u.path)
        destination = ((file.parent / path) if path else file).resolve()
        check(destination.is_relative_to(ROOT.resolve()),
              f"{file.name}: site navigation escapes distribution: {url}")
        check(destination.is_file(),
              f"{file.name}: broken local asset/link: {url}")
        if u.fragment:
            fragment = unquote(u.fragment)
            target, _ = parse_html(destination)
            check(fragment in target.ids,
                  f"{file.name}: missing anchor #{fragment}: {url}")


def check_embedded_manifest(file, html):
    m = re.search(r"<script>window\.COURSE=(\{[\s\S]*?\});</script>", html)
    check(m is not None, f"{file.name}: missing navigation manifest")
    data = json.loads(m.group(1))
    expected = {c["id"]: c["file"] for c in CHAPTERS}
    found = {c["id"]: c["file"] for c in data["chapters"]}
    check(found == expected, f"{file.name}: stale navigation manifest")


def check_code_fidelity(source, output):
    check(source.is_file(), f"original source absent: {source}")
    old_code = PRE.findall(source.read_text(encoding="utf-8"))
    new_code = PRE.findall(output.read_text(encoding="utf-8"))
    check(old_code == new_code,
          f"{output.name}: original code block count/text changed")
    return len(old_code)


def audit_one(file, is_lab=False):
    p, html = parse_html(file)
    check(p.elements.get("nav", 0) >= 1, f"{file.name}: no navigation")
    check("main-content" in p.ids, f"{file.name}: no skip-link target")
    check("course-nav" in p.ids, f"{file.name}: no course nav")
    check("mobile-menu" in p.ids, f"{file.name}: no mobile menu")
    check("shade" in p.ids, f"{file.name}: no mobile dismiss layer")
    check("chapter-links" in p.ids, f"{file.name}: no chapter links")
    check(p.section_count >= 1, f"{file.name}: no educational section")
    check_embedded_manifest(file, html)
    css = "../assets/site.css" if is_lab else "assets/site.css"
    js = "../assets/site.js" if is_lab else "assets/site.js"
    check(css in p.references and js in p.references,
          f"{file.name}: missing standard CSS/JS")
    check(p.codebars == len(PRE.findall(html)),
          f"{file.name}: copy control/pre block mismatch")
    if not is_lab:
        check(p.codebars > 0, f"{file.name}: missing source code")
    validate_references(file, p)
    return p.codebars


def main():
    check(CONFIG["version"] == "v05", "course version mismatch")
    check(len(CHAPTERS) == 10, "expected CH11..20 exactly")
    check([c["number"] for c in CHAPTERS] == list(range(11, 21)),
          "chapter numbering invalid")
    check(all(c["file"].endswith("_v05.html") for c in CHAPTERS),
          "wrong chapter version")
    check(len({c["id"] for c in CHAPTERS}) == 10, "duplicate chapter ids")
    check(len({c["file"] for c in CHAPTERS}) == 10,
          "duplicate chapter names")

    css = (ROOT / "assets/site.css").read_text(encoding="utf-8")
    js = (ROOT / "assets/site.js").read_text(encoding="utf-8")
    check("#f1f2ee" in css and "hero-bookshelf.jpg" in css,
          "wrong central brand style")
    check("linkPrefix" in js and "Escape" in js and "복사" in js,
          "nested lab navigation/accessibility/copy missing")
    all_pages = sorted(ROOT.glob("ch*_v*.html"))
    check({p.name for p in all_pages} == {c["file"] for c in CHAPTERS},
          "old/missing generated chapters")
    all_labs = sorted((ROOT / "labs").glob("P2_12_*_Lab_v*.html"))
    check({p.relative_to(ROOT).as_posix() for p in all_labs}
          == set(LAB_OUTPUT), "missing/obsolete lab outputs")

    index = ROOT / "index.html"
    intro, _ = parse_html(index)
    check("tech-tree" in intro.ids, "tech-tree missing from cover")
    check(sum(c["file"] in intro.references for c in CHAPTERS) == 10,
          "index does not link all 10 chapters")
    for lab in LAB_OUTPUT:
        check(lab in intro.references, f"cover missing lab link: {lab}")
    validate_references(index, intro)

    code_count = 0
    for i, ch in enumerate(CHAPTERS):
        dest = ROOT / ch["file"]
        code_count += audit_one(dest)
        original = CHAPTER_DIR / f"P2_{i+11}_Lesson" / CHAPTER_ORIGINAL[i]
        check_code_fidelity(original, dest)
        print(f"P2_CH{i+11:02d}_HTML_SOURCE_LINKS_PASS")

    lab_code_count = 0
    for i, name in enumerate(LAB_OUTPUT):
        dest = ROOT / name
        lab_code_count += audit_one(dest, is_lab=True)
        src = CHAPTER_DIR / "P2_12_Lesson" / "labs" / LAB_ORIGINAL[i]
        check_code_fidelity(src, dest)
        print(f"P2_LAB12_{i+1}_HTML_SOURCE_LINKS_PASS")

    for asset in ("12_2_jc_candidate.xdc",
                  "12_3_board_smoke.c", "12_4_ramp_vitis_example.c"):
        original = CHAPTER_DIR / "P2_12_Lesson" / "labs" / asset
        copy = ROOT / "labs" / asset
        check(original.read_bytes() == copy.read_bytes(),
              "changed standalone lab companion source: " + asset)

    print(f"P2_11_20_HTML_STATIC_AUDIT_PASS "
          f"(chapters=10 labs=4 codeblocks={code_count + lab_code_count}; "
          f"NO browser/FPGA verification)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
