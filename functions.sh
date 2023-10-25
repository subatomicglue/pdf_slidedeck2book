# source this file from your bash .sh script

# a date string you can use in filenames YYYYMMDD-HHMMSS
function filename_timestamp {
  date '+%Y%m%d-%H%M%S'
}

# a date string you can use in filenames YYYYMMDD
function filename_date {
  date '+%Y%m%d'
}

# a date string you can use in filenames YYYYMMDD-HHMMSS
function filename_timestamp_file {
  local filename="$1"
  date -r "$filename" '+%Y%m%d-%H%M%S'
}

# a date string you can use in filenames YYYYMMDD
function filename_date_file {
  local filename="$1"
  date -r "$filename" '+%Y%m%d'
}

function google_download {
  if [[ "$#" -lt 3 || "$#" -gt 4 ]]; then
    echo "${FUNCNAME[0]}"
    echo "  ${FUNCNAME[0]} <doc|slide|file> <google slides id> <output filename> <required for doc or slide:  pdf|pptx|docx>"
    echo ""
    return
  fi

  local TYPE="$1"; # slide, doc, file
  local ID="$2";
  local OUTFILE="$3";
  local DOC_TYPE="pdf";
  if [[ "$#" -eq 4 ]]; then
    DOC_TYPE="$4"; # pdf|pptx|docx
  fi

  if [ "$TYPE" == "slide" ]; then
    local URL="https://docs.google.com/presentation/d/$ID/export/$DOC_TYPE"
  elif [ "$TYPE" == "doc" ]; then
    local URL="https://docs.google.com/document/d/$ID/export/$DOC_TYPE?format=$DOC_TYPE"
  elif [ "$TYPE" == "file" ]; then
    local URL="https://drive.google.com/uc?export=download&confirm=yes&id=$ID"
  else
    echo "not enough args supplied."
    return -1
  fi

  # use external cookie.txt file:
  #local COOKIES=""
  #if [ -f "./cookies.txt" ]; then COOKIES="--use-cookies --load-cookies ./cookies.txt"; fi
  #if [ -f "/tmp/cookies.txt" ]; then COOKIES="--use-cookies --load-cookies /tmp/cookies.txt"; fi

  if [ -f "${OUTFILE}" ]; then
    echo "Skipping: Download -> \"${OUTFILE}\" (exists)";
    return -1;
  fi

  echo ""
  echo "URL: $URL"
  echo "Downloading google $TYPE $ID -> $OUTFILE"
  echo ""

  local QUIET="-q --show-progress"

  # simple download (doesn't work for large files)
  CMD="wget --timestamping $QUIET --no-check-certificate $COOKIES \"$URL\" -O \"$OUTFILE\""

  # large file download (uses cookie file to bypass some security thing):
  #CMD="wget $QUIET --load-cookies /tmp/cookies.txt \"${URL}&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate "${URL}" -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=$ID\" -O \"$OUTFILE\"; rm /tmp/cookies.txt"
  #echo "$CMD"
  eval "$CMD"

  if [ ! -f "$OUTFILE" ]; then
    echo "$CMD"
    echo "couldn't download \"$OUTFILE\""
    exit -1;
  fi

  if [ `file --mime-type -b "$OUTFILE"` == "text/html" ]; then
    echo ""
    echo "====================== WARNING ======================"
    echo "Your file downloaded with mimetype text/html"
    echo "It's likely your file isn't shared as \"anyone with the link can view\""
    echo ""
    echo "  cat \"$OUTFILE\""   # <-- will show .html data, likely a sign in page
    echo ""
  fi

  if [ ! -f "${OUTFILE}" ]; then
    echo "File did not Download!! \"${OUTFILE}\" (see above errors)";
    return -1;
  fi
}

function google_download_presentation_artifacts {
  if [[ "$#" -lt 2 || "$#" -gt 2 ]]; then
    echo "${FUNCNAME[0]}"
    echo "  ${FUNCNAME[0]} <google drive url to presentation>  <name for the output file>"
    echo ""
    return
  fi
  local id="$1"
  local filename="$2"

  google_download slide "${id}" "${filename}.pdf" pdf
  google_download slide "${id}" "${filename}.pptx" pptx
}

function google_download_document_artifacts {
  if [[ "$#" -lt 2 || "$#" -gt 2 ]]; then
    echo "${FUNCNAME[0]}"
    echo "  ${FUNCNAME[0]} <google drive url to document>  <name for the output file>"
    echo ""
    return
  fi
  local id="$1"
  local filename="$2"

  google_download doc "${id}" "${filename}.pdf" pdf
  google_download doc "${id}" "${filename}.docx" docx
}

function google_download_type {
  local URL="$1"
  local result=`echo "$URL" | sed -r -e 's/^https?:\/\/.*\/(document|presentation)\/d\/([^/]+)\/.*$/\1/g'`
  echo $result
}

function google_download_id {
  local URL="$1"
  local result=`echo "$URL" | sed -r -e 's/^https?:\/\/.*\/(document|presentation)\/d\/([^/]+)\/.*$/\2/g'`
  echo $result
}

function google_download_artifacts {
  if [[ "$#" -lt 2 || "$#" -gt 2 ]]; then
    echo "${FUNCNAME[0]}"
    echo "  ${FUNCNAME[0]} <google drive url to slide or doc>  <name for the output file>"
    echo ""
    return
  fi
  local URL="$1"
  local OUTFILE="$2"
  local type=`google_download_type "$URL"`
  local id=`google_download_id "$URL"`

  #echo "type=$type"
  #echo "id=$id"
  if [ "$type" == "presentation" ]; then
    google_download_presentation_artifacts "$id" "$OUTFILE"
  elif [ "$type" == "document" ]; then
    google_download_document_artifacts "$id" "$OUTFILE"
  fi
}

# process an array:
#
# URL_LIST=( \
# "https://docs.google.com/document/d/<id1>/edit?usp=sharing" "My Happy File 1" \
# "https://docs.google.com/document/d/<id2>/edit?usp=sharing" "My Happy File 2" \
# "https://docs.google.com/document/d/<id3>/edit?usp=sharing" "My Happy File 3" \
# )
#
# google_download_multiple_artifacts "${URL_LIST[@]}"
function google_download_multiple_artifacts() {
  local URL_LIST=("$@")
  local URL_LIST_COUNT=${#URL_LIST[@]}
  local i=0;

  echo "====================== here ${URL_LIST_COUNT}"
  for (( i = 0; i < ${URL_LIST_COUNT}; i = i + 2 )); do
    google_download_artifacts "${URL_LIST[$i]}" "${URL_LIST[$i + 1]}"
  done
}

