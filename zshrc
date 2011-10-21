# The following lines were added by compinstall

zstyle ':completion:*' completer _expand _complete _ignored _correct _approximate
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'm:{a-zA-Z}={A-Za-z}' 'm:{a-zA-Z}={A-Za-z}' 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' max-errors 1
zstyle :compinstall filename '/home/jgilmore/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall
# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=10000
SAVEHIST=10000
bindkey -v
# End of lines configured by zsh-newuser-install

autoload colors
colors


# enable color support of ls and also add handy aliases
if [ "$TERM" != "dumb" ]; then
    eval "`dircolors -b`"
    alias ls='ls --color=auto'
    #alias dir='ls --color=auto --format=vertical'
    #alias vdir='ls --color=auto --format=long'
fi

PATH=/home/jgilmore/bin:/usr/local/bin:/usr/bin:/bin:/usr/X11R6/bin:/usr/games:/sbin:/usr/sbin

local head
#If using ssh, set machine name to red.
if [ -n "$SSH_TTY" ]; then
    head="%n@%{%$fg_bold[red]%}%m%{$reset_color%}"
else
    head='%n@%m'
fi
    PROMPT="%n@%m%3~%(?.%{$fg[green]%}:%).%{$fg[red]%} %? :()%{$reset_color%}%#"


