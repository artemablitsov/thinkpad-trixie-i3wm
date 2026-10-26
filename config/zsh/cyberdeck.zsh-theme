# CYBERDECK · простой промпт для текстовой консоли (TTY), где нет Nerd-иконок.
# В kitty используется Powerlevel10k (~/.p10k.zsh).
#   ~/projects/cyberdeck on main ●
#   ❯
ZSH_THEME_GIT_PROMPT_PREFIX=" %F{8}on%f %F{4}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%f"
ZSH_THEME_GIT_PROMPT_DIRTY=" %F{3}●%f"
ZSH_THEME_GIT_PROMPT_CLEAN=""

_cd_ssh() { [[ -n "$SSH_CONNECTION" ]] && echo "%F{5}%n@%m%f "; }
_cd_status() { echo "%(?.%F{6}.%F{1})❯%f"; }

PROMPT='
$(_cd_ssh)%F{6}%~%f$(git_prompt_info)
$(_cd_status) '
RPROMPT='%(?..%F{1}%?%f )%F{8}%*%f'
