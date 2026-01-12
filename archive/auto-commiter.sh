#!/bin/bash
while true ; echo ======new cycle====== ; do /usr/bin/git status ; sleep 3; /usr/bin/git add -A ; sleep 3 ; /usr/bin/git commit -m "autocommit od Martusi $(date +%D%M%Y-%H%M) $(hostname)" ; sleep 3 ; /usr/bin/git pull ; sleep 3 ; /usr/bin/git push  ; sleep 13 ; done
