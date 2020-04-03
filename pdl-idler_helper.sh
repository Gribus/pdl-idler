#!/bin/bash
# pdl-idler_helper.sh (0.9026)
# Copyright (c) 2011-2016 byteframe@primarydataloop

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>

# source common and trap drop chat sigint
source ./pdl-idler_common.sh
VOICES=(awb rms slt kal16)
if [ ! -z ${1} ]; then
  DROP_CHAT=${1}
  finish()
  {
    stop_node_login ${DROP_CHAT}
  }
  sigint()
  {
    finish
    exit 1
  }
  trap sigint SIGINT SIGTERM
fi

server_command()
{
  # input command to server console through its screen session
  screen -S idler-server${1:(-2)} -p 0 -X stuff \
    "pdl-$(date +%H:%M:%S)$(printf \\r)${2}$(printf \\r)"
}

# stop if there are no farm clients remaining, or wait for consoles to change
declare -A ALERTS
NEW_ITEM_TIME=0
while true; do
  PGREP="$(pgrep -fa hl2\\.exe.*noshaderapi.*\+)"
  if [ -z "${PGREP}" ]; then
    break
  fi
  OLD_ITEM_TIME=${NEW_ITEM_TIME}
  unset NEW_ITEM_TIME
  CONS=$(ls -Hxt "${TF}"/con-* | sed -e "s/.*\/con-//" -e "s/\.log//")
  for ACCT in ${CONS}; do
    CON=share/${ACCT}/logs/${HOSTNAME}/con-${ACCT}.log
    if [ -z ${NEW_ITEM_TIME} ]; then
      NEW_ITEM_TIME=$(stat -c %Y "${CON}")
    fi
    if [ $(stat -c %Y "${CON}") -le ${OLD_ITEM_TIME} ]; then
      if [ ! -z ${SOUND} ]; then
        aplay "${TF}"/pdl/farm/sound/${SOUND%%^*} > /dev/null 2>&1 &
        SOUND="${SOUND#*^}"
      fi
      if [ ! -z "${SPEECH}" ]; then
        flite -voice ${VOICES[$(shuf -i 0-3 -n 1)]} -t "${SPEECH%%^*}"
        SPEECH="${SPEECH#*^}"
      else
        idler_sleep 1
      fi
      continue 2

    # check for a new alert if client is connected
    elif [[ ${PGREP} != *${ACCT}+* ]]; then
      ALERTS[${ACCT}]=0
    elif client_connection > /dev/null; then
      ALERT=$(grep -n _alert.wav "${CON}" | tail -n 1 | sed "s/:.*//")
      if [ "${ALERT}" != "${ALERTS[${ACCT}]}" ]; then
        set_account ${ACCT}

        # get item data, or wait on api failure and retry
        OPTS=$(player_items)
        ITEMS=$(echo "${OPTS}" | grep original_id | wc -l)
        SLOTS=$(echo "${OPTS}" | grep num_backpack_slots | grep -o \[0-9]*)
        if [[ "${OPTS}" != *status\":\ 1,* ]]; then
          tprint "${ACCT}: failed to download item data"
          if [ ${ACCT} = ${CONS##*[[:space:]]} ]; then
            idler_sleep 5
          fi
          continue 2

        # handle full backpack
        elif (( ${ITEMS} >= ${SLOTS} )); then
          if [[ "${DROP_DETERGE}" = *[1-9]* ]]; then
            tprint "${ACCT}: full inventory, deterging..." ${ITEMS}/${SLOTS}
            server_command "$(client_connection)" "sm_kick \"$(\
              steam_name)\" \"Cleaning Backpack... (${ITEMS}/${SLOTS})\""
            idler_stop
            stop_node_login
            wait_for_stop
            idler_deterge
            run_node_login
            idler_farm nodeterge
          else
            tprint "${ACCT}: full inventory, logging out..." ${ITEMS}/${SLOTS}
            server_command "$(client_connection)" "sm_kick \"$(\
              steam_name)\" \"Full Backpack (${ITEMS}/${SLOTS})\""
            idler_logout
          fi

        # update alert line number, find new items, then log
        else
          unset CHAT
          ALERTS[${ACCT}]=${ALERT}
          OPTS=$(echo "${OPTS}" | grep -B6 -A1000 inventory\":\ [03])
          ORIGINAL=($(echo "${OPTS}" | grep original_id | grep -o \[0-9]*))
          for ID in ${ORIGINAL[@]}; do
            if ! grep -q ${ID} share/${ACCT}/drops 2> /dev/null; then
              INVENTORY=$(echo "${OPTS}" | grep -A4 ${ID} | grep inventory \
                | grep -o \[0-9]*)
              if (( ${INVENTORY} >= 3221225472 )) || [ ${INVENTORY} = 0 ]; then
                echo ${ID} >> share/${ACCT}/drops
                INDEX=$(echo "${OPTS}" | grep -A1 ${ID} | grep defindex \
                  | grep -o \[0-9]*)
                ITEM=$(grep -PA500 "^\s*\t*\"${INDEX}\"" \
                  "${SMOD}"/configs/items.kv)
                NAME=$(echo "${ITEM}" | grep -m1 name.*\" \
                  | sed -e "s/[[:space:]]*\"name\"[[:space:]]*\"//" \
                  -e "s/\"[[:space:]]*//" -e 's/\r$//')
                WAV=$(echo "${ITEM}" | grep -m1 drop_sound \
                  | grep -o item_.*\\.wav || echo item_metal_pot_drop.wav)
                tprint "${ACCT}: \"${NAME#The }\" (#${INDEX})" \
                  $(echo ${WAV:5} | sed -e s/_drop.wav// -e s/_pickup.wav//)

                # queue sound and/or speech
                if [ ! -z ${3} ]; then
                  SOUND="${SOUND}ui/${WAV}^"
                  if echo "${ITEM}" | grep -Pm1 \
                  "^\t\t}|craft_class.*\"weapon|prefab.*weapon|crate\"" \
                  | grep -q }; then
                    SOUND="${SOUND}ui/item_notify_drop.wav^"
                  fi
                fi
                if [ ! -z ${4} ]; then
                  SPEECH="${SPEECH}${NAME}^"
                fi

                # announce item through server irc
                if [ ! -z ${2} ]; then
                  QUALITY=$(echo "${OPTS}" | grep -A3 ${ID} | grep quality \
                    | grep -o \[0-9]*)
                  server_command "${CONNECTION}" "itemevent \"$(\
                    steam_name)\" ${INDEX} ${QUALITY}"
                fi

                # construct chat line, then send
                if [ ! -z ${1} ]; then
                  CHAT="${CHAT}http://steamcommunity.com/profiles/${SUID}/inventory/#440_2_${ID}\n"
                fi
              fi
            fi
          done
          if [ ! -z ${CHAT} ]; then
            CHAT="ENTER_$(steam_name)\n${CHAT:0:(-2)}__n"
            echo -e ${CHAT/\\\nhttp/ http} >> share/${1}/node.log
          fi
        fi
      fi
    fi
  done
done
finish 2> /dev/null
