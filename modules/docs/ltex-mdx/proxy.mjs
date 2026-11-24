// LSP proxy in front of ltex-ls-plus:
// - MDX documents reach LTeX+ as their Markdown prose only (see mask.mjs);
//   positions in its replies are mapped back to the original text.
// - Spelling errors from non-English spell checkers are dropped when the
//   word is correct English: German pages name English UI labels, buttons
//   and product terms.
//
// Usage: node proxy.mjs <ltex-ls-plus> [args...]
import { spawn } from "node:child_process";
import dictionaryEn from "dictionary-en";
import nspell from "nspell";
import { mask } from "./mask.mjs";

const english = nspell(dictionaryEn);
// Spelling rules of other languages: GERMAN_SPELLER_RULE, MORFOLOGIK_RULE_<lang>.
const foreignSpelling = /^(?!MORFOLOGIK_RULE_EN_)(?:\w*SPELLER_RULE|MORFOLOGIK_RULE_\w+)$/;

const [command, ...args] = process.argv.slice(2);
const server = spawn(command, args, { stdio: ["pipe", "pipe", "inherit"] });
server.on("exit", (code, signal) => process.exit(code ?? (signal ? 1 : 0)));
process.stdin.on("end", () => server.stdin.end());

const docs = new Map(); // uri -> { text, strip, mdx }
const pending = new Map(); // id of a client request about an MDX document -> uri

function read(stream, onMessage) {
  let buffer = Buffer.alloc(0);
  stream.on("data", (chunk) => {
    buffer = Buffer.concat([buffer, chunk]);
    for (;;) {
      const headerEnd = buffer.indexOf("\r\n\r\n");
      if (headerEnd < 0) return;
      const length = Number(/Content-Length: *(\d+)/i.exec(buffer.subarray(0, headerEnd))[1]);
      const start = headerEnd + 4;
      if (buffer.length < start + length) return;
      onMessage(JSON.parse(buffer.subarray(start, start + length).toString("utf8")));
      buffer = buffer.subarray(start + length);
    }
  });
}

function write(stream, message) {
  const body = Buffer.from(JSON.stringify(message), "utf8");
  stream.write(`Content-Length: ${body.length}\r\n\r\n`);
  stream.write(body);
}

function masked(text) {
  try {
    return mask(text);
  } catch {
    return { text, strip: [] }; // invalid MDX while typing: check it unmasked
  }
}

// Offset of an LSP position (UTF-16 columns, like JS strings) in TEXT.
function offsetAt(text, { line, character }) {
  let offset = 0;
  for (let i = 0; i < line; i++) offset = text.indexOf("\n", offset) + 1;
  return offset + character;
}

// Remember URI's TEXT and return what LTeX+ should see instead.
function update(uri, text, mdx) {
  const result = mdx ? masked(text) : { text, strip: [] };
  docs.set(uri, { text, strip: result.strip, mdx });
  return result.text;
}

// Whether DIAGNOSTIC is a foreign-language spelling error on an English word.
function englishWord(diagnostic, lines) {
  const { start, end } = diagnostic.range;
  if (!foreignSpelling.test(diagnostic.code) || start.line !== end.line) return false;
  const word = lines[start.line]?.slice(start.character, end.character) ?? "";
  return /^[\p{L}'’]+$/u.test(word) && english.correct(word);
}

const toServer = (strip) => (p) => ({ line: p.line, character: Math.max(0, p.character - (strip[p.line] ?? 0)) });
const toClient = (strip) => (p) => ({ line: p.line, character: p.character + (strip[p.line] ?? 0) });

// Map every { start, end } range below VALUE.
function mapRanges(value, map) {
  if (Array.isArray(value)) return value.map((v) => mapRanges(v, map));
  if (!value || typeof value !== "object") return value;
  const out = {};
  for (const [key, v] of Object.entries(value)) out[key] = mapRanges(v, map);
  if (out.start?.line !== undefined && out.end?.line !== undefined) {
    out.start = map(out.start);
    out.end = map(out.end);
  }
  return out;
}

read(process.stdin, (message) => {
  const { method, params } = message;
  const uri = params?.textDocument?.uri;
  if (method === "textDocument/didOpen") {
    const { languageId, text } = params.textDocument;
    params.textDocument.text = update(uri, text, languageId === "mdx" || uri.endsWith(".mdx"));
  } else if (method === "textDocument/didChange" && docs.has(uri)) {
    let { text, mdx } = docs.get(uri);
    for (const change of params.contentChanges) {
      text = change.range
        ? text.slice(0, offsetAt(text, change.range.start)) + change.text + text.slice(offsetAt(text, change.range.end))
        : change.text;
    }
    params.contentChanges = [{ text: update(uri, text, mdx) }];
  } else if (method === "textDocument/didClose") {
    docs.delete(uri);
  } else if (method && message.id !== undefined && docs.has(uri)) {
    message.params = mapRanges(params, toServer(docs.get(uri).strip));
    pending.set(message.id, uri);
  }
  write(server.stdin, message);
});

read(server.stdout, (message) => {
  if (message.method === "textDocument/publishDiagnostics" && docs.has(message.params.uri)) {
    const doc = docs.get(message.params.uri);
    const lines = doc.text.split("\n");
    message.params = mapRanges(message.params, toClient(doc.strip));
    message.params.diagnostics = message.params.diagnostics.filter((d) => !englishWord(d, lines));
  } else if (!message.method && pending.has(message.id)) {
    const uri = pending.get(message.id);
    pending.delete(message.id);
    if (docs.has(uri)) message.result = mapRanges(message.result, toClient(docs.get(uri).strip));
  }
  write(process.stdout, message);
});
