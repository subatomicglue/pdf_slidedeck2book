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

################################
# scan command line args:
function usage
{
  echo "$scriptname  make book pdfs"
  echo "Usage:"
  echo "  $scriptname <indir>                 (directory full of .pdf files)"
  echo "  $scriptname <outdir>                (optional: output book pdfs here.  default (inferred from indir))"
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
shopt -s nullglob
CMD="$scriptdir/pdf_slidedeck2book.sh \"../${INDIR}/\"*\".pdf\""
#echo "$CMD"
eval "$CMD"
shopt -u nullglob

# Usage: generate_index *.pdf
function generate_index() {
  local FILES=("$@")

  echo "Writing index.html into $(pwd)"
  echo "<ul>" > index.html
  echo "<ul>" > index-secret.html
  for f in "${FILES[@]}"; do
    echo "---> $f"
    local f=$(echo "$f" | sed "s/^.*\///")
    echo "---> $f"
    local t=$(echo "$f" | sed "s/^.*\///" | sed "s/-book-[0-9]*-[0-9]*\..*$//")
    echo "===> $t"
    echo "<li><a href=\"$f\">$t</a>" >> index.html

    # secret:
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
    echo "<li><strong>${URL_LIST[$i + 1]}</strong> - [google link to <a href=\"${URL_LIST[$i]}\">$kind</a>; <a href=\"$google_type_url\">$ext</a>; <a href=\"$google_pdf_url\">pdf</a>]  [<a href=\"${URL_LIST[$i + 1]}.$ext\">$ext</a>; <a href=\"${URL_LIST[$i + 1]}.pdf\">pdf</a>]  [<a href=\"$t\">book</a>] " >> index-secret.html
  done
  echo "</ul>" >> index.html
  echo "</ul>" >> index-secret.html
}

# generate index
generate_index *.pdf

cd -

