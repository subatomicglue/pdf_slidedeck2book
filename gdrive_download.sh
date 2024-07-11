#!/bin/bash

# this script's dir (and location of the other tools)
scriptpath=$0
scriptname=`basename "$0"`
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cwd=`pwd`

####
source "$scriptdir/functions.sh"
PDF2BOOK_CMD="$scriptdir/pdf_slidedeck2book.sh"
dt=`filename_date`
OUT="./${dt}-out-download"

# options:
args=()
VERBOSE=false
ASSETFILE="assets.dat"

################################
# scan command line args:
function usage
{
  echo "$scriptname  download google drive URLs as exported [docx, pptx, pdfs] files"
  echo "Usage:"
  echo "  $scriptname <outdir> <assets.dat>   (outdir; gdrive URLs & titles)"
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
  echo "Setting outdir to ${args[0]}"
  OUT="${args[0]}"
  if [[ ! "$OUT" =~ -download ]]; then
    echo "out dir is expected to have '-download' in the name, sorry!"
    exit -1
  fi
  OUT2=`echo "$OUT" | sed  "s/-download/-books/"`
  echo "Setting bookdir to ${OUT2}"
fi
if [ ${#args[@]} -gt 1 ]; then
  echo "Setting assetfile to ${args[1]}"
  ASSETFILE=${args[1]}
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
source "${ASSETFILE}" # should define URL_LIST

#################################################################333

echo "Downloading to: \"${OUT}\""
mkdir -p "${OUT}"
cd "${OUT}"

if ! google_download_multiple_artifacts "${URL_LIST[@]}"; then
  echo "[FAILED] to download"
  echo "Command:"
  echo "   google_download_multiple_artifacts \"${URL_LIST[@]}\""
  echo ""
  echo "URL List:"
  echo "${URL_LIST[@]}"
  echo ""
  exit -1
fi

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
  local kind=""

  echo "Writing index.html into $(pwd)"
  echo "<ul>" > index.html
  echo "<ul>" > index-public.html
  for (( i = 0; i < ${URL_LIST_COUNT}; i = i + 3 )); do
    if [ "${URL_LIST[$i]}" == "" ]; then
      echo "</ul><ul>" >> index.html
      echo "</ul><ul>" >> index-public.html
      continue
    fi
    local id=`google_download_id "${URL_LIST[$i]}"`
    local type=`google_download_type "${URL_LIST[$i]}"`
    if [ "$type" == "presentation" ]; then
      ext="pptx"
      kind="slide"
    elif [ "$type" == "document" ]; then
      ext="docx"
      kind="doc"
    else
      echo "wtf"
      exit -1
    fi
    google_type_url=`google_drive_to_url "$kind" "$id" "$ext"`
    google_pdf_url=`google_drive_to_url "$kind" "$id" "pdf"`
    local INPUTFILETIME=`filename_timestamp_file "${URL_LIST[$i + 1]}.pdf"`
    local ANNOTATION="${URL_LIST[$i + 2]}"
    echo "<li><strong>${URL_LIST[$i + 1]}</strong> - [google link to <a href=\"${URL_LIST[$i]}\">$kind</a>; <a href=\"$google_type_url\">$ext</a>; <a href=\"$google_pdf_url\">pdf</a>]  [<a href=\"${URL_LIST[$i + 1]}.$ext\">$ext</a>; <a href=\"${URL_LIST[$i + 1]}.pdf\">pdf</a>]  [<a href=\"../out-books/${URL_LIST[$i + 1]}-book-$INPUTFILETIME.pdf\">book</a>] - $ANNOTATION " >> index.html
    echo "<li><strong>${URL_LIST[$i + 1]}</strong> - [ <a href=\"${URL_LIST[$i]}\">$kind</a>; <a href=\"$google_type_url\">$ext</a>; <a href=\"$google_pdf_url\">pdf</a>] - $ANNOTATION " >> index-public.html
  done
  echo "</ul>" >> index.html
  echo "</ul>" >> index-public.html
}

generate_index "${URL_LIST[@]}"
cd -

