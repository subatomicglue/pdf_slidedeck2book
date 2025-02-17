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

# give a URL to a google drive file
# returns a URL to an exported docx|pptx or pdf
function google_drive_to_url {
  if [[ "$#" -lt 3 || "$#" -gt 4 ]]; then
    echo "${FUNCNAME[0]}"
    echo "  ${FUNCNAME[0]} <doc|slide|file> <google slides id> <doctype pdf|pptx|docx>"
    echo ""
    return
  fi

  local TYPE="$1"; # slide, doc, file
  local ID="$2";
  local DOC_TYPE="pdf";
  if [[ "$#" -eq 3 ]]; then
    DOC_TYPE="$3"; # pdf|pptx|docx
  fi

  if [ "$TYPE" == "slide" ]; then
    local URL="https://docs.google.com/presentation/d/$ID/export/$DOC_TYPE"
  elif [ "$TYPE" == "doc" ]; then
    local URL="https://docs.google.com/document/d/$ID/export/$DOC_TYPE?format=$DOC_TYPE"
  elif [ "$TYPE" == "file" ]; then
    local URL="https://drive.google.com/uc?export=download&confirm=yes&id=$ID"
  else
    local URL ""
  fi

  echo "$URL"
}

# Log in to the server.  This only needs to be done once.
#wget --save-cookies cookies.txt \
#     --keep-session-cookies \
#     --post-data 'user=foo&password=bar' \
#     --delete-after \
#     http://server.com/auth.php

# Now grab the page or pages we care about.
#wget --load-cookies cookies.txt \
#     http://server.com/interesting/article.php

# wrks for drive:
# wget --no-check-certificate --timestamping --show-progress  --load-cookies cookies.txt "https://drive.google.com/uc?export=download&confirm=yes&id=1gUPCF0XYxiXxzhq8Fsu25GuD2KldH396PgtzyrRLXwU"
#
# doesnt work for docs:
# wget --debug --max-redirect==99 --timestamping --show-progress --no-check-certificate --load-cookies cookies.txt --header="Referer: https://docs.google.com/" --header="Origin: https://docs.google.com" --header="Accept-Language: en-US,en;q=0.9" --user-agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36"  "https://docs.google.com/document/d/1AwR0QOmyTN9QU5L6uLissNDKm5Hm08Kd7xVB8XtqXG0/export/pdf?format=pdf" -O "Fan edits.pdf"

function google_download {
  if [[ "$#" -lt 3 || "$#" -gt 4 ]]; then
    echo "${FUNCNAME[0]}"
    echo "  ${FUNCNAME[0]} <doc|slide|file> <google slides id> <output filename> <required for doc or slide:  pdf|pptx|docx>"
    echo ""
    return
  fi

  local OUTFILE="$3";
  local URL=`google_drive_to_url "$1" "$2" "$4"`
  if [ "$URL" == "" ]; then
    echo "incorrect args supplied. google_drive_to_url \"$@\""
    return -1
  fi

  # use external cookie.txt file:
  local COOKIES=""
  if [ -f "./cookies.txt" ]; then COOKIES="--load-cookies ./cookies.txt"; fi
  if [ -f "../cookies.txt" ]; then COOKIES="--load-cookies ../cookies.txt"; fi
  #if [ -f "/tmp/cookies.txt" ]; then COOKIES="--use-cookies --load-cookies /tmp/cookies.txt"; fi

  if [ -f "${OUTFILE}" ]; then
    echo "Skipping: Download -> \"${OUTFILE}\" (exists)";
    return 0; # all good, we got it
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
  local retout=$(eval "$CMD" 2>&1)
  local retval=$?
  echo $retval
  if [ $retval -ne 0 ]; then
    echo "[FAILED] Download of \"$OUTFILE\" failed with $retval (check URL and sharing permissions)"
    echo "Command was:"
    echo "   $CMD"
    echo ""
    echo "Output was:"
    echo "   $retout"
    return -1;
  fi

  if [ ! -f "$OUTFILE" ]; then
    echo "[FAILED] couldn't download \"$OUTFILE\""
    echo "Command was:"
    echo "   $CMD"
    echo ""
    return -1;
  fi

  local file_size=$(wc -c <"$OUTFILE")
  if [ $file_size -eq 0 ]; then
    echo "[FAILED] couldn't download \"$OUTFILE\""
    echo "Command was:"
    echo "   $CMD"
    echo ""
    echo "[INFO] Removing 0 sized \"$OUTFILE\""
    rm "$OUTFILE"
    return -1;
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
  return 0
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

  if ! google_download slide "${id}" "${filename}.pdf" pdf; then
    echo "[FAILED] google_download slide \"${id}\" \"${filename}.pdf\" pdf"
    return -1
  fi
  if ! google_download slide "${id}" "${filename}.pptx" pptx; then
    echo "[FAILED] google_download slide \"${id}\" \"${filename}.pptx\" pptx"
    return -1
  fi
  return 0
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

  if ! google_download doc "${id}" "${filename}.pdf" pdf; then
    echo "[FAILED] google_download doc \"${id}\" \"${filename}.pdf\" pdf"
    return -1
  fi
  if ! google_download doc "${id}" "${filename}.docx" docx; then
    echo "[FAILED] google_download doc \"${id}\" \"${filename}.docx\" docx"
    return -1
  fi
  return 0
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
    if ! google_download_presentation_artifacts "$id" "$OUTFILE"; then
      echo "[FAILED] google_download_presentation_artifacts \"$id\" \"$OUTFILE\""
      return -1
    fi
  elif [ "$type" == "document" ]; then
    google_download_document_artifacts "$id" "$OUTFILE"
    if ! google_download_document_artifacts "$id" "$OUTFILE"; then
      echo "[FAILED] google_download_document_artifacts \"$id\" \"$OUTFILE\""
      return -1
    fi
  else
    echo "[FAILED] google_download_artifacts:  unknown type \"$type\" not handled"
    return -1
  fi
  return 0
}

# process an array:
#
# URL_LIST=( \
# "https://docs.google.com/document/d/<id1>/edit?usp=sharing" "My Happy File 1" "some comments" \
# "https://docs.google.com/document/d/<id2>/edit?usp=sharing" "My Happy File 2" "some comments" \
# "https://docs.google.com/document/d/<id3>/edit?usp=sharing" "My Happy File 3" "some comments" \
# )
#
# google_download_multiple_artifacts "${URL_LIST[@]}"
function google_download_multiple_artifacts() {
  local URL_LIST=("$@")
  local URL_LIST_COUNT=${#URL_LIST[@]}
  local USE_ID_NAMES=false
  local i=0;

  for (( i = 0; i < ${URL_LIST_COUNT}; i = i + 3 )); do
    #echo "${URL_LIST[$i]}"
    if [ "${URL_LIST[$i]}" == "true" ] || [ "${URL_LIST[$i]}" == "false" ]; then
      URL_LIST=("${URL_LIST[@]:1}")
      URL_LIST_COUNT=${#URL_LIST[@]}
      USE_ID_NAMES="${URL_LIST[$i]}"
      #echo "${URL_LIST[$@]}"
    fi
    # whitespace placeholders are skipped, they'll be used by index.html generator for list breaks.
    if [ "${URL_LIST[$i]}" != "" ]; then
      local name="${URL_LIST[$i + 1]}"
      local id="$(google_download_id "${URL_LIST[$i + 1]}")"
      local filename=$([ "${USE_ID_NAMES}" == "false" ] && echo "${URL_LIST[$i + 1]}" || echo $(google_download_id "${URL_LIST[$i + 1]}") )
      #echo "google_download_artifacts \"${URL_LIST[$i]}\" \"${filename}\""
      if ! google_download_artifacts "${URL_LIST[$i]}" "${filename}"; then
        echo "[FAILED] google_download_artifacts \"${URL_LIST[$i]}\" \"${filename}\""
        return -1
      fi
      if [ "${USE_ID_NAMES}" == "true" ]; then
        ln -s "${filename}" "${name}"  # make a pretty/readable name-link to the id-filename...
      fi
    fi
  done

  return 0
}

