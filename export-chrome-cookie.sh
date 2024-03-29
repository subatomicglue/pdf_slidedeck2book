#!/bin/bash
#
# Remixed from https://gist.github.com/nicerobot/1443588
#
# Usage:
#    * export-chrome-cookie.sh
#    * export-chrome-cookie.sh <domain>
#      <domain> examples:
#        .google.com
#        %.google.com (SQLite wildcard)
#        %.com

# The path for MAC!
CHROME="${HOME}/Library/Application Support/Google/Chrome/Default"
echo $CHROME
COOKIES="$CHROME/Cookies"
echo ${COOKIES:-Cookies}

QUERY='select host_key, "TRUE", path, "FALSE", expires_utc, name, value from cookies'

if [[ $# == 1 ]]; then
    domain=$1
    QUERY="$QUERY where host_key like '$domain'"
fi
echo $QUERY

echo "# Netscape HTTP Cookie File" > cookies.txt
sqlite3 -separator '	' "${COOKIES:-Cookies}" "$QUERY" >> cookies.txt

