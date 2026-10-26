# shellcheck shell=sh
# Cyberdeck: единая тема для Qt5/Qt6 и GTK (login-шеллы, startx)
export QT_QPA_PLATFORMTHEME=qt5ct
export QT_STYLE_OVERRIDE=kvantum
export QT_AUTO_SCREEN_SCALE_FACTOR=0
export GTK2_RC_FILES="$HOME/.gtkrc-2.0"
export XCURSOR_SIZE=${XCURSOR_SIZE:-24}
export MC_SKIN=nord
# Neovim — редактор по умолчанию (mc по F4, git, crontab, sudoedit, less → v)
export EDITOR=nvim VISUAL=nvim SUDO_EDITOR=nvim
# nmtui/whiptail (newt) — цвета Nord вместо синего фона
export NEWT_COLORS='root=lightgray,default;border=cyan,default;window=lightgray,default;shadow=default,default;title=cyan,default;button=black,cyan;actbutton=black,brightcyan;compactbutton=lightgray,default;checkbox=lightgray,default;actcheckbox=black,cyan;entry=white,black;disentry=gray,default;label=lightgray,default;listbox=lightgray,default;actlistbox=black,cyan;sellistbox=cyan,default;actsellistbox=black,cyan;textbox=lightgray,default;acttextbox=black,cyan;emptyscale=default,black;fullscale=default,cyan;helpline=gray,default;roottext=gray,default'
