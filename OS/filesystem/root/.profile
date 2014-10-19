# have prompt string set window title for x term
if  [ $TERM == "cygwin" -o $TERM == "rxvt" -o $TERM == "xterm" -o $TERM == "rxvt-unicode" ] ; then
PS1="\033[0m\033]0;root @ redpitaya  - ${PWD}\007\[\033[1;31m\]# \033[0m"
fi
