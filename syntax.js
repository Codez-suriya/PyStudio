/* ==========================================================================
   PyStudio — Python syntax highlighting (no libraries)
   How it works: a colored <pre> sits behind the transparent <textarea>.
   You still type in the real textarea, so caret, selection, undo, mobile
   keyboards and your existing run/clear code keep working unchanged.
   ========================================================================== */
(function (root) {
    "use strict";

    /* ---------- Tokenizer ---------- */
    const KEYWORDS = new Set([
        "and", "as", "assert", "async", "await", "break", "class", "continue",
        "def", "del", "elif", "else", "except", "finally", "for", "from",
        "global", "if", "import", "in", "is", "lambda", "nonlocal", "not",
        "or", "pass", "raise", "return", "try", "while", "with", "yield"
    ]);
    const CONSTANTS = new Set(["True", "False", "None"]);
    const BUILTINS = new Set([
        "abs", "all", "any", "bin", "bool", "bytes", "callable", "chr", "dict",
        "dir", "divmod", "enumerate", "eval", "filter", "float", "format",
        "frozenset", "getattr", "hasattr", "hash", "hex", "id", "input", "int",
        "isinstance", "issubclass", "iter", "len", "list", "map", "max", "min",
        "next", "object", "oct", "open", "ord", "pow", "print", "range", "repr",
        "reversed", "round", "set", "setattr", "slice", "sorted", "str", "sum",
        "super", "tuple", "type", "vars", "zip",
        "Exception", "ValueError", "TypeError", "KeyError", "IndexError",
        "ZeroDivisionError", "RuntimeError", "StopIteration"
    ]);

    // Groups: 1 comment | 2 triple string | 3 string | 4 decorator | 5 number | 6 word | 7 operator
    const TOKEN_RE = new RegExp([
        /(#[^\n]*)/,
        /((?:[rRbBuUfF]{1,2})?(?:'''[\s\S]*?(?:'''|$)|"""[\s\S]*?(?:"""|$)))/,
        /((?:[rRbBuUfF]{1,2})?(?:'(?:\\.|[^'\\\n])*'?|"(?:\\.|[^"\\\n])*"?))/,
        /(@[A-Za-z_][\w.]*)/,
        /(0[xX][\da-fA-F_]+|0[bB][01_]+|0[oO][0-7_]+|(?:\d[\d_]*\.?[\d_]*|\.\d[\d_]*)(?:[eE][+-]?\d+)?[jJ]?)/,
        /([A-Za-z_]\w*)/,
        /([+\-*\/%=<>!&|^~]+)/
    ].map(r => r.source).join("|"), "g");

    const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    const span = (cls, s) => `<span class="tok-${cls}">${esc(s)}</span>`;

    function stringHtml(text) {
        const prefix = text.match(/^[A-Za-z]*/)[0];
        if (!/f/i.test(prefix)) return span("string", text);

        // f-strings: show {expressions} in their own color ({{ and }} are literal braces)
        const body = esc(text).replace(/\{\{|\}\}|\{[^{}\n]*\}/g, m =>
            (m === "{{" || m === "}}")
                ? m
                : `</span><span class="tok-interp">${m}</span><span class="tok-string">`
        );
        return `<span class="tok-string">${body}</span>`;
    }

    function wordHtml(word, start, end, src) {
        if (CONSTANTS.has(word)) return span("const", word);
        if (KEYWORDS.has(word)) return span("keyword", word);

        const before = src.slice(Math.max(0, start - 12), start);
        if (/\bdef\s+$/.test(before)) return span("func", word);
        if (/\bclass\s+$/.test(before)) return span("class", word);

        const isAttr = src.charAt(start - 1) === ".";
        const isCall = /^[ \t]*\(/.test(src.slice(end, end + 8));

        if (!isAttr && BUILTINS.has(word)) return span("builtin", word);
        if (word === "self" || word === "cls") return span("self", word);
        if (isCall) return span("func", word);
        return esc(word);
    }

    function highlight(src) {
        let out = "";
        let last = 0;
        let m;
        TOKEN_RE.lastIndex = 0;

        while ((m = TOKEN_RE.exec(src)) !== null) {
            if (m[0] === "") { TOKEN_RE.lastIndex++; continue; }

            out += esc(src.slice(last, m.index));
            const end = m.index + m[0].length;

            if (m[1] !== undefined) out += span("comment", m[0]);
            else if (m[2] !== undefined || m[3] !== undefined) out += stringHtml(m[0]);
            else if (m[4] !== undefined) out += span("decorator", m[0]);
            else if (m[5] !== undefined) out += span("number", m[0]);
            else if (m[6] !== undefined) out += wordHtml(m[0], m.index, end, src);
            else out += span("operator", m[0]);

            last = end;
        }

        return out + esc(src.slice(last));
    }

    root.PyHighlight = { highlight };

    if (typeof document === "undefined") return; // allows testing in Node

    /* ---------- Editor overlay ---------- */
    function init() {
        const editor = document.getElementById("python-code");
        if (!editor || editor.closest(".code-editor")) return;

        const wrap = document.createElement("div");
        wrap.className = "code-editor";

        const pre = document.createElement("pre");
        pre.className = "code-highlight";
        pre.setAttribute("aria-hidden", "true");

        editor.parentNode.insertBefore(wrap, editor);
        wrap.append(pre, editor);
        editor.setAttribute("wrap", "off");

        const lineCount = document.getElementById("line-count");

        function sync() {
            pre.scrollTop = editor.scrollTop;
            pre.scrollLeft = editor.scrollLeft;
        }

        function render() {
            const value = editor.value;
            pre.innerHTML = highlight(value) + "\n"; // trailing newline keeps last line height in sync
            if (lineCount) lineCount.textContent = "Lines: " + value.split("\n").length;
            sync();
        }

        // Re-render when other code sets editor.value (Clear, New File, examples...)
        const desc = Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, "value");
        Object.defineProperty(editor, "value", {
            configurable: true,
            get() { return desc.get.call(this); },
            set(v) { desc.set.call(this, v); render(); }
        });

        editor.addEventListener("input", render);
        editor.addEventListener("scroll", sync);
        window.addEventListener("resize", sync);

        /* ----- Friendly typing: Tab indent + auto-indent (keeps Ctrl+Z working) ----- */
        let tabTrap = true; // press Esc, then Tab, to move focus out of the editor

        function insert(text) {
            editor.focus();
            if (!document.execCommand("insertText", false, text)) {
                editor.setRangeText(text, editor.selectionStart, editor.selectionEnd, "end");
                editor.dispatchEvent(new Event("input", { bubbles: true }));
            }
        }

        function lineStart(v, pos) {
            return pos === 0 ? 0 : v.lastIndexOf("\n", pos - 1) + 1;
        }

        function indentSelection(outdent) {
            const v = editor.value;
            const s = editor.selectionStart;
            const e = editor.selectionEnd;
            const multiLine = v.slice(s, e).includes("\n");

            if (!outdent && !multiLine) {
                const col = s - lineStart(v, s);
                insert(" ".repeat(4 - (col % 4)));
                return;
            }

            const start = lineStart(v, s);
            let end = v.indexOf("\n", e > s && v[e - 1] === "\n" ? e - 1 : e);
            if (end === -1) end = v.length;

            let firstDelta = 0;
            let total = 0;
            const lines = v.slice(start, end).split("\n").map((line, i) => {
                let delta = 0;
                if (outdent) {
                    delta = -(line.match(/^ {1,4}/) || [""])[0].length;
                    line = line.slice(-delta);
                } else if (line.trim() !== "") {
                    delta = 4;
                    line = "    " + line;
                }
                if (i === 0) firstDelta = delta;
                total += delta;
                return line;
            });

            editor.setSelectionRange(start, end);
            insert(lines.join("\n"));
            editor.setSelectionRange(Math.max(start, s + firstDelta), e + total);
        }

        editor.addEventListener("keydown", event => {
            if (event.ctrlKey || event.metaKey || event.altKey) return;

            if (event.key === "Escape") { tabTrap = false; return; }

            if (event.key === "Tab" && tabTrap) {
                event.preventDefault();
                indentSelection(event.shiftKey);
                return;
            }

            if (event.key === "Enter" && !event.shiftKey) {
                const v = editor.value;
                const s = editor.selectionStart;
                const before = v.slice(lineStart(v, s), s);
                const indent = before.match(/^[ \t]*/)[0];
                const extra = /:\s*(#.*)?$/.test(before) ? "    " : "";
                if (indent || extra) {
                    event.preventDefault();
                    insert("\n" + indent + extra);
                }
            }
        });

        editor.addEventListener("blur", () => { tabTrap = true; });

        render();
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", init);
    } else {
        init();
    }
})(typeof window !== "undefined" ? window : globalThis);
