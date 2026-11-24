// Reduce an MDX document to the Markdown prose LTeX+ should check.
//
// LTeX+ reads MDX with a CommonMark parser: ESM and {expressions} look like
// prose, and component children look like raw HTML and are skipped.  This
// parses MDX 3 with remark-mdx and returns text with the same lines where
// ESM, expressions and component tags are blanked, inline components become
// inline code (a dummy word for LTeX+), and the indentation that components
// add to their children is removed.  `strip[line]` is the number of
// characters removed from the start of that line, to map columns back.
import { unified } from "unified";
import remarkParse from "remark-parse";
import remarkMdx from "remark-mdx";
import remarkFrontmatter from "remark-frontmatter";
import remarkGfm from "remark-gfm";

const parser = unified()
  .use(remarkParse)
  .use(remarkFrontmatter, ["yaml", "toml"])
  .use(remarkGfm);

export function parseMdx(text) {
  return mdxParser.parse(text);
}

const mdxParser = parser().use(remarkMdx);
export const parseMarkdown = (text) => parser.parse(text);

export function mask(text) {
  const tree = parseMdx(text);
  const chars = text.split(""); // UTF-16 code units, like LSP columns
  const indent = []; // per line: indentation added by enclosing components

  const blank = (start, end) => {
    for (let i = start; i < end; i++) if (chars[i] !== "\n" && chars[i] !== "\r") chars[i] = " ";
  };
  const dummy = (start, end) => {
    if (end - start < 2 || text.slice(start, end).includes("\n")) return blank(start, end);
    chars[start] = chars[end - 1] = "`";
    for (let i = start + 1; i < end - 1; i++) chars[i] = "x";
  };

  const visit = (node) => {
    const { start, end } = node.position ?? {};
    switch (node.type) {
      case "mdxjsEsm":
      case "mdxFlowExpression":
        return blank(start.offset, end.offset);
      case "mdxTextExpression":
      case "mdxJsxTextElement":
        return dummy(start.offset, end.offset);
      case "mdxJsxFlowElement": {
        const first = node.children[0]?.position;
        const last = node.children.at(-1)?.position;
        if (!first) return blank(start.offset, end.offset);
        blank(start.offset, first.start.offset);
        blank(last.end.offset, end.offset);
        const added = Math.max(0, first.start.column - start.column);
        for (let line = first.start.line - 1; line < last.end.line; line++) {
          indent[line] = (indent[line] ?? 0) + added;
        }
        break;
      }
    }
    for (const child of node.children ?? []) visit(child);
  };
  visit(tree);

  const strip = [];
  const lines = chars.join("").split("\n").map((line, i) => {
    const n = Math.min(indent[i] ?? 0, line.length - line.trimStart().length);
    strip[i] = n;
    return line.slice(n);
  });
  return { text: lines.join("\n"), strip };
}
