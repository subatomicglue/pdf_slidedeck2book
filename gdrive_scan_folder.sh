#!/bin/bash

# this script's dir (and location of the other tools)
scriptpath=$0
scriptname=`basename "$0"`
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cwd=`pwd`

####
source "$scriptdir/functions.sh"
PDF2BOOK_CMD="$scriptdir/pdf_slidedeck2book.sh"

# options:
args=()
VERBOSE=false
ASSETFILE="assets.dat"

################################
# scan command line args:
function usage
{
  echo "$scriptname  scan google drive folder for doc and slide assets, output asset.dat"
  echo "Usage:"
  echo "  $scriptname <google drive dir>      (scan for gdoc/gslide files)"
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

INDIR="$HOME/Google Drive"
if [ ${#args[@]} -gt 0 ]; then
  INDIR="${args[0]}"
fi

#ls -1 -- ~/"Google Drive/"**/+(*.gslides|*.gdoc) | xargs -0 -L 1 echo | python3 -c "import re, sys, json;"$'\n'"for f in sys.stdin: f=f.rstrip(); c=(re.sub(  \"^\\s*//.*$\",\"\",open(f, 'r').read(),flags=re.MULTILINE ) if f !='' else ''); id=json.loads( c )['doc_id'] if c != '' else ''; n=re.sub(r'^.*/([^/]+)\.(gdoc|gslides)$',r'\1',f); t=re.sub(r'^.*/([^/]+)\.(gdoc|gslides)$',r'\2',f); print( '\"' + n + '\" ' + t + ' ' + id )"

echo "URL_LIST=( \\"
shopt -s extglob
shopt -s nullglob
#files=$("ls -1 -- \"$HOME/Google Drive/\"**/+(*.gslides|*.gdoc)")

files=("${INDIR}/"**/+(*.gslides|*.gdoc))
#echo "${#files[@]}"        # print array length
#echo "${files[@]}"         # print array elements
for f in "${files[@]}"
do
  id=$(echo "$f" | python3 -c "import re, sys, json;"$'\n'"for f in sys.stdin: f=f.rstrip(); c=(re.sub(  \"^\\s*//.*$\",\"\",open(f, 'r').read(),flags=re.MULTILINE ) if f !='' else ''); id=json.loads( c )['doc_id'] if c != '' else ''; print( id )")

  #name=$(echo "$f" | python3 -c "import re, sys, json;"$'\n'"for f in sys.stdin: f=f.rstrip(); n=re.sub(r'^.*/([^/]+)\.(gdoc|gslides)$',r'\1',f); print( n )")
  name=$(echo "$f" | sed "s/^.*\///" | sed "s/\..*$//")

  #typ=$(echo "$f" | python3 -c "import re, sys, json;"$'\n'"for f in sys.stdin: f=f.rstrip(); t=re.sub(r'^.*/([^/]+)\.(gdoc|gslides)$',r'\2',f); print( t )")
  typ=$(echo "$f" | sed "s/^.*\.\(gdoc\|gslides\)$/\1/")

  if [ "$typ" == "gdoc" ]; then
    echo "\"https://docs.google.com/document/d/$id/edit?usp=sharing\" \"$name\" \\"
  elif [ "$typ" == "gslides" ]; then
    echo "\"https://docs.google.com/presentation/d/$id/edit?usp=sharing\" \"$name\" \\"
  fi
done

echo ")"

