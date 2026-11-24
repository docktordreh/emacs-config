import { readFileSync } from "node:fs";
import { parseMarkdown, parseMdx } from "./mask.mjs";

const text = readFileSync(0, "utf8");
const markdown = process.argv.includes("--markdown");
const lines = text.split("\n");
const ranges = [];
let lastEsmEnd;
const column = ({ line, column }) => [...lines[line - 1].slice(0, column - 1)].length;

function visit(node, depth = 0) {
  const block = node.type === "mdxJsxFlowElement";
  const inline = node.type === "mdxJsxTextElement";
  const kind = markdown ? (node.type === "html" ? "html" : null) :
    block ? "block" : inline ? "inline" :
    node.type === "mdxjsEsm" ? "esm" : node.type === "yaml" ? "yaml" : null;
  if (kind) {
    const { start, end } = node.position;
    // Blank lines between successive declarations belong to the import block.
    if (kind === "esm" && lastEsmEnd !== undefined &&
        !text.slice(lastEsmEnd, start.offset).trim()) {
      ranges.at(-1).splice(3, 2, end.line, column(end));
    } else {
      ranges.push([kind, start.line, column(start), end.line, column(end), depth]);
    }
    lastEsmEnd = kind === "esm" ? end.offset : undefined;
  }
  for (const child of node.children ?? []) visit(child, depth + Number(block || inline));
}

try {
  visit((markdown ? parseMarkdown : parseMdx)(text));
  console.log(JSON.stringify(ranges));
} catch {
  // Incomplete JSX while typing: keep the previous preview until it parses.
  process.exitCode = 1;
}
