# source this file from your bash .sh script


function google_download {
  if [[ "$#" -lt 3 || "$#" -gt 4 ]]; then
    echo "${FUNCNAME[0]}"
    echo "  ${FUNCNAME[0]} <doc|slide|file> <google slides id> <output filename> <pdf|pptx|docx>"
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
    local URL="https://docs.google.com/document/d/$ID/export/$DOC_TYPE"
  elif [ "$TYPE" == "file" ]; then
    local URL="https://drive.google.com/uc?export=download&id=$ID"
  else
    echo "not enough args supplied."
    return -1
  fi

  # handle large files with CONFIRM
  #local CONFIRM=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate '"'$URL'"' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p');
  #echo "CONFIRM: " $CONFIRM;
  #if [ "$CONFIRM" -ne "" ]; then
  #  URL="$URL&confirm=$CONFIRM";
  #fi

  echo "$URL"
  # --load-cookies cookies.txt
  wget --no-check-certificate --load-cookies /tmp/cookies.txt "$URL" -O "$OUTFILE"
}

