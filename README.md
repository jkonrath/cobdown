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
