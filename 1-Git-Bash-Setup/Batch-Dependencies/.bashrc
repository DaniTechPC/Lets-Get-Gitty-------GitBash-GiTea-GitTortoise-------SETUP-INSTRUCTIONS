# ============================================================
# Git Bash Linux-Like Environment
# Managed by Setup-GitBash-Linux.bat
# ============================================================

# Put the user's Linux-compatibility commands first.
export PATH="$HOME/bin:$PATH"

# Always start interactive Git Bash sessions in the user's home directory (~).
# This intentionally overrides the folder used by "Git Bash Here".
if [[ $- == *i* ]]; then
    cd "$HOME"

    # Ubuntu-like interactive prompt: user@host:~/folder$
    PS1='\[\e[01;32m\]\u@\h\[\e[00m\]:\[\e[01;34m\]\w\[\e[00m\]\$ '
fi

# Useful Ubuntu-style aliases.
alias ll='ls -alF --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias cls='clear'
alias c='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias home='cd ~'

# Bash quality-of-life settings similar to a normal Linux shell.
HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend
shopt -s checkwinsize
shopt -s globstar 2>/dev/null || true

# Make less behave comfortably in a terminal.
export LESS='-R'

# Friendly command-not-found hint. This does not intercept every Bash error,
# but gives users a discoverable helper command.
linuxhelp() {
    linux-help "$@"
}

# Run this after installing a new WinGet package if the current shell has not
# noticed it yet.
refreshpath() {
    export PATH="$HOME/bin:/c/Users/$USERNAME/AppData/Local/Microsoft/WinGet/Links:$PATH"
    hash -r
    echo "PATH refreshed for this Git Bash session."
}
