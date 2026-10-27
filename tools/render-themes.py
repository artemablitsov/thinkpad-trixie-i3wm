#!/usr/bin/env python3
"""tools/render-themes.py — картинки тем mc и Neovim для README (docs/assets).

Рисует терминал 80×24 клетка за клеткой, беря цвета прямо из файлов тем:
  config/mc/nord.ini, config/mc/nord-root.ini   — скины mc
  config/nvim/colors/nord-root.lua               — палитра nord-root
Обычная тема Neovim (nord.nvim) — по палитре Nord. Это отрисовка, а не снимок
экрана: раскладка как у mc и Neovim, цвета — точно из тем.

    python3 tools/render-themes.py      # → docs/assets/root-mc.svg, root-nvim.svg
"""
import configparser
import html
import pathlib
import re

REPO = pathlib.Path(__file__).resolve().parent.parent
W, H = 80, 24                      # клеток
CW, CH, FS = 8.4, 18, 14           # ширина/высота клетки, кегль

# Палитра kitty (Nord) — для 16-цветных скинов
NORD16 = {
    "black": "#3B4252", "red": "#BF616A", "green": "#A3BE8C", "yellow": "#EBCB8B",
    "blue": "#81A1C1", "magenta": "#B48EAD", "cyan": "#88C0D0", "lightgray": "#E5E9F0",
    "gray": "#4C566A", "brightred": "#BF616A", "brightgreen": "#A3BE8C",
    "brightyellow": "#EBCB8B", "brightblue": "#81A1C1", "brightmagenta": "#B48EAD",
    "brightcyan": "#8FBCBB", "white": "#ECEFF4",
}
FG0, BG0 = "#D8DEE9", "#2E3440"    # «default» терминала


class Screen:
    def __init__(self, fg=FG0, bg=BG0):
        self.fg0, self.bg0 = fg, bg
        self.cells = [[(" ", fg, bg, False) for _ in range(W)] for _ in range(H)]

    def put(self, row, col, text, fg=None, bg=None, bold=False):
        for i, ch in enumerate(text):
            if 0 <= col + i < W:
                self.cells[row][col + i] = (ch, fg or self.fg0, bg or self.bg0, bold)

    def fill(self, row, col, n, fg=None, bg=None):
        self.put(row, col, " " * n, fg, bg)

    def svg(self, x0, y0):
        out = []
        for r, line in enumerate(self.cells):
            y = y0 + r * CH
            c = 0
            while c < W:   # фон — отрезками одного цвета
                bg = line[c][2]
                e = c
                while e < W and line[e][2] == bg:
                    e += 1
                out.append(f'<rect x="{x0 + c * CW:.1f}" y="{y}" width="{(e - c) * CW + 0.6:.1f}" height="{CH + 0.5}" fill="{bg}"/>')
                c = e
            c = 0
            while c < W:   # текст — отрезками одного цвета; textLength держит сетку
                _, fg, _, bold = line[c]
                e = c
                while e < W and line[e][1] == fg and line[e][3] == bold:
                    e += 1
                text = "".join(ch for ch, *_ in line[c:e])
                if text.strip():
                    out.append(
                        f'<text x="{x0 + c * CW:.1f}" y="{y + 13.5}" fill="{fg}"'
                        f'{" font-weight=\"700\"" if bold else ""} textLength="{(e - c) * CW:.1f}"'
                        f' lengthAdjust="spacingAndGlyphs">{html.escape(text)}</text>')
                c = e
        return "\n".join(out)


# ── mc ────────────────────────────────────────────────────────────────
def mc_skin(name):
    cp = configparser.ConfigParser(interpolation=None, strict=False)
    cp.optionxform = str
    cp.read(REPO / "config/mc" / f"{name}.ini", encoding="utf-8")
    aliases = dict(cp["aliases"]) if cp.has_section("aliases") else {}

    def color(v, default):
        v = (v or "").strip()
        if not v or v == "default":
            return default
        v = aliases.get(v, v)
        return NORD16.get(v, v if v.startswith("#") else default)

    core_fg, core_bg = FG0, BG0
    d = cp.get("core", "_default_", fallback="")
    if d:
        f, b = (d.split(";") + ["", ""])[:2]
        core_fg, core_bg = color(f, FG0), color(b, BG0)

    def get(section, key):
        v = cp.get(section, key, fallback=None)
        if v is None:
            v = cp.get(section, "_default_", fallback="")
        parts = (v.split(";") + ["", "", ""])[:3]
        return color(parts[0], core_fg), color(parts[1], core_bg), "bold" in parts[2]
    return get, core_fg, core_bg


def render_mc(skin, user, host_path):
    get, fg0, bg0 = mc_skin(skin)
    s = Screen(fg0, bg0)
    frame = get("core", "frame")
    header = get("core", "header")
    selected = get("core", "selected")
    marked = get("core", "marked")
    d = get("filehighlight", "directory")
    sym = get("filehighlight", "symlink")
    exe = get("filehighlight", "executable")
    doc = get("filehighlight", "doc")
    menu = get("menu", "_default_")
    menuhot = get("menu", "menuhot")

    # Строка меню
    s.fill(0, 0, W, menu[0], menu[1])
    x = 2
    for item in ("Left", "File", "Command", "Options", "Right"):
        s.put(0, x, item[0], menuhot[0], menuhot[1])
        s.put(0, x + 1, item[1:], menu[0], menu[1])
        x += len(item) + 5

    left = [("/..", "UP--DIR", d, "Oct 27 10:40"), ("/NetworkManager", "4096", d, "Oct 26 18:02"),
            ("/apt", "4096", d, "Oct 26 17:55"), ("/cyberdeck", "4096", d, "Oct 26 16:40"),
            ("/default", "4096", d, "Oct 26 16:41"), ("/greetd", "4096", d, "Oct 26 16:41"),
            ("/pam.d", "4096", d, "Oct 26 16:44"), ("/sudoers.d", "4096", d, "Oct 26 16:44"),
            ("/systemd", "4096", d, "Oct 26 16:44"), (" fstab", "703", None, "Oct 26 12:10"),
            (" hostname", "10", None, "Oct 26 12:10"), (" hosts", "187", None, "Oct 26 12:10"),
            ("@mtab", "19", sym, "Oct 26 12:09"), (" nftables.conf", "1873", doc, "Oct 26 16:44"),
            (" sudoers", "1800", None, "Oct 26 12:10")]
    right = [("/..", "UP--DIR", d, "Oct 27 10:40"), ("/.config", "4096", d, "Oct 27 10:31"),
             ("/.local", "4096", d, "Oct 27 10:31"), (" .bashrc", "571", None, "Apr 10  2025"),
             (" .profile", "161", None, "Apr 10  2025"), ("*backup.sh", "1204", exe, "Oct 27 09:12")]
    if user != "root":
        right[0:3] = [("/..", "UP--DIR", d, "Oct 27 10:40"), ("/.cyberdeck", "4096", d, "Oct 27 10:20"),
                      ("/Documents", "4096", d, "Oct 26 19:05")]
    cur_left, mark_left = 3, 9

    def panel(col, path, rows, active, cur, mark):
        wdt = 40
        s.put(1, col, "┌" + "─" * (wdt - 2) + "┐", *frame[:2])
        title = f" {path} "
        tcol = col + 2
        tc = selected if active else header
        s.put(1, tcol, title, tc[0], tc[1], True)
        s.put(1, col + wdt - 5, ".[^]", *frame[:2])
        s.put(2, col, "│", *frame[:2]); s.put(2, col + wdt - 1, "│", *frame[:2])
        s.put(2, col + 1, f"{'.n   Name':<17}", header[0], header[1], True)
        s.put(2, col + 18, "│", *frame[:2])
        s.put(2, col + 19, f"{'Size':^7}", header[0], header[1], True)
        s.put(2, col + 26, "│", *frame[:2])
        s.put(2, col + 27, f"{'Modify time':<12}"[:12], header[0], header[1], True)
        for i in range(15):
            r = 3 + i
            s.put(r, col, "│", *frame[:2]); s.put(r, col + wdt - 1, "│", *frame[:2])
            s.put(r, col + 18, "│", *frame[:2]); s.put(r, col + 26, "│", *frame[:2])
            if i >= len(rows):
                continue
            name, size, hl, mtime = rows[i]
            fg, bg, b = hl if hl else (fg0, bg0, False)
            if i == mark:
                fg, bg, b = marked
            if active and i == cur:
                fg, bg, b = selected
                s.fill(r, col + 1, wdt - 2, fg, bg)
            s.put(r, col + 1, f"{name:<17}"[:17], fg, bg, b)
            s.put(r, col + 18, "│", fg if (active and i == cur) else frame[0], bg if (active and i == cur) else frame[1])
            s.put(r, col + 19, f"{size:>7}"[:7], fg, bg, b)
            s.put(r, col + 26, "│", fg if (active and i == cur) else frame[0], bg if (active and i == cur) else frame[1])
            s.put(r, col + 27, f"{mtime:<12}"[:12], fg, bg, b)
        s.put(18, col, "├" + "─" * (wdt - 2) + "┤", *frame[:2])
        s.put(19, col, "│", *frame[:2]); s.put(19, col + wdt - 1, "│", *frame[:2])
        info = rows[cur][0].strip("/ ") if active else "UP--DIR"
        s.put(19, col + 1, f" {info}"[:wdt - 2])
        s.put(20, col, "└" + "─" * (wdt - 2) + "┘", *frame[:2])
        s.put(20, col + wdt - 21, " 31G/233G (13%) ", *frame[:2])

    panel(0, host_path, left, True, cur_left, mark_left)
    panel(40, "/root" if user == "root" else "/home/artem", right, False, 0, -1)

    prompt = "root@cyberdeck:/etc# " if user == "root" else "artem@cyberdeck:/etc$ "
    s.put(22, 0, prompt)
    hot = get("buttonbar", "hotkey")
    btn = get("buttonbar", "button")
    labels = ["Help", "Menu", "View", "Edit", "Copy", "RenMov", "Mkdir", "Delete", "PullDn", "Quit"]
    x = 0
    for i, lab in enumerate(labels, 1):
        n = str(i)
        s.put(23, x, n, hot[0], hot[1], hot[2])
        s.fill(23, x + len(n), 8 - len(n), btn[0], btn[1])
        s.put(23, x + len(n), lab[:8 - len(n)], btn[0], btn[1])
        x += 8
    return s


# ── Neovim ────────────────────────────────────────────────────────────
def root_palette():
    lua = (REPO / "config/nvim/colors/nord-root.lua").read_text(encoding="utf-8")
    body = lua[lua.index("local c = {"):lua.index("}", lua.index("local c = {"))]
    return dict(re.findall(r'(\w+) = "(#[0-9A-Fa-f]{6})"', body))


SCRIPT = [
    ("#!/usr/bin/env bash", "comment"),
    ("# Пороги заряда батареи ThinkPad: 75–85 %", "comment"),
    ('BAT_START_THRESHOLD="" BAT_STOP_THRESHOLD=""', "code"),
    ("[[ -r /etc/cyberdeck/power.conf ]] && source /etc/cyberdeck/power.conf", "code"),
    ("for b in /sys/class/power_supply/BAT*; do", "code"),
    ("  end=$b/charge_control_end_threshold", "code"),
    ("  start=$b/charge_control_start_threshold", "code"),
    ('  [[ -n "$BAT_STOP_THRESHOLD" && -w $end ]] && echo 85 > "$end"', "code"),
    ('  [[ -n "$BAT_START_THRESHOLD" && -w $start ]] && echo 75 > "$start"', "code"),
    ("done", "code"),
    ("exit 0", "code"),
]
KEYWORDS = {"for", "in", "do", "done", "exit", "source", "echo", "if", "then", "fi"}
# end=… / start=… — присваивания (имя переменной) в bash-подсветке


def tokens(line):
    """Грубая подсветка bash: строки, $переменные, ключевые слова, числа, операторы."""
    for m in re.finditer(r'"[^"]*"|\$\w+|\b\w+\b|&&|\[\[|\]\]|[<>=;*]|\s+|.', line):
        t = m.group(0)
        if t.startswith('"'):
            yield t, "string"
        elif t.startswith("$"):
            yield t, "var"
        elif t in KEYWORDS:
            yield t, "keyword"
        elif t.isdigit():
            yield t, "number"
        elif t in ("&&", "[[", "]]", ">", "<", "=", ";", "*"):
            yield t, "operator"
        elif re.fullmatch(r"[A-Z_]+", t):
            yield t, "ident"
        else:
            yield t, "plain"


def render_nvim(root):
    if root:
        c = root_palette()
        th = dict(fg=c["s0"], bg=c["r0"], comment=c["muted"], string=c["green"], var=c["e9"],
                  keyword=c["e9"], number=c["purple"], operator=c["e9"], ident=c["s0"], plain=c["s0"],
                  linenr=c["r3"], curnr=c["e8"], search_fg=c["r0"], search_bg=c["yellow"],
                  sl_bg=c["r1"], sl_fg=c["s1"], badge_fg=c["s2"], badge_bg=c["deep"],
                  mode_fg=c["r0"], mode_bg=c["e8"])
    else:
        th = dict(fg="#D8DEE9", bg="#2E3440", comment="#616E88", string="#A3BE8C", var="#81A1C1",
                  keyword="#81A1C1", number="#B48EAD", operator="#81A1C1", ident="#D8DEE9", plain="#D8DEE9",
                  linenr="#4C566A", curnr="#D8DEE9", search_fg="#2E3440", search_bg="#EBCB8B",
                  sl_bg="#3B4252", sl_fg="#E5E9F0", mode_fg="#3B4252", mode_bg="#88C0D0")
    s = Screen(th["fg"], th["bg"])
    cur = 7
    for i, (line, kind) in enumerate(SCRIPT):
        r = i
        nr = f"{i + 1:>3} "
        s.put(r, 2, nr, th["curnr"] if i == cur else th["linenr"], None, i == cur)
        col = 6
        if kind == "comment":
            s.put(r, col, line, th["comment"])
            continue
        for t, k in tokens(line):
            s.put(r, col, t, th[k])
            col += len(t)
        # поиск /THRESHOLD — подсвечены совпадения
        for m in re.finditer("THRESHOLD", line):
            for j in range(m.start(), m.end()):
                ch = s.cells[r][6 + j][0]
                s.cells[r][6 + j] = (ch, th["search_fg"], th["search_bg"], False)
    path = "/usr/local/sbin/charge-limits"
    s.fill(22, 0, W, th["sl_fg"], th["sl_bg"])
    if root:
        x = 0
        s.put(22, x, " ROOT ", th["badge_fg"], th["badge_bg"], True); x += 6
        s.put(22, x, " NORMAL ", th["mode_fg"], th["mode_bg"], True); x += 8
        s.put(22, x, f" {path}", th["sl_fg"], th["sl_bg"])
        right = "[sh]  8:3  72% "
    else:
        s.put(22, 0, " NORMAL ", th["mode_fg"], th["mode_bg"], True)
        s.put(22, 8, " │ " + path, th["sl_fg"], th["sl_bg"])
        right = "sh │ 72% │  8:3 "
    s.put(22, W - len(right), right, th["sl_fg"], th["sl_bg"])
    s.put(23, 0, "/THRESHOLD", th["fg"])
    s.put(23, W - 10, "[2/4]", th["fg"])
    return s


# ── SVG ───────────────────────────────────────────────────────────────
def frame_svg(screens, out, title):
    pad, gap, bar = 18, 28, 26
    tw, th_ = W * CW, H * CH
    width = pad * 2 + tw * 2 + gap
    height = pad * 2 + bar + th_ + 30
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width:.0f}" height="{height:.0f}" '
             f'viewBox="0 0 {width:.0f} {height:.0f}" role="img" aria-label="{html.escape(title)}">',
             f"<title>{html.escape(title)}</title>",
             "<style>text{font-family:'JetBrains Mono','DejaVu Sans Mono',Menlo,Consolas,monospace;"
             f"font-size:{FS}px;white-space:pre}}.cap{{font-size:13px}}</style>",
             f'<rect width="{width:.0f}" height="{height:.0f}" rx="12" fill="#242933"/>']
    for i, (scr, label, cmd, accent) in enumerate(screens):
        x0 = pad + i * (tw + gap)
        parts.append(f'<rect x="{x0 - 1}" y="{pad - 1}" width="{tw + 2:.1f}" height="{bar + th_ + 2:.1f}" rx="6" fill="{accent}"/>')
        parts.append(f'<rect x="{x0}" y="{pad}" width="{tw:.1f}" height="{bar}" rx="5" fill="#3B4252"/>')
        parts.append(f'<text x="{x0 + 10}" y="{pad + 17}" fill="#D8DEE9" class="cap">{html.escape(cmd)}</text>')
        parts.append(scr.svg(x0, pad + bar))
        parts.append(f'<text x="{x0 + tw / 2:.1f}" y="{pad + bar + th_ + 22:.1f}" fill="{accent}" '
                     f'class="cap" text-anchor="middle" font-weight="700">{html.escape(label)}</text>')
    parts.append("</svg>")
    out.write_text("\n".join(parts) + "\n", encoding="utf-8")


def main():
    assets = REPO / "docs/assets"
    frame_svg([(render_mc("nord", "artem", "/etc"), "you — Nord", "artem@cyberdeck ~ $ mc /etc", "#4C566A"),
               (render_mc("nord-root", "root", "/etc"), "root — Nord Root", "artem@cyberdeck ~ $ sudo mc /etc", "#A23B55")],
              assets / "root-mc.svg", "Midnight Commander: your session in Nord, root in burgundy")
    frame_svg([(render_nvim(False), "you — Nord", "artem@cyberdeck ~ $ nvim /usr/local/sbin/charge-limits", "#4C566A"),
               (render_nvim(True), "root — Nord Root", "artem@cyberdeck ~ $ sudo nvim /usr/local/sbin/charge-limits", "#A23B55")],
              assets / "root-nvim.svg", "Neovim: your session in Nord, root in burgundy with a ROOT badge")
    print("docs/assets/root-mc.svg, docs/assets/root-nvim.svg")


if __name__ == "__main__":
    main()
