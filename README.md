# Cobdown

`Cobdown` is a COBOL 85-style Markdown-to-HTML converter intended to compile with `GnuCOBOL`.

It reads a Markdown file path from standard input, reads an output HTML path from standard input, and writes a complete HTML document.

Yes this is a stupid idea.

## Build

```sh
make
```

Or directly:

```sh
cobc -x -free -o cobdown cobdown.cob
```

## Run

```sh
./cobdown
```

When prompted, enter:

1. The input Markdown file path
2. The output HTML file path

## Supported basic Markdown syntax

- ATX headings: `# Heading`
- Setext headings:

  ```md
  Heading
  -------
  ```

- Paragraphs
- Hard line breaks using two trailing spaces or a trailing backslash
- Italic and bold emphasis with `*`, `_`, `**`, and `__`
- Blockquotes, including nested blockquotes
- Unordered lists with `-`, `*`, and `+`
- Ordered lists with `1.`
- Inline code with backticks
- Indented code blocks
- Horizontal rules with `---`, `***`, or `___`
- Links: `[text](url)`
- Images: `![alt](url)`
- Backslash escaping for inline punctuation

## Sample

```sh
make run-sample
```

That converts [`sample.md`](/Users/jkonrath/Documents/GitHub/cobdown/sample.md) into [`sample.html`](/Users/jkonrath/Documents/GitHub/cobdown/sample.html).

## CommonMark benchmark

The repo contains the official CommonMark spec source at [`third_party/commonmark/spec.txt`](/Users/jkonrath/Documents/GitHub/cobdown/third_party/commonmark/spec.txt) and includes a benchmark harness at [`scripts/benchmark_commonmark.py`](/Users/jkonrath/Documents/GitHub/cobdown/scripts/benchmark_commonmark.py).

Run the full CommonMark example suite:

```sh
make benchmark-commonmark
```

Run only the sections that correspond most closely to basic Markdown syntax:

```sh
make benchmark-commonmark-basic
```

Failure artifacts are written under `benchmark-results/` as:

- the example Markdown input
- the expected CommonMark HTML
- the actual `cobdown` HTML
- a small metadata file with the example number and section

## TODO

* Make this a callable subprogram so another COBOL program could call it. (Accept input and output paths in LINKAGE SECTION instead of interactively; GOBACK instead of STOP RUN, etc.) Maybe write it as a subprogram and then have a simple test program that calls it and as a subprogram so it doesn't have to do both interactive and noninteractive.
