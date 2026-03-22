#!/usr/bin/env python3
from __future__ import annotations

import argparse
import html
import json
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path


EXAMPLE_FENCE = "```````````````````````````````` example"
EXAMPLE_END = "````````````````````````````````"
SECTION_RE = re.compile(r"^(#{1,6})\s+(.*)$")

BASIC_SECTION_KEYWORDS = {
    "backslash escapes",
    "atx headings",
    "setext headings",
    "thematic breaks",
    "indented code blocks",
    "block quotes",
    "list items",
    "lists",
    "code spans",
    "emphasis and strong emphasis",
    "links",
    "images",
    "hard line breaks",
    "soft line breaks",
    "paragraphs",
}


@dataclass
class Example:
    number: int
    section: str
    markdown: str
    expected_html: str


def parse_spec_examples(spec_text: str) -> list[Example]:
    lines = spec_text.splitlines()
    examples: list[Example] = []
    section_stack: list[str] = []
    i = 0
    example_number = 0

    while i < len(lines):
        heading_match = SECTION_RE.match(lines[i])
        if heading_match:
            level = len(heading_match.group(1))
            title = heading_match.group(2).strip()
            while len(section_stack) >= level:
                section_stack.pop()
            section_stack.append(title)
            i += 1
            continue

        if lines[i] == EXAMPLE_FENCE:
            example_number += 1
            i += 1
            markdown_lines: list[str] = []
            while i < len(lines) and lines[i] != ".":
                markdown_lines.append(lines[i])
                i += 1
            i += 1

            html_lines: list[str] = []
            while i < len(lines) and lines[i] != EXAMPLE_END:
                html_lines.append(lines[i])
                i += 1
            i += 1

            section = " / ".join(section_stack[-2:]) if section_stack else "Unknown"
            examples.append(
                Example(
                    number=example_number,
                    section=section,
                    markdown="\n".join(markdown_lines),
                    expected_html="\n".join(html_lines).strip(),
                )
            )
            continue

        i += 1

    return examples


def is_basic_example(example: Example) -> bool:
    section = example.section.lower()
    return any(keyword in section for keyword in BASIC_SECTION_KEYWORDS)


def ensure_binary(repo_root: Path) -> None:
    subprocess.run(["make", "cobdown"], cwd=repo_root, check=True)


def extract_body_html(document_text: str) -> str:
    match = re.search(r"<body>\n?(.*)\n?</body>", document_text, flags=re.DOTALL)
    if not match:
        return document_text.strip()
    return match.group(1).strip()


def normalize_html_block(text: str) -> str:
    return text.strip().replace("\r\n", "\n").replace("\r", "\n")


def run_cobdown(repo_root: Path, markdown_text: str) -> str:
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp_path = Path(tmpdir)
        md_path = tmp_path / "example.md"
        html_path = tmp_path / "example.html"
        md_path.write_text(markdown_text, encoding="utf-8")

        proc = subprocess.run(
            [str(repo_root / "cobdown")],
            input=f"{md_path}\n{html_path}\n",
            text=True,
            capture_output=True,
            cwd=repo_root,
            check=True,
        )
        _ = proc.stdout

        return extract_body_html(html_path.read_text(encoding="utf-8"))


def write_failure_artifacts(out_dir: Path, example: Example, actual_html: str) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    stem = f"example-{example.number:04d}"
    (out_dir / f"{stem}.md").write_text(example.markdown, encoding="utf-8")
    (out_dir / f"{stem}.expected.html").write_text(example.expected_html, encoding="utf-8")
    (out_dir / f"{stem}.actual.html").write_text(actual_html, encoding="utf-8")
    (out_dir / f"{stem}.meta.json").write_text(
        json.dumps(
            {
                "example": example.number,
                "section": example.section,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Benchmark cobdown against the official CommonMark spec examples."
    )
    parser.add_argument(
        "--repo-root",
        default=Path(__file__).resolve().parents[1],
        type=Path,
        help="Repository root containing cobdown.cob and the built cobdown binary.",
    )
    parser.add_argument(
        "--spec",
        default=Path(__file__).resolve().parents[1] / "third_party" / "commonmark" / "spec.txt",
        type=Path,
        help="Path to the official CommonMark spec.txt file.",
    )
    parser.add_argument(
        "--basic-only",
        action="store_true",
        help="Run only examples from sections that map to basic Markdown syntax.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Limit the number of examples run. 0 means run all selected examples.",
    )
    parser.add_argument(
        "--write-failures-dir",
        type=Path,
        default=None,
        help="Directory where failing example artifacts should be written.",
    )
    parser.add_argument(
        "--show-failures",
        type=int,
        default=10,
        help="How many failing examples to print in the console summary.",
    )
    args = parser.parse_args()

    repo_root = args.repo_root.resolve()
    spec_path = args.spec.resolve()

    ensure_binary(repo_root)

    examples = parse_spec_examples(spec_path.read_text(encoding="utf-8"))
    if args.basic_only:
        examples = [example for example in examples if is_basic_example(example)]
    if args.limit > 0:
        examples = examples[: args.limit]

    if not examples:
        print("No CommonMark examples selected.", file=sys.stderr)
        return 1

    failures: list[tuple[Example, str]] = []
    section_totals: dict[str, dict[str, int]] = {}

    for example in examples:
        actual_html = normalize_html_block(run_cobdown(repo_root, example.markdown))
        expected_html = normalize_html_block(example.expected_html)
        section_totals.setdefault(example.section, {"total": 0, "passed": 0})
        section_totals[example.section]["total"] += 1

        if actual_html == expected_html:
            section_totals[example.section]["passed"] += 1
            continue

        failures.append((example, actual_html))
        if args.write_failures_dir:
            write_failure_artifacts(args.write_failures_dir, example, actual_html)

    total = len(examples)
    failed = len(failures)
    passed = total - failed
    rate = (passed / total) * 100.0

    print(f"Examples run: {total}")
    print(f"Passed:       {passed}")
    print(f"Failed:       {failed}")
    print(f"Pass rate:    {rate:.2f}%")
    print()
    print("Section summary:")
    for section in sorted(section_totals):
        sec_total = section_totals[section]["total"]
        sec_passed = section_totals[section]["passed"]
        sec_rate = (sec_passed / sec_total) * 100.0
        print(f"- {section}: {sec_passed}/{sec_total} ({sec_rate:.1f}%)")

    if failures:
        print()
        print("Sample failures:")
        for example, actual_html in failures[: args.show_failures]:
            print(f"- Example {example.number} [{example.section}]")
            print(f"  Markdown: {example.markdown[:80]!r}")
            print(f"  Expected: {example.expected_html[:120]!r}")
            print(f"  Actual:   {actual_html[:120]!r}")

    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
