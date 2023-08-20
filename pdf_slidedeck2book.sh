#!/bin/bash

# this script's dir (and location of the other tools)
scriptpath=$0
scriptname=`basename "$0"`
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cwd=`pwd`

# options:
MARGIN_SIZE=36
DPI=300
BOOK_WIDTH=11
BOOK_HEIGHT=8.5
CLEANUP=1
FORCE=0
args=()
VERBOSE=false

################################
# scan command line args:
function usage
{
  echo "$scriptname rename audio files by their peak level.  useful for individual instrument samples."
  echo "Usage: "
  echo "  $scriptname <file>        (list of pdf files to process)"
  echo "  $scriptname --help        (this help)"
  echo "  $scriptname --verbose     (output verbose information)"
  echo "  $scriptname --margin      (default: --margin ${MARGIN_SIZE})"
  echo "  $scriptname --dpi         (default: --dpi ${DPI})"
  echo "  $scriptname --width       (default: --width ${BOOK_WIDTH})"
  echo "  $scriptname --height      (default: --height ${BOOK_HEIGHT})"
  echo "  $scriptname --cleanup     (default: --cleanup ${CLEANUP})"
  echo "  $scriptname --force       (overwrite file(s), default: --force ${FORCE})"
  echo ""
}
ARGC=$#
ARGV=("$@")
non_flag_args=0
non_flag_args_required=1
for ((i = 0; i < ARGC; i++)); do
  if [[ $ARGC -ge 1 && ${ARGV[$i]} == "--help" ]]; then
    usage
    exit -1
  fi
  if [[ $ARGC -ge 1 && ${ARGV[$i]} == "--verbose" ]]; then
    VERBOSE=true
    continue
  fi
  if [[ $ARGC -ge 1 && ${ARGV[$i]} == "--margin" ]]; then
    ((i+=1))
    MARGIN_SIZE=${ARGV[$i]}
    $VERBOSE && echo "Parsing Args: Changing margin to $MARGIN_SIZE"
    continue
  fi
  if [[ $ARGC -ge 1 && ${ARGV[$i]} == "--dpi" ]]; then
    ((i+=1))
    DPI=${ARGV[$i]}
    $VERBOSE && echo "Parsing Args: Changing dpi to $DPI"
    continue
  fi
  if [[ $ARGC -ge 1 && ${ARGV[$i]} == "--width" ]]; then
    ((i+=1))
    BOOK_WIDTH=${ARGV[$i]}
    $VERBOSE && echo "Parsing Args: Changing book width to $BOOK_WIDTH"
    continue
  fi
  if [[ $ARGC -ge 1 && ${ARGV[$i]} == "--height" ]]; then
    ((i+=1))
    BOOK_HEIGHT=${ARGV[$i]}
    $VERBOSE && echo "Parsing Args: Changing book height to $BOOK_HEIGHT"
    continue
  fi
  if [[ $ARGC -ge 1 && ${ARGV[$i]} == "--cleanup" ]]; then
    ((i+=1))
    CLEANUP=${ARGV[$i]}
    $VERBOSE && echo "Parsing Args: Changing cleanup to $CLEANUP"
    continue
  fi
  if [[ $ARGC -ge 1 && ${ARGV[$i]} == "--force" ]]; then
    ((i+=1))
    FORCE=${ARGV[$i]}
    $VERBOSE && echo "Parsing Args: Changing force to $FORCE"
    continue
  fi
  if [[ $ARGC -ge 1 && ${ARGV[$i]:0:2} == "--" ]]; then
    echo "Unknown option ${ARGV[$i]}"
    exit -1
  fi

  args+=("${ARGV[$i]}")
  $VERBOSE && echo "Parsing Args: Audio: \"${ARGV[$i]}\""
  ((non_flag_args+=1))
done

# output help if they're getting it wrong...
if [ $non_flag_args_required -ne 0 ] && [[ $ARGC -eq 0 || ! $ARGC -ge $non_flag_args_required ]]; then
  [ $ARGC -gt 0 ] && echo "Expected $non_flag_args_required args, but only got $ARGC"
  usage
  exit -1
fi
################################


#############################################################
# get parts of the filepath
# filepath=`filepath_path ../bok.m4a`
# filename=`filepath_name ../bok.m4a`
# fileext=`filepath_ext ../bok.m4a`
function filepath_path { local file=$1; echo `dirname -- "${file}"`; }
function filepath_name { local file=$1; echo `basename -- "${file%.*}"`; }
function filepath_ext { local file=$1; echo "${file##*.}"; }


#############################################################
# EXIT/CLEANUP, SIGNAL HANDLING
function cleanup()
{
  if [ "$CLEANUP" == 1 ]; then
    if [ -d "$OUTDIR1" ]; then
      echo "Removing: $OUTDIR1"
      rm -rf "$OUTDIR1"
    fi
    if [ -d "$OUTDIR2" ]; then
      echo "Removing: $OUTDIR2"
      rm -rf "$OUTDIR2"
    fi
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


# do the work:
function process {
  local DECO_BEGIN="--=::["
  local DECO_END="]::=--"
  local DECO_JOB="--==========::==========--"
  local DECO_STEP="----------"

  for INPUTFILE in "${args[@]}"; do
    local INPUTFILENAME=`filepath_name "$INPUTFILE"`
    local OUTPATH="./$INPUTFILENAME-book.pdf"

    # force remove previous file if present
    if [ $FORCE -eq 1 ]; then
      rm -f "${OUTPATH}"
    fi
    # skip job if output file already exists
    if [ -f "${OUTPATH}" ]; then
      echo "Skipping: \"$INPUTFILE\" -> \"$OUTPATH\" (exists)"
      continue
    fi

    # Start job
    echo "${DECO_JOB}"
    echo "${DECO_BEGIN}Processing \"$INPUTFILE\"${DECO_END}"

    # use global vars for OUTDIRX, so cleanup works
    OUTDIR1=`mktemp -d -t "$INPUTFILENAME-1"`
    OUTDIR2=`mktemp -d -t "$INPUTFILENAME-2"`

    ######################################
    # get dpi of pdf:
    ######################################
    #echo "${DECO_STEP}"
    echo "${DECO_BEGIN}dpi of input pdf${DECO_END}"
    magick identify -monitor -format "%w x %h %x x %y\n" "$INPUTFILE"

    ######################################
    # CONVERT PDF TO PNGs
    ######################################
    #echo "${DECO_STEP}"
    echo "${DECO_BEGIN}CONVERT PDF PAGES TO PNG(s)...${DECO_END}"
    pdf2pngs "$INPUTFILE" "$OUTDIR1" "$DPI"


    ######################################
    # ADD MARGINS TO PNGs
    ######################################
    #echo "${DECO_STEP}"
    echo "${DECO_BEGIN}ADD MARGINS TO PNG(s)...${DECO_END}"
    addMarginToPNGs "$OUTDIR1" "$OUTDIR2" "$((DPI/2))" `python -c "print('{0:0.4f}'.format($BOOK_HEIGHT / $BOOK_WIDTH))"`

    ######################################
    # CONVERT PNGs to PDF
    ######################################
    #echo "${DECO_STEP}"
    echo "${DECO_BEGIN}CONVERT PNGs to PDF...${DECO_END}"
    echo " - silent while loading PNGs"
    echo " - outputs % for each generated PDF page"
    magick convert -monitor "$OUTDIR2/"*.png -alpha off -set units $DPI -quality 60 -compress jpeg "${OUTPATH}"

    # comparison of [jpeg, lzw, rle, zip] compression schemes:
    # -rw-r--r--  1 kevinmeinert  staff    81861538 Apr  1 09:09 grow-jpeg.pdf
    # -rw-r--r--  1 kevinmeinert  staff  1922920649 Apr  1 09:19 grow-lzw.pdf
    # -rw-r--r--  1 kevinmeinert  staff  2249930760 Apr  1 09:22 grow-rle.pdf
    # -rw-r--r--  1 kevinmeinert  staff  1190841219 Apr  1 09:13 grow-zip.pdf

    #####################################
    # remove tempdirs
    cleanup

    #####################################
    # open the new pdf
    echo "${DECO_BEGIN}Opening '${OUTPATH}'${DECO_END}"
    open "${OUTPATH}"
  done
}

process

