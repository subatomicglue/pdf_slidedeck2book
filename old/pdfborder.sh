pdf2ps "$1" a.ps
cat addborder.ps a.ps > b.ps
ps2pdf b.ps "$1-new.pdf"
rm a.ps b.ps

