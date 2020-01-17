#! /bin/bash
find texlive -type d -exec echo {}/. \; | sed 's/^texlive//g' >texlive.lst
find texlive -type f | sed 's/^texlive//g' >>texlive.lst
cd texlive/texmf-dist/
ls -R -1 > ls-R