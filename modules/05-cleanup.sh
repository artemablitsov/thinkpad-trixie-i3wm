# shellcheck shell=bash
# Удаляем все оконные менеджеры, кроме i3, и все прочие display manager'ы.

WMS=(
  openbox fluxbox blackbox icewm jwm awesome dwm herbstluftwm bspwm qtile spectrwm
  fvwm fvwm3 twm ctwm evilwm cwm xfwm4 metacity mutter muffin marco kwin-x11
  kwin-wayland sway wayfire labwc enlightenment wmaker xmonad notion ratpoison
  sawfish matchbox-window-manager weston compiz-core i3-gaps
)
DMS=(lightdm gdm3 sddm lxdm xdm slim nodm wdm ly emptty)

to_purge=()
for p in "${WMS[@]}" "${DMS[@]}"; do pkg_installed "$p" && to_purge+=("$p"); done
if [[ ${#to_purge[@]} -gt 0 ]]; then
  info "Removing: ${to_purge[*]}"
  apt-get purge -y -q "${to_purge[@]}"
  apt-get autoremove -y -q --purge
else
  info "No other WM/DM found"
fi

# Лишние xsession-файлы, чтобы в greeter был только Cyberdeck
find /usr/share/xsessions -maxdepth 1 -name '*.desktop' ! -name 'i3*.desktop' -print -delete 2>/dev/null || true
ok "Only i3 is left"
