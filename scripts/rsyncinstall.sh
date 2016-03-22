#!/bin/zsh

[ -f /usr/local/bin/rsync3 ] || {
  [ -f /usr/local/bin/rsync ] && ln -s /usr/local/bin/rsync  /usr/local/bin/rsync3
}

