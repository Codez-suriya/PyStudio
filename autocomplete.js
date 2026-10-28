/* ==========================================================================
   PyStudio — autocomplete (no libraries)
   Works with the textarea + highlight overlay from syntax.js.

   Suggests: snippets, keywords, builtins, names defined in your code,
   module members (after `math.`), methods (after `name.` / `"str".`),
   and module names after `import` / `from x import`.

   Keys:  Up/Down = move   Tab/Enter = accept   Esc = close   Ctrl+Space = open
   ========================================================================== */
(function () {
    "use strict";

    /* ---------- Data ---------- */
    const KEYWORDS = ("and as assert async await break class continue def del elif else except " +
        "finally for from global if import in is lambda nonlocal not or pass raise return try " +
        "while with yield True False None").split(" ");

    const BUILTINS = ("abs all any bin bool bytes callable chr dict dir divmod enumerate eval filter " +
        "float format frozenset getattr hasattr hash hex id input int isinstance issubclass iter len " +
        "list map max min next object oct open ord pow print range repr reversed round set setattr " +
        "slice sorted str sum super tuple type vars zip " +
        "Exception ValueError TypeError KeyError IndexError ZeroDivisionError RuntimeError " +
        "StopIteration AttributeError NameError").split(" ");

    // label, text to insert ($0 = cursor), short description
    const SNIPPETS = [
        ["def",    "def $0():\n    pass",                      "function"],
        ["class",  "class $0:\n    def __init__(self):\n        pass", "class"],
        ["for",    "for $0 in range():\n    pass",              "for loop"],
        ["while",  "while $0:\n    pass",                       "while loop"],
        ["if",     "if $0:\n    pass",                          "if block"],
        ["elif",   "elif $0:\n    pass",                        "elif block"],
        ["else",   "else:\n    $0",                             "else block"],
        ["try",    "try:\n    $0\nexcept Exception as e:\n    print(e)", "try / except"],
        ["with",   "with open($0) as f:\n    pass",              "with open"],
        ["main",   "if __name__ == \"__main__\":\n    $0",       "main guard"],
        ["lambda", "lambda $0: ",                               "lambda"]
    ];
    const SNIPPET_LABELS = new Set(SNIPPETS.map(s => s[0]));

    const STR_M = ("capitalize casefold center count encode endswith find format index isalnum isalpha " +
        "isdigit islower isnumeric isspace isupper join ljust lower lstrip partition replace rfind " +
        "rjust rpartition rsplit rstrip split splitlines startswith strip swapcase title upper zfill").split(" ");
    const LIST_M = "append clear copy count extend index insert pop remove reverse sort".split(" ");
    const DICT_M = "clear copy fromkeys get items keys pop popitem setdefault update values".split(" ");
    const SET_M  = ("add clear copy difference discard intersection isdisjoint issubset issuperset " +
        "pop remove symmetric_difference union update").split(" ");
    const TUPLE_M = "count index".split(" ");
    const FILE_M = "close flush read readline readlines seek tell write writelines".split(" ");

    const TYPE_METHODS = { str: STR_M, list: LIST_M, dict: DICT_M, set: SET_M, tuple: TUPLE_M, file: FILE_M };

    const MODULES = {
        math: "ceil comb cos degrees e exp fabs factorial floor gcd hypot inf isclose isqrt log log10 log2 pi pow radians sin sqrt tan tau trunc".split(" "),
        random: "choice choices randint random randrange sample seed shuffle uniform".split(" "),
        time: "ctime monotonic perf_counter sleep strftime time".split(" "),
        datetime: "date datetime timedelta timezone".split(" "),
        json: "dump dumps load loads".split(" "),
        re: "IGNORECASE MULTILINE compile findall finditer fullmatch match search split sub".split(" "),
        string: "ascii_letters ascii_lowercase ascii_uppercase digits punctuation whitespace".split(" "),
        collections: "Counter OrderedDict defaultdict deque namedtuple".split(" "),
        itertools: "accumulate chain combinations count cycle groupby permutations product repeat zip_longest".split(" "),
        functools: "lru_cache partial reduce wraps".split(" "),
        statistics: "mean median mode pstdev stdev variance".split(" "),
        sys: "argv exit maxsize path platform version".split(" "),
        os: "getcwd listdir path sep".split(" "),
        textwrap: "dedent fill indent shorten wrap".split(" ")
    };
    const MODULE_NAMES = Object.keys(MODULES);

    /* ---------- Context scanning ---------- */

    // Returns "code" | "string" | "comment" for the position at the end of `text`.
    function stateAt(text) {
        let i = 0;
        const n = text.length;
        while (i < n) {
            const c = text[i];
            if (c === "#") {
                const nl = text.indexOf("\n", i);
                if (nl === -1) return "comment";
                i = nl + 1;
                continue;
            }
            if (c === "'" || c === '"') {
                const triple = text.substr(i, 3) === c.repeat(3);
                if (triple) {
                    const close = text.indexOf(c.repeat(3), i + 3);
                    if (close === -1) return "string";
                    i = close + 3;
                    continue;
                }
                i++;
                while (i < n && text[i] !== c && text[i] !== "\n") {
                    if (text[i] === "\\") i++;
                    i++;
                }
                if (i >= n) return "string";      // unterminated on current line
                i++;                               // closing quote (or newline)
                continue;
            }
            i++;
        }
        return "code";
    }

    // Names the user defined: assignments, def, class, imports, for-targets, params.
    function collectLocals(src) {
        const out = new Map();
        const add = (name, kind) => {
            if (name && !KEYWORDS.includes(name) && !out.has(name)) out.set(name, kind);
        };
        let m;
        const re = {
            def:   /\bdef\s+([A-Za-z_]\w*)\s*\(([^)]*)\)/g,
            cls:   /\bclass\s+([A-Za-z_]\w*)/g,
            asg:   /^[ \t]*([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)\s*(?:[-+*\/%|&^]|\/\/|\*\*)?=(?!=)/gm,
            loop:  /\bfor\s+([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)\s+in\b/g,
            imp:   /^[ \t]*import\s+([^\n#]+)/gm,
            from:  /^[ \t]*from\s+[\w.]+\s+import\s+([^\n#]+)/gm,
            as_:   /\bas\s+([A-Za-z_]\w*)/g
        };
        while ((m = re.def.exec(src))) {
            add(m[1], "function");
            m[2].split(",").forEach(p => add(p.trim().split(/[=:\s]/)[0].replace(/^\*+/, ""), "variable"));
        }
        while ((m = re.cls.exec(src))) add(m[1], "class");
        while ((m = re.asg.exec(src))) m[1].split(",").forEach(n => add(n.trim(), "variable"));
        while ((m = re.loop.exec(src))) m[1].split(",").forEach(n => add(n.trim(), "variable"));
        while ((m = re.imp.exec(src))) m[1].split(",").forEach(p => add(p.trim().split(/\s+as\s+/).pop().split(".")[0], "module"));
        while ((m = re.from.exec(src))) m[1].split(",").forEach(p => add(p.trim().split(/\s+as\s+/).pop(), "variable"));
        while ((m = re.as_.exec(src))) add(m[1], "variable");
        return out;
    }

    // `import random as r` -> { r: "random" }, `import math` -> { math: "math" }
    function importAliases(src) {
        const map = {};
        const re = /^[ \t]*import\s+([^\n#]+)/gm;
        let m;
        while ((m = re.exec(src))) {
            m[1].split(",").forEach(part => {
                const [mod, alias] = part.trim().split(/\s+as\s+/);
                if (mod) map[alias || mod.split(".")[0]] = mod.split(".")[0];
            });
        }
        return map;
    }

    // Guess the type of the thing before the dot.
    function inferType(src, head) {
        const trimmed = head.trimEnd();
        const last = trimmed.slice(-1);
        if (last === '"' || last === "'") return "str";
        if (last === "]") return "list";
        if (last === "}") return /:/.test(trimmed.slice(trimmed.lastIndexOf("{"))) ? "dict" : "set";
        if (last === ")") {
            const call = trimmed.match(/([A-Za-z_]\w*)\([^()]*\)$/);
            if (call) return typeFromCall(call[1]);
            return null;
        }
        const name = (trimmed.match(/([A-Za-z_]\w*)$/) || [])[1];
        if (!name) return null;

        // use the most recent assignment to that name
        const re = new RegExp("^[ \\t]*" + name + "\\s*=(?!=)\\s*([^\\n#]*)", "gm");
        let m, rhs = null;
        while ((m = re.exec(src))) rhs = m[1].trim();
        const w = new RegExp("\\bwith\\s+open\\([^)]*\\)\\s+as\\s+" + name + "\\b");
        if (w.test(src)) return "file";
        if (rhs === null) return null;
        if (/^[rbuf]{0,2}("|')/i.test(rhs)) return "str";
        if (/^\[/.test(rhs)) return "list";
        if (/^\{/.test(rhs)) return /^\{\s*\}|:/.test(rhs) ? "dict" : "set";
        if (/^\(/.test(rhs)) return "tuple";
        const call = rhs.match(/^([A-Za-z_]\w*)\(/);
        if (call) return typeFromCall(call[1]);
        return null;
    }

    function typeFromCall(fn) {
        return ({ str: "str", input: "str", list: "list", sorted: "list", dict: "dict",
                  set: "set", tuple: "tuple", open: "file" })[fn] || null;
    }

    /* ---------- Suggestion engine ---------- */

    function rank(items, prefix) {
        if (!prefix) return items;
        const p = prefix.toLowerCase();
        const scored = [];
        for (const item of items) {
            const l = item.label.toLowerCase();
            let s;
            if (item.label.startsWith(prefix)) s = 0;
            else if (l.startsWith(p)) s = 1;
            else if (l.includes(p)) s = 2;
            else continue;
            scored.push([s + (item.weight || 0), item]);
        }
        scored.sort((a, b) => a[0] - b[0] || a[1].label.length - b[1].label.length ||
                              a[1].label.localeCompare(b[1].label));
        return scored.map(x => x[1]);
    }

    function members(names, kind, detail) {
        return names.map(n => ({ label: n, kind, detail, insert: n }));
    }

    function getSuggestions(text, caret, forced) {
        const before = text.slice(0, caret);
        if (stateAt(before) !== "code") return null;

        const lineStart = before.lastIndexOf("\n") + 1;
        const line = before.slice(lineStart);
        const prefixMatch = line.match(/[A-Za-z_]\w*$/);
        const prefix = prefixMatch ? prefixMatch[0] : "";
        const start = caret - prefix.length;
        const head = line.slice(0, line.length - prefix.length);
        const src = text;

        let items;

        // import x / from x import y
        const fromImp = head.match(/^\s*from\s+(\w+)\s+import\s+(?:[\w\s,]*,\s*)?$/);
        if (fromImp) {
            const list = MODULES[fromImp[1]];
            items = list ? members(list, "function", fromImp[1]) : [];
        } else if (/^\s*(?:from|import)\s+(?:[\w\s,.]*,\s*)?$/.test(head) && /(?:^|\s)(?:import|from)\s+(?:[\w\s,.]*,\s*)?$/.test(head)) {
            items = members(MODULE_NAMES, "module", "module");
        }
        // attribute access: something.<prefix>
        else if (head.endsWith(".") && !/\d\.$/.test(head)) {
            const objText = head.slice(0, -1);
            const name = (objText.match(/([A-Za-z_]\w*)$/) || [])[1];
            const aliases = importAliases(src);

            if (name && aliases[name] && MODULES[aliases[name]] && !/\.\s*$/.test(objText.slice(0, -name.length))) {
                items = members(MODULES[aliases[name]], "function", aliases[name]);
            } else {
                const type = inferType(src, objText);
                if (type) {
                    items = members(TYPE_METHODS[type], "method", type);
                } else {
                    const seen = new Set();
                    items = [];
                    for (const [t, list] of Object.entries(TYPE_METHODS)) {
                        for (const n of list) {
                            if (!seen.has(n)) { seen.add(n); items.push({ label: n, kind: "method", detail: t, insert: n }); }
                        }
                    }
                }
            }
        }
        // plain identifier
        else {
            if (!prefix && !forced) return null;
            // don't pop up while typing a number like 3x or after def/class names
            if (/\b(?:def|class)\s+$/.test(head)) return null;
            if (/\d$/.test(head) && prefix === "") return null;

            const locals = collectLocals(src);

            // Keep declared functions and classes available even
            // when the typed prefix matches their complete name.
            if (!["function", "class"].includes(locals.get(prefix))) {
                locals.delete(prefix);
            }

            items = [];

            
            for (const [name, kind] of locals) {
                items.push({ label: name, kind, detail: kind, insert: name, weight: -0.5 });
            }
            for (const s of SNIPPETS) {
                items.push({ label: s[0], kind: "snippet", detail: s[2], insert: s[1], weight: 0.1 });
            }
            for (const k of KEYWORDS) {
                if (SNIPPET_LABELS.has(k)) continue;
                items.push({ label: k, kind: "keyword", detail: "keyword", insert: k, weight: 0.2 });
            }
            for (const b of BUILTINS) {
                const isCallable = /^[a-z]/.test(b) || /Error$|Exception$/.test(b);
                items.push({ label: b, kind: "builtin", detail: "builtin", insert: b, call: isCallable, weight: 0.3 });
            }
            for (const [name, kind] of locals) {
                const it = items.find(i => i.label === name);
                if (it && kind === "function") it.call = true;
                if (it && kind === "class") it.call = true;
            }
            // snippets only make sense at the start of a statement
            if (head.trim() !== "") items = items.filter(i => i.kind !== "snippet");
            else {
                // keep keywords that have snippets from showing twice, already handled above
            }
            // modules in `import` already covered; module names usable in code
            for (const [name, kind] of locals) { void name; void kind; }
        }

        const ranked = rank(items, prefix);
        // mark calls for member functions
        ranked.forEach(i => { if (i.kind === "method" || (i.kind === "function" && i.detail && MODULES[i.detail])) i.call = !/^[A-Z_]+$|^(pi|e|tau|inf|argv|path|sep|version|platform|maxsize|digits|ascii_\w+|punctuation|whitespace)$/.test(i.label); });

        if (!ranked.length) return null;
        if (ranked.length === 1 && ranked[0].label === prefix && ranked[0].kind !== "snippet") return null;
        return { items: ranked.slice(0, 50), start, prefix };
    }

    /* ---------- UI ---------- */

    function init() {
        const editor = document.getElementById("python-code");
        if (!editor) return;

        const popup = document.createElement("ul");
        popup.className = "ac-popup";
        popup.setAttribute("role", "listbox");
        popup.hidden = true;
        document.body.appendChild(popup);

        let state = null;      // { items, start, prefix }
        let selected = 0;
        let suppressNext = false;

        /* --- caret position via a hidden mirror element --- */
        const mirror = document.createElement("div");
        mirror.className = "ac-mirror";
        mirror.setAttribute("aria-hidden", "true");
        document.body.appendChild(mirror);

        const MIRROR_PROPS = ["fontFamily", "fontSize", "fontWeight", "fontStyle", "letterSpacing",
            "lineHeight", "tabSize", "paddingTop", "paddingRight", "paddingBottom", "paddingLeft",
            "borderTopWidth", "borderRightWidth", "borderBottomWidth", "borderLeftWidth", "textTransform"];

        function caretRect() {
            const cs = getComputedStyle(editor);
            MIRROR_PROPS.forEach(p => { mirror.style[p] = cs[p]; });
            mirror.style.width = editor.clientWidth + "px";
            mirror.textContent = editor.value.slice(0, state ? state.start : editor.selectionStart);
            const marker = document.createElement("span");
            marker.textContent = "\u200b";
            mirror.appendChild(marker);

            const box = editor.getBoundingClientRect();
            const lineH = parseFloat(cs.lineHeight) || 20;
            return {
                left: box.left + marker.offsetLeft - editor.scrollLeft + editor.clientLeft,
                top: box.top + marker.offsetTop - editor.scrollTop + editor.clientTop,
                lineH
            };
        }

        function position() {
            if (!state) return;
            const r = caretRect();
            const box = editor.getBoundingClientRect();
            popup.style.left = "0px";
            popup.style.top = "0px";
            const pw = popup.offsetWidth;
            const ph = popup.offsetHeight;

            let left = Math.min(Math.max(r.left, 8), window.innerWidth - pw - 8);
            let top = r.top + r.lineH;
            if (top + ph > window.innerHeight - 8 && r.top - ph > 8) top = r.top - ph; // flip above

            // hide if caret scrolled out of the editor view
            const visible = r.top + r.lineH > box.top && r.top < box.bottom;
            popup.style.visibility = visible ? "visible" : "hidden";
            popup.style.left = left + "px";
            popup.style.top = top + "px";
        }

        function render() {
            popup.textContent = "";
            state.items.forEach((item, i) => {
                const li = document.createElement("li");
                li.className = "ac-item" + (i === selected ? " ac-selected" : "");
                li.setAttribute("role", "option");
                li.setAttribute("aria-selected", i === selected ? "true" : "false");
                li.dataset.index = i;

                const badge = document.createElement("span");
                badge.className = "ac-badge ac-k-" + item.kind;
                badge.textContent = ({ keyword: "k", builtin: "b", function: "ƒ", method: "m", class: "C",
                                       variable: "v", module: "M", snippet: "⌘" })[item.kind] || "·";

                const label = document.createElement("span");
                label.className = "ac-label";
                const p = state.prefix.length;
                if (p && item.label.toLowerCase().startsWith(state.prefix.toLowerCase())) {
                    const b = document.createElement("b");
                    b.textContent = item.label.slice(0, p);
                    label.append(b, item.label.slice(p));
                } else {
                    label.textContent = item.label;
                }

                const detail = document.createElement("span");
                detail.className = "ac-detail";
                detail.textContent = item.detail || "";

                li.append(badge, label, detail);
                popup.appendChild(li);
            });
            popup.hidden = false;
            position();
            const sel = popup.children[selected];
            if (sel) sel.scrollIntoView({ block: "nearest" });
            editor.setAttribute("aria-expanded", "true");
        }

        function hide() {
            state = null;
            popup.hidden = true;
            popup.style.visibility = "";
            editor.setAttribute("aria-expanded", "false");
        }

        function update(forced) {
            if (editor.selectionStart !== editor.selectionEnd) { hide(); return; }
            const result = getSuggestions(editor.value, editor.selectionStart, forced);
            if (!result) { hide(); return; }
            const keep = state && state.start === result.start ? state.items[selected] : null;
            state = result;
            selected = keep ? Math.max(0, result.items.findIndex(i => i.label === keep.label)) : 0;
            render();
        }

        /* --- accepting a suggestion --- */
        function insert(text) {
            editor.focus();
            if (!document.execCommand("insertText", false, text)) {
                editor.setRangeText(text, editor.selectionStart, editor.selectionEnd, "end");
                editor.dispatchEvent(new Event("input", { bubbles: true }));
            }
        }

        function accept(index) {
            if (!state) return;
            const item = state.items[index];
            const start = state.start;
            const caret = editor.selectionStart;
            const value = editor.value;
            suppressNext = true;

            let text = item.insert;
            let cursorOffset = null;

            if (item.kind === "snippet") {
                const lineStart = value.lastIndexOf("\n", start - 1) + 1;
                const indent = value.slice(lineStart, start).match(/^[ \t]*/)[0];
                text = text.replace(/\n/g, "\n" + indent);
                const marker = text.indexOf("$0");
                text = text.replace("$0", "");
                cursorOffset = marker === -1 ? text.length : marker;
            } else if (item.call && value.charAt(caret) !== "(") {
                text += "()";
                cursorOffset = text.length - 1;
            }

            // replace the typed prefix (and any identifier chars right after the caret)
            let end = caret;
            while (end < value.length && /\w/.test(value[end])) end++;
            editor.setSelectionRange(start, end);
            insert(text);
            if (cursorOffset !== null) editor.setSelectionRange(start + cursorOffset, start + cursorOffset);

            hide();
            suppressNext = false;
        }

        /* --- events --- */
        // Capture on document so we run before syntax.js's Tab/Enter handlers.
        document.addEventListener("keydown", event => {
            if (event.target !== editor) return;

            if (event.ctrlKey && event.code === "Space") {
                event.preventDefault();
                event.stopImmediatePropagation();
                update(true);
                return;
            }
            if (!state) return;
            if (event.ctrlKey || event.metaKey || event.altKey) { hide(); return; }

            switch (event.key) {
                case "ArrowDown":
                    selected = (selected + 1) % state.items.length;
                    break;
                case "ArrowUp":
                    selected = (selected - 1 + state.items.length) % state.items.length;
                    break;
                case "PageDown":
                    selected = Math.min(selected + 6, state.items.length - 1);
                    break;
                case "PageUp":
                    selected = Math.max(selected - 6, 0);
                    break;
                case "Tab":
                case "Enter":
                    if (event.shiftKey) { hide(); return; }
                    event.preventDefault();
                    event.stopImmediatePropagation();
                    accept(selected);
                    return;
                case "Escape":
                    event.preventDefault();
                    event.stopImmediatePropagation(); // keeps Esc from also releasing the Tab trap
                    hide();
                    return;
                default:
                    return;
            }
            event.preventDefault();
            event.stopImmediatePropagation();
            render();
        }, true);

        editor.addEventListener("input", event => {
            if (suppressNext) return;
            const t = event.inputType || "";
            // only react to typing and deleting, not undo/redo/paste-heavy edits
            if (t === "insertFromPaste" || t === "historyUndo" || t === "historyRedo") { hide(); return; }
            update(false);
        });

        editor.addEventListener("keyup", event => {
            if (["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) hide();
        });
        editor.addEventListener("click", hide);
        editor.addEventListener("blur", () => setTimeout(hide, 0));
        editor.addEventListener("scroll", position);
        window.addEventListener("resize", position);
        window.addEventListener("scroll", position, true);

        // mouse: mousedown (not click) so the textarea keeps focus
        popup.addEventListener("mousedown", event => {
            event.preventDefault();
            const li = event.target.closest(".ac-item");
            if (li) accept(Number(li.dataset.index));
        });
        popup.addEventListener("mousemove", event => {
            const li = event.target.closest(".ac-item");
            if (li && Number(li.dataset.index) !== selected) {
                popup.children[selected]?.classList.remove("ac-selected");
                selected = Number(li.dataset.index);
                li.classList.add("ac-selected");
            }
        });

        editor.setAttribute("aria-autocomplete", "list");
        editor.setAttribute("aria-haspopup", "listbox");
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", init);
    } else {
        init();
    }
})();
