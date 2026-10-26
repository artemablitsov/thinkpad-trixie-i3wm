# shellcheck shell=bash
# CYBERDECK · переменные графической сессии (читает cyberdeck-xsession)
export QT_QPA_PLATFORMTHEME=qt5ct
export QT_STYLE_OVERRIDE=kvantum
export QT_AUTO_SCREEN_SCALE_FACTOR=0
export GTK2_RC_FILES="$HOME/.gtkrc-2.0"
export XCURSOR_SIZE=${XCURSOR_SIZE:-24}
export MC_SKIN=nord
export NEWT_COLORS='root=lightgray,default;border=cyan,default;window=lightgray,default;shadow=default,default;title=cyan,default;button=black,cyan;actbutton=black,brightcyan;compactbutton=lightgray,default;checkbox=lightgray,default;actcheckbox=black,cyan;entry=white,black;disentry=gray,default;label=lightgray,default;listbox=lightgray,default;actlistbox=black,cyan;sellistbox=cyan,default;actsellistbox=black,cyan;textbox=lightgray,default;acttextbox=black,cyan;emptyscale=default,black;fullscale=default,cyan;helpline=gray,default;roottext=gray,default'
export TERMINAL=kitty
export BROWSER=x-www-browser
export EDITOR=nvim VISUAL=nvim SUDO_EDITOR=nvim
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/go/bin:$PATH"
cur=$(sed -n 's/^Inherits=//p' "$HOME/.icons/default/index.theme" 2>/dev/null)
export XCURSOR_THEME="${cur:-Adwaita}"
unset cur
