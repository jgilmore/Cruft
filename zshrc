# The following lines were added by compinstall

#zstyle ':completion:*' completer _expand _complete _ignored _correct _approximate
#zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
#zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
#zstyle ':completion:*' max-errors 1
#zstyle :compinstall filename '/home/jgilmore/.zshrc'


zmodload zsh/complist
autoload -U compinit && compinit

### If you want zsh's completion to pick up new commands in $path automatically
### comment out the next line and un-comment the following 5 lines
zstyle ':completion:::::' completer _complete
#_force_rehash() {
#  (( CURRENT == 1 )) && rehash
#  return 1 # Because we didn't really complete anything
#}
#zstyle ':completion:::::' completer _force_rehash _complete _approximate
#zstyle -e ':completion:*:approximate:*' max-errors '0'
zstyle ':completion:*:descriptions' format "- %d -"
#zstyle ':completion:*:corrections' format "- %d - (errors %e})"
zstyle ':completion:*:default' list-prompt '%S%M matches%s'
zstyle ':completion:*' group-name ''
zstyle ':completion:*:manuals' separate-sections true
zstyle ':completion:*:manuals.(^1*)' insert-sections true
zstyle ':completion:*' menu select
zstyle ':completion:*' verbose yes
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'm:{a-zA-Z}={A-Za-z}' 'm:{a-zA-Z}={A-Za-z}' 'm:{a-zA-Z}={A-Za-z}'

autoload -Uz compinit
compinit
# End of lines added by compinstall
# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=10000
SAVEHIST=10000
# End of lines configured by zsh-newuser-install

#use vi mode
bindkey -v

#use arrow keys, home, etc.
bindkey '' backward-delete-char #backspace
bindkey '[3~' delete-char #delete
bindkey 'OH' beginning-of-line #home
bindkey 'OF' end-of-line #end

#Others, I don't actually use these much...
bindkey '^R' history-incremental-search-backward
bindkey '[1;5D' emacs-backward-word #^<left>
bindkey '[1;5C' emacs-forward-word #^<right>

#Make the history commands put the cursor on the END of the line.
bindkey "\eOA" up-line-or-history
bindkey "\eOB" down-line-or-history
bindkey "\e[A" up-line-or-history
bindkey "\e[B" down-line-or-history

#Shift home and end for marking (and presumably deleteing) the end/begining of a line.




autoload colors
colors

autoload run-help
help(){
    bash -c "help $@"
}


# enable color support of ls and also add handy aliases
if [ "$TERM" != "dumb" ]; then
    eval "`dircolors -b`"
    alias ls='ls --color=auto'
    #alias dir='ls --color=auto --format=vertical'
    #alias vdir='ls --color=auto --format=long'
fi

PATH=/home/jgilmore/bin:/usr/local/bin:/usr/bin:/bin:/usr/X11R6/bin:/usr/games:/sbin:/usr/sbin

local head CH USERCOLOR MACHINECOLOR
#Set the color of the username depending on the md5sum, so each username will have a different color. Don't do white or black.
CH=1
while USERCOLOR=`echo $USER | md5sum | cut -c $CH-$CH`; echo $USERCOLOR | grep '[07a-z]'>/dev/null; do 
    CH=$(( $CH + 1 )); 
done

USERCOLOR="$fg[$color[3$USERCOLOR]]"

#If using ssh, set machine name to red.
if [ "$SSH_TTY" ]; then
    MACHINECOLOR="$fg_bold[red]"
else
    MACHINECOLOR="$reset_color"
fi
head="%{$USERCOLOR%}%n%{$reset_color%}@%{$MACHINECOLOR%}%m%{$reset_color%}"

PROMPT="$head%3~%(?.%{$fg[green]%}:%).%{$fg[red]%} %? :()%{$reset_color%}%#"

case $TERM in
    xterm*)
        precmd () {print -Pn "\e]0;zsh: %n@%m: %~\a"}
        preexec () { print -Pn "\e]0;zsh:%n@%m: %~,$1 \a" }
        ;;
esac
fortune Scripture\ Mastery
