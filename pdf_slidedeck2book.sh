#!/bin/bash


#############################################################
# get parts of the filepath
# filepath=`filepath_path ../bok.m4a`
# filename=`filepath_name ../bok.m4a`
# fileext=`filepath_ext ../bok.m4a`
function filepath_path { local file=$1; echo `dirname -- "${file}"`; }
function filepath_name { local file=$1; echo `basename -- "${file%.*}"`; }
function filepath_ext { local file=$1; echo "${file##*.}"; }


#############################################################
# CONFIG
INPUTFILE="$1"
INPUTFILEPATH=`filepath_path "$INPUTFILE"`
INPUTFILENAME=`filepath_name "$INPUTFILE"`
MARGIN_SIZE=36
DPI=300
BOOK_WIDTH=11
BOOK_HEIGHT=8.5
OUTDIR1=`mktemp -d -t "$INPUTFILENAME-1"`
OUTDIR2=`mktemp -d -t "$INPUTFILENAME-2"`
#OUTDIR1="./out"
#OUTDIR2="./out2"
CLEANUP=1


#############################################################
# EXIT/CLEANUP, SIGNAL HANDLING
function cleanup()
{
  if [ "$CLEANUP" == 1 ]; then
    echo "Removing:"
    echo " - $OUTDIR1"
    rm -rf "$OUTDIR1"
    echo " - $OUTDIR2"
    rm -rf "$OUTDIR2"
  fi
}
function ctrl_c()
{
  echo ""
  echo "CTRL-C!"
  exit -1
}
trap cleanup EXIT
trap ctrl_c SIGINT
#############################################################

function getWidth {
  local FILENAME="$1"
  echo `convert "$FILENAME" -format "%w" info:`
}
function getHeight {
  local FILENAME="$1"
  echo `convert "$FILENAME" -format "%h" info:`
}
function getColor_Avg {
  local FILENAME="$1"
  echo `convert -colorspace sRGB "$FILENAME" -resize 1x1\! -format "%[fx:int(255*r+.5)],%[fx:int(255*g+.5)],%[fx:int(255*b+.5)]" info:-`
}
function getColor_TopLeftPixel {
  local FILENAME="$1"
  local HEIGHT=`getHeight "$FILENAME"`
  local X=1
  local Y=1
  echo `convert -colorspace sRGB "$FILENAME" -format "%[fx:int(255*p{$X,$Y}.r)],%[fx:int(255*p{$X,$Y}.g)],%[fx:int(255*p{$X,$Y}.b)]" info:`
}

function addMargin {
  local INFILE="$1"
  local OUTFILE="$2"
  local MARGIN_SIZE="$3"
  local DESIRED_ASPECT="$4"
  local WIDTH=`getWidth "$INFILE"`
  local HEIGHT=`getHeight "$INFILE"`
  local WIDTH_NEW=$((WIDTH + MARGIN_SIZE + MARGIN_SIZE))
  local HEIGHT_NEW=$((HEIGHT + MARGIN_SIZE + MARGIN_SIZE))
  local NEW_ASPECT=`python -c "print('{0:0.4f}'.format($HEIGHT_NEW / $WIDTH_NEW))"`
  #local COLOR=`getColor_Avg "$INFILE"`          # average color
  local COLOR=`getColor_TopLeftPixel "$INFILE"` # top left pixel
  #echo "$WIDTH ($WIDTH_NEW)"
  #echo "$HEIGHT ($HEIGHT_NEW)"
  #echo "$COLOR"

  #echo "NEW_ASPECT:$NEW_ASPECT    DESIRED_ASPECT:$DESIRED_ASPECT"
  #echo "python -c \"print('{0:0.4f}'.format($HEIGHT_NEW / $WIDTH_NEW))\""
  #echo "python -c \"print('{0:0.4f}'.format($BOOK_HEIGHT / $BOOK_WIDTH))\""
  if [ `python -c "print( 1 if $NEW_ASPECT < $DESIRED_ASPECT else 0 )"` == "1" ]; then
    #echo "WIDTH was $WIDTH_NEW"
    #echo "HEIGHT was $HEIGHT_NEW"
    HEIGHT_NEW=`python -c "import math; print('{0}'.format(int( $WIDTH_NEW * $DESIRED_ASPECT )))"`
    #echo "WIDTH will be $WIDTH_NEW"
    #echo "HEIGHT will be $HEIGHT_NEW"
  else
    #echo "WIDTH was $WIDTH_NEW"
    #echo "HEIGHT was $HEIGHT_NEW"
    WIDTH_NEW=`python -c "import math; print('{0}'.format(int( $HEIGHT_NEW / $DESIRED_ASPECT )))"`
    #echo "WIDTH will be $WIDTH_NEW"
    #echo "HEIGHT will be $HEIGHT_NEW"
  fi

  echo "$INFILE -> $OUTFILE  with margin [color=rgb($COLOR), size=$MARGIN_SIZE]"
  #magick convert -colorspace sRGB "$INFILE" -blur 0x64 -resize "${WIDTH_NEW}x${HEIGHT_NEW}" "$OUTFILE"  # new image from blurred image
  magick convert -colorspace sRGB -size "${WIDTH_NEW}x${HEIGHT_NEW}" canvas:rgb\($COLOR\) "$OUTFILE"  # new image from COLOR
  #magick convert -colorspace sRGB "$INFILE" -resize 1x1\! -resize "${WIDTH_NEW}x${HEIGHT_NEW}"\! "$OUTFILE"   # new image from image average color

  magick composite -colorspace sRGB -gravity center "$INFILE"  "$OUTFILE" "$OUTFILE"
  #exit -1
}

function pdf2pngs {
  local INFILE="$1"
  local OUTDIR="$2"
  local DPI="$3"
  rm -rf "$OUTDIR"
  mkdir -p "$OUTDIR"
  magick convert -monitor -density $((DPI*2)) "$INFILE" -quality 100 -set units $DPI -monitor   "$OUTDIR/out-%04d.png"
}

function addMarginToPNGs {
  local INDIR="$1"
  local OUTDIR="$2"
  local MARGIN_SIZE="$3"
  local DESIRED_ASPECT="$4"
  rm -r "$OUTDIR"
  mkdir -p "$OUTDIR"

  shopt -s nullglob
  for f in "$INDIR/"*.png; do
    addMargin "$f" "$OUTDIR/"`filepath_name "$f"`.`filepath_ext "$f"` "$MARGIN_SIZE" "$DESIRED_ASPECT"
  done
  shopt -u nullglob
}

######################################
# get dpi of pdf:
######################################
echo "dpi of input pdf"
magick identify -format "%w x %h %x x %y\n" "$INPUTFILE"

######################################
# CONVERT PDF TO PNGs
######################################
echo "CONVERT PDF TO PNGs..."
pdf2pngs "$INPUTFILE" "$OUTDIR1" "$DPI"


######################################
# ADD MARGINS TO PNGs
######################################
echo "ADD MARGINS TO PNGs..."
addMarginToPNGs "$OUTDIR1" "$OUTDIR2" "$((DPI/2))" `python -c "print('{0:0.4f}'.format($BOOK_HEIGHT / $BOOK_WIDTH))"`


#####################################

######################################
# CONVERT PNGs to PDF
######################################
echo "CONVERT PNGs to PDF..."
rm "$INPUTFILEPATH/${INPUTFILENAME}-margins.pdf"
# -rw-r--r--  1 kevinmeinert  staff    81861538 Apr  1 09:09 grow-jpeg.pdf
# -rw-r--r--  1 kevinmeinert  staff  1922920649 Apr  1 09:19 grow-lzw.pdf
# -rw-r--r--  1 kevinmeinert  staff  2249930760 Apr  1 09:22 grow-rle.pdf
# -rw-r--r--  1 kevinmeinert  staff  1190841219 Apr  1 09:13 grow-zip.pdf
magick convert -monitor "$OUTDIR2/"*.png -alpha off -set units $DPI -quality 60 -compress jpeg "$INPUTFILEPATH/${INPUTFILENAME}-margins.pdf"


echo "Opening '$INPUTFILEPATH/${INPUTFILENAME}-margins.pdf'"
open "$INPUTFILEPATH/${INPUTFILENAME}-margins.pdf"

