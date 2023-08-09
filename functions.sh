# source this file from your bash .sh script

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
    local URL="https://docs.google.com/document/d/$ID/export/$DOC_TYPE"
  elif [ "$TYPE" == "file" ]; then
    local URL="https://drive.google.com/uc?export=download&id=$ID"
  else
    echo "not enough args supplied."
    return -1
  fi

  # use external cookie.txt file:
  #local COOKIES=""
  #if [ -f "./cookies.txt" ]; then COOKIES="--use-cookies --load-cookies ./cookies.txt"; fi
  #if [ -f "/tmp/cookies.txt" ]; then COOKIES="--use-cookies --load-cookies /tmp/cookies.txt"; fi

  echo ""
  echo "URL: $URL"
  echo ""

  # simple download (doesn't work for large files)
  #CMD="wget --no-check-certificate $COOKIES \"$URL&confirm=yes\" -O \"$OUTFILE\""

  # large file download (uses cookie file to bypass some security thing):
  CMD="wget --load-cookies /tmp/cookies.txt \"https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate "https://docs.google.com/uc?export=download&id=$ID" -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=$ID\" -O \"$OUTFILE\"; rm /tmp/cookies.txt"
  echo "$CMD"
  eval "$CMD"

  if [ `file --mime-type -b "$OUTFILE"` == "text/html" ]; then
    echo ""
    echo "====================== WARNING ======================"
    echo "Your file downloaded with mimetype text/html"
    echo "It's likely your file isn't shared as \"anyone with the link can view\""
    echo ""
    echo "  cat \"$OUTFILE\""   # <-- will show .html data, likely a sign in page
    echo ""
  fi
}

