#!/usr/bin/env python3
"""배포 폴더의 HTML 링크, SVG, 공개 경로를 표준 라이브러리로 점검한다."""

from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote
import re
import xml.etree.ElementTree as ET


class DocumentParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.references = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            assert attrs["id"] not in self.ids, f"duplicate id: {attrs['id']}"
            self.ids.add(attrs["id"])
        for key in ("href", "src"):
            if key in attrs:
                self.references.append(attrs[key])


def parse_html(path):
    parser = DocumentParser()
    parser.feed(path.read_text(encoding="utf-8"))
    return parser


def check_package(root):
    root = Path(root).resolve()
    html_files = sorted(root.glob("*.html"))
    assert html_files, f"no HTML files: {root}"

    for path in html_files:
        parser = parse_html(path)
        for reference in parser.references:
            if not reference or reference.startswith(
                ("#", "http://", "https://", "mailto:", "data:", "javascript:")
            ):
                continue
            relative, _, fragment = reference.partition("#")
            relative = unquote(relative.split("?", 1)[0])
            target = (path.parent / relative).resolve()
            assert target.exists(), f"missing reference: {path.name} -> {reference}"
            if fragment and target.suffix.lower() == ".html":
                assert fragment in parse_html(target).ids, (
                    f"missing fragment: {path.name} -> {reference}"
                )

    for svg in root.rglob("*.svg"):
        ET.parse(svg)

    forbidden = re.compile(
        r"/home/[^/<\s]+|/Users/[^/<\s]+|[A-Za-z]:\\Users\\|"
        r"github_pat_|ghp_[A-Za-z0-9]+|AKIA[0-9A-Z]{16}"
    )
    for path in root.rglob("*"):
        if path.is_file() and path.suffix.lower() in {
            ".html", ".md", ".txt", ".c", ".h", ".v", ".xdc", ".mmd", ".dot"
        }:
            assert not forbidden.search(path.read_text(encoding="utf-8", errors="ignore")), (
                f"private path or credential pattern: {path}"
            )

    print(f"PACKAGE_CHECK_OK html={len(html_files)} root={root.name}")
