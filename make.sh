#!/usr/bin/bash
npm run build
node lib/index.js --save tmp
cp resources/IEEEtran.cls tmp/IEEEtran.cls
cp resources/IEEE.bst tmp/IEEE.bst
cd tmp
pdflatex -interaction=nonstopmode paper.tex
bibtex paper.aux
pdflatex -interaction=nonstopmode paper.tex
pdflatex -interaction=nonstopmode paper.tex
cd ..
mv tmp/paper.pdf paper.pdf
rm tmp/*