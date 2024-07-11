#!/bin/bash

# this script's dir (and location of the other tools)
scriptpath=$0
scriptname=`basename "$0"`
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cwd=`pwd`

source "$scriptdir/functions.sh"

# options:
args=()
VERBOSE=false
ASSETFILE="assets.dat"
INDEX_ONLY=0

################################
# scan command line args:
function usage
{
  echo "$scriptname  make book pdfs"
  echo "Usage:"
  echo "  $scriptname <indir>                 (directory full of .pdf files)"
  echo "  $scriptname <outdir>                (optional: output book pdfs here.  default (inferred from indir))"
  echo "  $scriptname --index                 (index only)"
  echo "  $scriptname --help                  (this help)"
  echo "  $scriptname --verbose               (output verbose information)"
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
  if [[ $ARGC -ge 1 && ${ARGV[$i]} == "--index" ]]; then
    INDEX_ONLY=1
    echo "Generating index only"
    continue
  fi
  if [[ $ARGC -ge 1 && ${ARGV[$i]} == "--verbose" ]]; then
    VERBOSE=true
    continue
  fi
  if [[ $ARGC -ge 1 && ${ARGV[$i]:0:2} == "--" ]]; then
    echo "Unknown option ${ARGV[$i]}"
    exit -1
  fi

  args+=("${ARGV[$i]}")
  $VERBOSE && echo "Parsing Args: \"${ARGV[$i]}\""
  ((non_flag_args+=1))
done

# output help if they're getting it wrong...
if [ $non_flag_args_required -ne 0 ] && [[ $ARGC -eq 0 || ! $ARGC -ge $non_flag_args_required ]]; then
  [ $ARGC -gt 0 ] && echo "Expected $non_flag_args_required args, but only got $ARGC"
  usage
  exit -1
fi

####################################################################
if [ ${#args[@]} -gt 0 ]; then
  INDIR="${args[0]}"
  if [[ ! "$INDIR" =~ -download ]]; then
    echo "in dir is expected to have '-download' in the name, sorry!"
    exit -1
  fi
  if [[ "$INDIR" != /* ]]; then
    INDIR="$cwd/$INDIR"
  fi
fi
OUTDIR="$(echo "$INDIR" | sed  "s/-download//")-books"
if [ ${#args[@]} -gt 1 ]; then
  OUTDIR="${args[1]}"
fi
echo "In Dir:   \"${INDIR}\""
echo "Book Dir: \"${OUTDIR}\""
####################################################################


mkdir -p "${OUTDIR}"
cd "${OUTDIR}"

# make books:
if [ "$INDEX_ONLY" == "0" ]; then
  shopt -s nullglob
  CMD="$scriptdir/pdf_slidedeck2book.sh \"../${INDIR}/\"*\".pdf\""
  #echo "$CMD"
  eval "$CMD"
  shopt -u nullglob
fi

function encodeURI() {
  local uri="$1"
  node -e "console.log( encodeURI( \"$uri\" ) )"
}

function escapeHTML() {
  local str="$1"
  str=$(echo "$str" | sed -e "s/&/\\&amp;/g")
  str=$(echo "$str" | sed -e "s/</\\&lt;/g")
  str=$(echo "$str" | sed -e "s/>/\\&gt;/g")
  str=$(echo "$str" | sed -e "s/'/\\&#39;/g")
  str=$(echo "$str" | sed -e "s/\"/\\&quot;/g")
  str=$(echo "$str" | sed -e "s/’/\\&#146;/g")
  echo "$str"
}

# Usage: generate_index *.pdf
function generate_index() {
  local FILES=("$@")

  local INDEXFILE="index-simple-listing.html"
  echo "Writing \"$INDEXFILE\" into $(pwd)"
  echo "<ul>" > "$INDEXFILE"
  for f in "${FILES[@]}"; do
    echo "---> $f"
    local f=$(echo "$f" | sed "s/^.*\///")
    echo "---> $f"
    local t=$(echo "$f" | sed "s/^.*\///" | sed "s/-book-[0-9]*-[0-9]*\..*$//")
    echo "===> $t"
    echo "<li><a href=\"$(encodeURI "$f")\">$(escapeHTML "$t")</a>" >> "$INDEXFILE"
  done
  echo "</ul>" >> "$INDEXFILE"

  if [ -f "../$INDIR/index-public2.html"
  INDEXFILE="index.html"
  cp "$INDIR/index-public2.html" "$INDEXFILE"
}

# generate index
generate_index *.pdf

cd -

