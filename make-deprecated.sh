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
  echo "$scriptname  download google slide/docs pdfs, make book pdfs (deprecated - requires public access set in gdrive)"
  echo "Usage:"
  echo "  $scriptname <outdir> <assets.dat>   (list of pdf files to process; outdir)"
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
    echo "outdir is expected to have '-download' in the name, sorry!"
    exit -1
  fi
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


"${scriptdir}"/gdrive_download.sh "${OUT}" "${ASSETFILE}"

"${scriptdir}"/make_books.sh "${OUT}"

