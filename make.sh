#!/bin/bash

# this script's dir (and location of the other tools)
scriptpath=$0
scriptname=`basename "$0"`
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cwd=`pwd`

####
source "node_modules/pdf_slidedeck2book/functions.sh"
PDF2BOOK_CMD="node_modules/pdf_slidedeck2book/pdf_slidedeck2book.sh"
dt=`filename_timestamp`
OUT="./out-download-${dt}"
OUT2="./out-books"

# options:
args=()
VERBOSE=false
ASSETFILE="assets.dat"

################################
# scan command line args:
function usage
{
  echo "$scriptname  download google slide/docs pdfs, make book pdfs"
  echo "Usage:"
  echo "  $scriptname <assets.dat> <outdir>   (list of pdf files to process; outdir)"
  echo "  $scriptname --help                  (this help)"
  echo "  $scriptname --verbose               (output verbose information)"
  echo ""
}
ARGC=$#
ARGV=("$@")
non_flag_args=0
non_flag_args_required=0
for ((i = 0; i < ARGC; i++)); do
  if [[ $ARGC -ge 1 && ${ARGV[$i]} == "--help" ]]; then
    usage
    exit -1
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



#################################################################333

if [ ${#args[@]} -gt 0 ]; then
  echo "Setting assetfile to ${args[0]}"
  ASSETFILE=${args[0]}
fi
if [ ${#args[@]} -gt 1 ]; then
  echo "Setting outdir to ${args[1]}"
  OUT=${args[1]}
fi
if [ ! -f "$ASSETFILE" ]; then
  echo "\"${ASSETFILE}\" not found"
  echo "  "
  echo "example:"
  echo "  "
  echo "URL_LIST=( \\
\"https://docs.google.com/document/d/<some id here>/edit?usp=sharing\" \"My Happy Document\" \\
)"

  exit -1
fi
source "${ASSETFILE}"

#################################################################333

echo "Downloading to: \"${OUT}\""
mkdir -p "${OUT}"
cd "${OUT}"

google_download_multiple_artifacts "${URL_LIST[@]}"

# generate index.html:
#
# URL_LIST=( \
# "https://docs.google.com/document/d/<id1>/edit?usp=sharing" "My Happy File 1" \
# "https://docs.google.com/document/d/<id2>/edit?usp=sharing" "My Happy File 2" \
# "https://docs.google.com/document/d/<id3>/edit?usp=sharing" "My Happy File 3" \
# )
#
# generate_index "${URL_LIST[@]}"
function generate_index() {
  local URL_LIST=("$@")
  local URL_LIST_COUNT=${#URL_LIST[@]}
  local i=0;
  local ext=""

  echo "Writing index.html into $(pwd)"
  echo "<ul>" > index.html
  for (( i = 0; i < ${URL_LIST_COUNT}; i = i + 2 )); do
    local type=`google_download_type "${URL_LIST[$i]}"`
    if [ "$type" == "presentation" ]; then
      ext="pptx"
    elif [ "$type" == "document" ]; then
      ext="docx"
    fi
    local INPUTFILETIME=`filename_timestamp_file "${URL_LIST[$i + 1]}.pdf"`
    echo "<li><a href=\"${URL_LIST[$i]}\">${URL_LIST[$i + 1]}</a> [<a href=\"${URL_LIST[$i + 1]}.$ext\">$ext</a>] [<a href=\"${URL_LIST[$i + 1]}.pdf\">pdf</a>] [<a href=\"../out-books/${URL_LIST[$i + 1]}-book-$INPUTFILETIME.pdf\">book</a>]" >> index.html
  done
  echo "</ul>" >> index.html
}

generate_index "${URL_LIST[@]}"
cd -

#################################################################333

mkdir -p "${OUT2}"
cd "${OUT2}"

shopt -s nullglob
FILES=("../${OUT}/"*".pdf")
shopt -u nullglob
CMD="../$PDF2BOOK_CMD $(printf "'%s' " "${FILES[@]}")"
#echo "$CMD"
eval "$CMD"

# generate index.html:
#
# URL_LIST=( \
# "https://docs.google.com/document/d/<id1>/edit?usp=sharing" "My Happy File 1" \
# "https://docs.google.com/document/d/<id2>/edit?usp=sharing" "My Happy File 2" \
# "https://docs.google.com/document/d/<id3>/edit?usp=sharing" "My Happy File 3" \
# )
#
# generate_index "${URL_LIST[@]}"
function generate_index() {
  local URL_LIST=("$@")
  local URL_LIST_COUNT=${#URL_LIST[@]}
  local i=0;
  local ext=""

  echo "Writing index.html into $(pwd)"
  echo "<ul>" > index.html
  for (( i = 0; i < ${URL_LIST_COUNT}; i = i + 2 )); do
    local type=`google_download_type "${URL_LIST[$i]}"`
    if [ "$type" == "presentation" ]; then
      ext="pptx"
    elif [ "$type" == "document" ]; then
      ext="docx"
    fi
    local INPUTFILETIME=`filename_timestamp_file "../out-download/${URL_LIST[$i + 1]}.pdf"`
    echo "<li><a href=\"${URL_LIST[$i]}\">${URL_LIST[$i + 1]}</a> [<a href=\"${URL_LIST[$i + 1]}-book-$INPUTFILETIME.pdf\">book</a>]" >> index.html
  done
  echo "</ul>" >> index.html
}

generate_index "${URL_LIST[@]}"

cd -

