#!/bin/bash
#version=2.0.0

function printTable()
{
  local -r delimiter="${1}"
  local -r data="$(removeEmptyLines "${2}")"

  if [[ "${delimiter}" != '' && "$(isEmptyString "${data}")" = 'false' ]]; then
    local -r numberOfLines="$(wc -l <<< "${data}")"

    if [[ "${numberOfLines}" -gt '0' ]]; then
      local table=''
      local i=1

      for ((i = 1; i <= "${numberOfLines}"; i = i + 1))
      do
        local line=''
        line="$(sed "${i}q;d" <<< "${data}")"

        local numberOfColumns='0'
        numberOfColumns="$(awk -F "${delimiter}" '{print NF}' <<< "${line}")"

        if [[ "${i}" -eq '1' ]]; then
          table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
        fi

        table="${table}\n"

        local j=1

        for ((j = 1; j <= "${numberOfColumns}"; j = j + 1)); do
          table="${table}$(printf '#| %s' "$(cut -d "${delimiter}" -f "${j}" <<< "${line}")")"
        done

        table="${table}#|\n"

        if [[ "${i}" -eq '1' ]] || [[ "${numberOfLines}" -gt '1' && "${i}" -eq "${numberOfLines}" ]]; then
          table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
        fi
      done

      if [[ "$(isEmptyString "${table}")" = 'false' ]]; then
        echo -e "${table}" | column -s '#' -t | awk '/^\+/{gsub(" ", "-", $0)}1'
      fi
    fi
  fi
}

function removeEmptyLines()
{
  local -r content="${1}"

  echo -e "${content}" | sed '/^\s*$/d'
}

function repeatString()
{
  local -r string="${1}"
  local -r numberToRepeat="${2}"

  if [[ "${string}" != '' && "${numberToRepeat}" =~ ^[1-9][0-9]*$ ]]; then
    local -r result="$(printf "%${numberToRepeat}s")"
    echo -e "${result// /${string}}"
  fi
}

function isEmptyString()
{
  local -r string="${1}"

  if [[ "$(trimString "${string}")" = '' ]]; then
    echo 'true' && return 0
  fi

  echo 'false' && return 1
}

function trimString()
{
  local -r string="${1}"

  sed 's,^[[:blank:]]*,,' <<< "${string}" | sed 's,[[:blank:]]*$,,'
}

RESTART_HEADER="Scope|Reason|Created At"

if [ -f /storage/var/jpiadmapi/restart.db3 ]; then
  RESTART_DATA="`/usr/bin/sqlite3 /storage/var/jpiadmapi/restart.db3 \"select scope,reason,created_at from history where restart_complete=0\"`"
else
  RESTART_DATE=""
fi

clear
echo "+----------------+"
echo "|  RESTART INFO  |"

if [ "$RESTART_DATA" == "" ]; then
  echo "+----------------+"
  echo "| No data found. |"
  echo "+----------------+"
else
  printTable '|' "$RESTART_HEADER\n$RESTART_DATA"
fi

echo ""
read -p "Press ENTER key to return System Info..."
