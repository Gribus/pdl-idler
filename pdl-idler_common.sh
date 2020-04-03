#!/bin/bash
# pdl-idler_common.sh (0.9026)
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

# colored output with an optional right-aligned argument and padding
export TERM=xterm
b=$(tput bold) d=$(tput dim) u=$(tput smul)
v=$(tput rmul) z=$(tput sgr0)
r=$(tput setf 4) y=$(tput setaf 3) m=$(tput setf 5)
l=$(tput setf 3) p=$(tput setf 7) g=$(tput setaf 2)
x=$(tput setaf 9)
print()
{
  tput sc
  echo -en "${1}"
  tput rc
  PAD=${3}
  if [ -z ${3} ]; then
    PAD=$(($(echo -en "${2}" \
      | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" | wc -c)-2))
  fi
  tput cuf $(($(tput cols)-PAD))
  echo ${2}
  unset END_ECHO
  if [ ! -z ${4} ]; then
    tput cuu1
    tput cuf $(($(echo -en "${1}" \
      | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" | wc -c)-2))
    END_ECHO=yes
  fi
}

# print with a timestamp and duration since last call during action chain
ACTION_TIME=$(date +%s)
tprint()
{
  PRINT="${g}${1}"
  if [[ "${PRINT}" != *${ACCT}:* ]]; then
    PRINT="${g}<${HOSTNAME}>: ${1}"
  fi
  if [[ "${PRINT}" = *warning,* ]]; then
    PRINT="${PRINT/warning, /${y}warning,${x} } ${y}${b}{*}${z}${x}"
  fi
  if [[ "${PRINT}" = *error,* ]]; then
    PRINT="${PRINT/error, /${r}error,${x} } ${r}${b}{"'!}'"${z}${x}"
  fi
  if [[ "${PRINT}" = *fatal,* ]]; then
    PRINT="${PRINT/fatal, /${m}fatal,${x} } ${m}${b}{#}${z}${x}"
  fi
  print "${p}[$(date +%H:%M:%S)]${x} ${PRINT/:/${x}:${b}}${z}" \
    "${p}${u}+$(($(date +%s)-ACTION_TIME))s${z}${x}|${l}${2}${x}" "${3}" ${4}
}

steam_pid()
{
  # get pid of steam process with an optional command line string
  GET=${ACCT}
  if [ ! -z ${2} ]; then
    GET=${2}
  fi
  SPID=$(pgrep -fn "steam\\.exe -${GET} .*${1}")
  if [ -z ${SPID} ]; then
    return 1
  fi
  echo ${SPID}
}

window_id()
{
  # check existance and/or get id of a named window
  steam_pid > /dev/null
  for WID in $(xwininfo -all -root -children 2> /dev/null \
  | grep "${1}.*: (\"steam\\.exe" | awk '{print $1}'); do
    XPROP=$(xprop -id ${WID} 2> /dev/null)
    if echo "${XPROP}" | grep -q _PID.*\ ${SPID}; then
      if [ ! -z "${2}" ] && ! echo "${XPROP}" | grep -q ${3} "${2}"; then
        continue
      fi
      echo ${WID}
      return 0
    fi
  done
  unset WID
  return 1
}

idler_sleep()
{
  # wait for a period of time to elapse or until the user hits enter 3 times
  SLEEP=$(read -st ${1})
}

hl2_pid()
{
  # get pid of tf2 client process
  HPID=$(pgrep -fn "hl2\\.exe.*${1}.*${ACCT//./}\+")
  if [ -z ${HPID} ]; then
    return 1
  fi
  echo ${HPID}
}

memory()
{
  # get memory usage of a process via pid
  MEMORY=$(grep RSS /proc/${1}/status 2> /dev/null | grep -o \[0-9]*)
  if [ ! -z ${MEMORY} ]; then
    if [ ! -z ${2} ]; then
      MEMORY=$((${MEMORY}+${2}*1024))
    fi
    printf "${u}%03dm${v}\n" $((${MEMORY} / 1024))
  else
    echo 00m
  fi
}

steam_memory()
{
  # get memory usage of steam and web helper processes
  local WEB=00
  for WPID in $(pgrep -f steamwebhelper\\.exe); do
    if grep -q ${WINEPREFIX} /proc/${WPID}/environ; then
      let WEB+=$(($(grep RSS /proc/${WPID}/status | grep -o \[0-9]*)/1024))
    fi
  done
  memory ${SPID} ${WEB}
}

hl2_memory()
{
  # get memory usage of hl2 process
  memory ${HPID}
}

both_memory()
{
  # get memory usage of steam and hl2
  echo $(steam_memory)+$(hl2_memory)
}

node_login_pid()
{
  # get user node pid
  GET=${ACCT}
  if [ ! -z ${1} ]; then
    GET=${1}
  fi
  pgrep -f node\ share/${GET}/node.js
}

is_node_login_available()
{
  # check user node availability
  GET=${ACCT}
  if [ ! -z ${1} ]; then
    GET=${1}
  fi
  if grep -q //${HOSTNAME} share/${GET}/node.js 2> /dev/null \
  && ! node_login_pid ${GET} > /dev/null; then
    return 0
  elif [ -e share/${GET}/node.log ] \
  && ! tac share/${GET}/node.log | grep -q ^EXIT \
  && [ -z $(find share/${GET}/node.log -maxdepth 1 -mmin +1) ]; then
    return 1
  fi
  return 0
}

node_login_background()
{
  # get node background session type
  GET=${ACCT}
  if [ ! -z ${1} ]; then
    GET=${1}
  fi
  tac share/${GET}/node.log | grep -om 1 ^BREAK_.* | sed s/BREAK_//
}

stop_node_login()
{
  # end user node background session
  GET=${ACCT}
  if [ ! -z ${1} ]; then
    GET=${1}
  fi
  if node_login_pid ${GET} > /dev/null; then
    tprint "${GET}: ending node session..." \
      @$(node_login_pid ${GET}),$(node_login_background ${GET})
    kill $(node_login_pid ${GET})
  elif ! is_node_login_available ${GET}; then
    tprint "${GET}: ending node session..." $(grep -m1 \/\/ \
      share/${GET}/node.js | sed "s/.*\///"),$(node_login_background ${GET})
    echo QUIT >> share/${GET}/node.log
  fi
  while ! is_node_login_available ${GET}; do
    idler_sleep 1
  done
}

is_commandable()
{
  # check if a client has stopped the command aliases
  tac ${CON} | grep -m1 "Shutdown func\|pdl_aload\|pdl_astop" | grep -q aload
}

idler_stop()
{
  # end a background fake game session and/or quit/kill client process
  if ! is_node_login_available && [ "$(node_login_background)" = FAKE ] \
  && ! ps $(grep -m 1 //@ ${NODEJS} | grep -o \[0-9]*) | grep -q pdl-idler.*\\.sh; then
    stop_node_login
  fi
  if hl2_pid > /dev/null; then
    if [ "${1}" = yes ]; then
      STOP_TIMEOUT=121
      tprint "${ACCT}: killing client..." @${HPID},$(both_memory)
    else
      STOP_TIMEOUT=120
      if is_commandable; then
        tprint "${ACCT}: quitting client..." @${HPID},$(both_memory)
        STOP_TIMEOUT=0
        echo quit > "${ATF}"/pdl-${ACCT}/cfg/banned_ip.cfg
      fi
    fi
    while hl2_pid > /dev/null; do
      if [ ${STOP_TIMEOUT} = 120 ]; then
        tprint "${ACCT}: warning, killing client..." $(both_memory)
      elif [ ${STOP_TIMEOUT} = 121 ]; then
        kill -9 ${HPID}
      else
        idler_sleep 1
      fi
      let STOP_TIMEOUT+=1
    done
  fi
}

# get size on disk of the wineprefix and other account specific files
APPS=steam/steamapps
TF=${APPS}/common/Team\ Fortress\ 2/tf
account_size()
{
  echo $(du --apparent-size -ch share/${ACCT} wine-${ACCT} \
    "${TF}"/con-${ACCT}.log 2> /dev/null | grep total | awk '{print $1}')
}

auth_state()
{
  # get authentication state
  AUTH_STATE=$(tac ${LOGS}/connection_log.txt 2> /dev/null \
    | grep -m1 "Log session\|LogOnResponse" | grep -v session)
  if [[ ${AUTH_STATE} != *\'OK\'* ]]; then
    echo ${AUTH_STATE}
    return 1
  fi
  return 0
}

block_on_file()
{
  # lock or wait on a pid file for other invocations
  while true; do
    for LOCK in ${1}-*.lock; do
      if [ -e ${LOCK} ]; then
        if [ ${LOCK} != "${1}"-${HOSTNAME}.lock ] || ps $(cat ${LOCK}) \
        | grep -v "^[[:space:]]*$$ " | grep -q \ [ba]*sh\ .*pdl-idler.*\\.sh; then
          if [ -z ${BLOCKED} ]; then
            local BLOCKED=yes
            tprint "${ACCT}: warning, blocked file wait..." @$$/$(cat ${LOCK}),${1}
          fi
          idler_sleep 1.$(shuf -i 1-9 -n 1)
          continue 2
        fi
      fi
    done
    if [ ! -z ${2} ] && [ ! -z ${BLOCKED} ]; then
      return 1
    fi
    echo $$ > "${1}"-${HOSTNAME}.lock
    return 0
  done
}

focus_window()
{
  # block on display, then activate or focus a window by its id
  block_on_file .xdotool${DISPLAY:1}
  if [ ! -z ${1} ]; then
    if [ ${DISPLAY} != :0 ]; then
      xdotool windowraise ${1} windowfocus --sync ${1} \
        mousemove --window ${1} 3 3 click 1 2> /dev/null
      idler_sleep 0.4
    elif [ $(echo $((16#${1:2}))) != $(xdotool getwindowfocus) ]; then
      xdotool windowactivate --sync ${1} 2> /dev/null
    fi
  fi
}

close_window()
{
  # close a window by id
  if [ -z ${1} ] || ! window_id ${1} > /dev/null; then
    return 1
  fi
  if [ -z ${2} ]; then
    local ALTF4=Alt+F4
  fi
  if [ -z ${3} ]; then
    local MOUSE="mousemove --window ${1} 8 $(($(xwininfo -id ${1} 2> /dev/null \
      | grep Height | grep -o \[0-9]*)-8)) click --repeat 2 --delay 300 1"
  fi
  local KEY=Escape
  if [ -z ${4} ]; then
    KEY=Return
  fi
  focus_window ${1}
  while window_id ${1} > /dev/null && ! xprop -id ${1} | grep -q Withdrawn \
  && ! xwininfo -id ${1} | grep -q IsUnMapped; do
    let CLOSEWINDOW_TIMEOUT+=1
    if [ ${CLOSEWINDOW_TIMEOUT} = 1 ]; then
      xdotool ${MOUSE} key --window ${1} ${KEY} ${ALTF4} 2> /dev/null
    elif [ ${CLOSEWINDOW_TIMEOUT} == 3 ]; then
      unset CLOSEWINDOW_TIMEOUT
    fi
    idler_sleep 1
  done
  rm -f .xdotool${DISPLAY:1}-${HOSTNAME}.lock
  return 0
}

app_state()
{
  # get steam app state string or return nothing if not changing content
  local APPID=440
  if [ ! -z ${1} ]; then
    APPID=${1}
  fi
  STATE=$(tac ${LOGS}/content_log.txt 2> /dev/null | grep -om 1 \
    "Loaded [0-9]* apps\|AppID ${APPID} .*te changed.*," | grep -v Loaded)
  if [ ! -z "${STATE}" ] && [[ "${STATE}" != *Fully\ Installed, ]]; then
    echo ${STATE##*: }
    return 0
  fi
  return 1
}

wait_for_stop()
{
  # wait for steam if it still registers tf2 as running
  local WAIT_FOR_STOP_TIMEOUT
  while app_state | grep -q ,App\ Running,$; do
    idler_sleep 1
    let WAIT_FOR_STOP_TIMEOUT+=1
    if [ ${WAIT_FOR_STOP_TIMEOUT} = 10 ]; then
      return 1
    fi
  done
}

wine_run()
{
  # execute a program with wine and surpress the call output
  wine "$@" > /dev/null 2>&1
}

idler_logout()
{
  # stop, end or kill steam/node, backup creds, stop X, and remove temp files
  idler_stop ${1}
  if steam_pid > /dev/null; then
    if [ "${1}" = yes ]; then
      LOGOUT_TIMEOUT=61
      tprint "${ACCT}: killing steam..." ${DISPLAY},@${SPID}/$(steam_memory)
    else
      LOGOUT_TIMEOUT=0
      tprint "${ACCT}: logging out..." ${DISPLAY},@${SPID}/$(steam_memory)
      if ! auth_state > /dev/null; then
        close_window $(window_id Error)
        close_window $(window_id Guard)
        close_window $(window_id Login)
      elif wait_for_stop; then
        wine_run C:/Steam/steam.exe -shutdown
      else
        tprint "${ACCT}: error, client stop unregistered, killing steam"
        LOGOUT_TIMEOUT=61
      fi
    fi
    if tac ${LOGS}/cloud_log.txt 2> /dev/null \
    | grep -m1 "Need to\|Upload complete" | grep -q Need; then
      tprint "${ACCT}: cloud sync needed..." $(steam_memory)
    fi
    if app_state | grep -q ",Update Stopping,\|(Suspended)"; then
      tprint "${ACCT}: warning, download stopping..." $(steam_memory)
    fi
    while steam_pid > /dev/null; do
      if [ ${LOGOUT_TIMEOUT} = 60 ]; then
        tprint "${ACCT}: warning, killing steam..." $(steam_memory)
      elif [ ${LOGOUT_TIMEOUT} = 61 ]; then
        kill -9 ${SPID}
      fi
      idler_sleep 1
      let LOGOUT_TIMEOUT+=1
    done
  fi
  # XXX forget space, want to keep stuff, LOGS, maybe steamapps, move utility stuff to that function
  # dumps? || con.log link
  if [ -z ${2}${DEBUG} ]; then
    rm -fr ${LOGS} ${STEAM}/steamapps wine-${ACCT}/_*_lo*.reg \
      wine-${ACCT}/.utility.* "${TF}"/con-${ACCT}.log ${STEAM}/dumps
    rmdir share/${ACCT}/logs 2> /dev/null
  fi
}

check_account_input()
{
  # check account password and email address
  MIN_LENGTH=6
  if [ ! -z ${EMAIL} ]; then
    MIN_LENGTH=8
  fi
  if (( $(expr length "${PASS}") < ${MIN_LENGTH} )); then
    tprint "${ACCT}: error, invalid password" ${PASS}
  elif [ ! -z ${EMAIL} ] && ! echo ${EMAIL} | grep -q .*@.*\\..*; then
    tprint "${ACCT}: error, invalid email"
  else
    return 0
  fi
  return 1
}

steam_uid()
{
  # get steam uid from config.vdf
  if [[ "${1}" = 765611* ]]; then
    echo ${1}
  elif ! cat share/${1}/config/config.vdf 2> /dev/null | tr -d '[:blank:]' \
  | tr -d '\n' | grep -o \"${1}\"{\"SteamID\"\"765611[0-9]*\" \
  | grep -o 765611[0-9]*; then
    return 1
  fi
}

steam_ids()
{
  # get+cache steam account ids
  SUID=$(steam_uid ${ACCT})
  unset SCID
  if [ ! -z ${SUID} ]; then
    SCID=$((SUID-76561197960265728))
  fi
}

set_account()
{
  # set the account credentials, variables, and directory/file locations
  if [ -z ${2} ]; then
    OLD_ACCT=${ACCT}/${PASS}
  fi
  ACCT=$(echo ${1/\/*} | tr [:upper:] [:lower:] | sed s/#.*//)
  EMAIL=${1##*#}
  if [[ ${ACCT} != ?????* ]] \
  || [[ ${ACCT}${EMAIL} = *steam* ]] || [[ ${ACCT}${EMAIL} = *valve* ]]; then
    tprint "${ACCT}: error, invalid account credentials"
    return 1
  fi
  PASS=$(echo ${1%#${EMAIL}} | sed "s/${ACCT}\///")
  if [ ${PASS} = ${ACCT} ]; then
    if echo ${ACCOUNTS_STRING} \
    | grep -qP "( |^)${ACCT}/[[:graph:]][[:graph:]]*"; then
      set_account $(echo ${ACCOUNTS_STRING} | grep -oPm 1 "( |^)${ACCT}/\S*") no
      return
    fi
    unset PASS
  fi
  if [ ${EMAIL} = ${1} ]; then
    unset EMAIL
  fi
  check_account_input || return 1
  export WINEPREFIX="${PWD}"/wine-${ACCT}/
  STEAM=wine-${ACCT}/drive_c/Steam
  ATF=${STEAM}/steamapps/common/Team\ Fortress\ 2/tf
  CONFIG=share/${ACCT}/config
  LOGS=share/${ACCT}/logs/${HOSTNAME}
  CON=${LOGS}/con-${ACCT}.log
  USERDATA=share/${ACCT}/userdata
  LCONFIG=${USERDATA}/"*"/config/localconfig.vdf
  NODEJS=share/${ACCT}/node.js
  NODELOG=share/${ACCT}/node.log
  export DISPLAY=:0
  if steam_pid > /dev/null; then
    export DISPLAY=:$(ps ${SPID} | grep -o "_\:[0-9]*" | grep -o \[0-9]*)
  fi
  steam_ids
}

idler_uninstall()
{
  # logout, backup credentials, then remove client files and wineprefix
  if [ -d wine-${ACCT} ]; then
    idler_logout $*
    tprint "${ACCT}: uninstalling..." $(account_size)
    wineserver -k
    if ! rm -rf wine-${ACCT} 2> /dev/null; then
      tprint "${ACCT}: fatal, could not uninstall"
      exit 1
    fi
  fi
}

idler_delete()
{
  # logout, uninstall, then remove credential backup
  if [ -d share/${ACCT} ]; then
    idler_uninstall $*
    tprint "${ACCT}: deleting..." $(account_size)
    if ! rm -fr share/${ACCT} 2> /dev/null; then
      tprint "${ACCT}: fatal, could not delete"
      exit 1
    fi
  fi
}

free_swap()
{
  # get available system swap
  echo $(($(grep SwapFree /proc/meminfo | awk '{print $2}')/1000))
}

version()
{
  # parse version string
  if [ -z ${1} ]; then
    echo none
    return 1
  fi
  echo $* | grep -o \[0-9]*
}

steam_ui_cache_version()
{
  # get steam ui version manifest file
  version $(grep version steam/package/steam_client_win32.manifest 2> /dev/null)
}

steam_ui_version()
{
  # get steam ui version of the installed account prefix
  version $(cat wine-${ACCT}/.ui.pdl 2> /dev/null)
}

xserver_pid()
{
  # get pid of an X server process by its display id via tmp lock file
  local FILE=/tmp/.X${1:1}-lock
  if [[ ${FILE} = *.X0?-lock ]]; then
    FILE=${FILE//.X0/.X}
  fi
  if [ ! -e ${FILE} ]; then
    return 1
  fi
  echo $(cat ${FILE})
}

key_press()
{
  # press any number of keyboard keys
  focus_window ${1}
  local DELAY="--delay 300"
  if [ ! -z ${3} ]; then
    DELAY="--delay ${3}"
  fi
  if [ $(echo ${2} | wc -w) = 1 ]; then
    xdotool key ${4} ${2} ${5}
  else
    xdotool key ${4} ${DELAY} ${2} ${5}
  fi
  idler_sleep $(echo "scale=4;${DELAY:8}/1000" | bc)
  rm -f .xdotool${DISPLAY:1}-${HOSTNAME}.lock
}

steam_connect_hash()
{
  # get last 6 chars of connect cache from config.vdf or old cred file reference
  local HASH=$(cat ${CONFIG}/config.vdf 2> /dev/null | tr -d '[:blank:]' \
    | tr -d '\n' | grep -o \"ConnectCache\"{\"[a-f0-9]*\"\"[a-f0-9]* | tail -c5)
  if [ -z ${HASH} ]; then
    HASH=------
  fi
  echo \#${HASH}
}

download()
{
  # download a file
  TARGET="${1##*/}"
  if [ -d "${2}" ]; then
    TARGET="${2}/${TARGET}"
  elif [ ! -z "${2}" ]; then
    TARGET="${2}"
  fi
  for DOWNLOAD in {1..3}; do
    if wget -q ${1} -O "${TARGET}"; then
      rm -f ${HOME}/.wget-hsts
      return 0
    fi
  done
  tprint "error, file download failed" ${TARGET##*/}
  return 1
}

disable_power_management()
{
  # disable power management
  XFCE_PID=$(pgrep -fx xfce4-power-manager)
  if [ ! -z ${XFCE_PID} ]; then
    XFCE_AC=$(DISPLAY=:0 xfconf-query -c xfce4-power-manager \
      -p /xfce4-power-manager/inactivity-on-ac -v 2> /dev/null)
    if [ ! -z ${XFCE_AC} ] && [ ${XFCE_AC} != 14 ]; then
      tprint "disabled xfce4-power-manager" ${XFCE_AC}\>0,@${XFCE_PID}
      echo ${XFCE_AC} > .xfce4pm.pdl
      set_xfce_power 14 &
    fi
  fi
}

app_size()
{
  # get disk size of the app content or download
  if [ ! -z ${2} ]; then
    SIZE=$(grep -m1 SizeOnDisk ${APPS}/appmanifest_${1}.acf 2> /dev/null \
      | grep -o \[0-9]* || echo 0)
  else
    SIZE=$(tac ${LOGS}/content_log.txt 2> /dev/null \
      | grep -om 1 "ID ${1}.*: download [/0-9]*" | grep -om 1 "[0-9]*/[0-9]*")
    SIZE=$((${SIZE#*/}-${SIZE%/*}))
  fi
  if ((SIZE < 10000)); then
    echo ${SIZE}b
  elif (( SIZE < 10238977)); then
    echo $((SIZE/1024))kb
  else
    echo $(($((SIZE/1024))/1024))mb
  fi
}

app_version()
{
  # get buildid from application manifest
  version $(grep -m1 buildid ${APPS}/appmanifest_${1}.acf 2> /dev/null)
}

app_activity()
{
  # announce when steam(cmd) is updating or validating an app
  local APP_PID=$(pgrep steamcmd || echo ${SPID})
  if [ -z ${VALIDATING} ] && tac ${LOGS}/content_log.txt \
  | grep -m 1 "] Loaded\|${1}.*te changed.*,Validating\|validation finished" \
  | grep -q Validating; then
    VALIDATING=yes
    tprint "warning, validating app..." $(app_size ${1} disk),@${APP_PID}
  fi
  if [ -z ${DOWNLOADING} ] && tac ${LOGS}/content_log.txt \
  | grep -m 1 "] Loaded\|${1}.*te changed.*,Downloading" | grep -q Download; then
    DOWNLOADING=yes
    tprint "warning, downloading app..." $(app_size ${1}),@${APP_PID}
  fi
  if [ -z ${COMMITTING} ] && tac ${LOGS}/content_log.txt \
  | grep -m 1 "] Loaded\|${1}.*te changed.*,Committing" | grep -q Committing; then
    COMMITTING=yes
    tprint "warning, committing app..." $(app_size ${1}),@${APP_PID}
  fi
}

check_steamcmd_app()
{
  # disable pm, reset crash/ssfn file, then start steamcmd app check/download
  disable_power_management
  tprint "checking steam app..." $(app_size ${1} 1),v$(app_version ${1}),\#${1}
  rm -fr ${STEAM}/.crash ${STEAM}/steamapps
  mkdir -p ${STEAM}/steamapps
  ln -sf "${PWD}"/${APPS}/* ${STEAM}/steamapps/
  rm -f ${STEAM}/steamapps/*.acf
  ln -sf "${PWD}"/${APPS}/appmanifest_${1}.acf ${STEAM}/steamapps
  sed -i -e 's/.*SentryFile.*/"SentryFile""'${PWD//\//\\/}\\/share\\/${ACCT}\\/ssfn\"/ \
    ${CONFIG}/config.vdf
  rm -fr ${HOME}/Steam 2> /dev/null
  ln -sf "${PWD}"/${STEAM} ${HOME}/Steam
  if [ -d ${HOME}/.steam ]; then
    rm -fr ${HOME}/.steam-other
    mv ${HOME}/.steam ${HOME}/.steam-other 2> /dev/null
  fi
  chmod +x steam/linux32/steamcmd steam/steamcmd.sh
  echo \] Loaded >> ${LOGS}/content_log.txt
  touch ${LOGS}/steamcmd_log.txt
  bash ${STEAM}/steamcmd.sh -noverifyfiles ${2} ${3} +app_update ${1} \
    ${STEAMCMD} +quit > ${LOGS}/steamcmd_log.txt 2>&1 &
  while ! tac ${LOGS}/steamcmd_log.txt | grep -q "Success.*App '${1}'"; do
    idler_sleep 1
    app_activity ${1}
    if auth_state | grep -q "Logon Denied\|Two-factor\|Limit Exceed"; then
      tprint "fatal, steamcmd auth/guard error" \#${1}
      killall -w steamcmd
      exit 1
    fi
  done
  rm -fr ${HOME}/Steam
  mv ${HOME}/.steam-other ${HOME}/.steam 2> /dev/null
  unset VALIDATING DOWNLOADING COMMITTING
}

vpk_extract()
{
  # extract files from a vpk archive
  VPK="${1}"_dir.vpk
  DST="${2}"
  shift 2
  for TGT in $*; do
    mkdir -p ${TGT%/*} "${DST}"/${TGT%/*}
  done
  wine_run "${TF}"/../bin/vpk.exe x "${VPK}" $*
  for TGT in $*; do
    mv ${TGT} "${DST}"/${TGT%/*} 2> /dev/null
  done
  for TGT in $*; do
    rm -fr ${TGT%%/*}
  done
}

# get player count of an idle server via the port
STF=${APPS}/common/Team\ Fortress\ 2\ Dedicated\ Server/tf
server_playercount()
{
  tac "${STF}"/pdl-${HOSTNAME}-281${1:(-2)}/console.log \
    | grep -om 1 "Players:.*" | grep -o \[0-9]*
}

# find first available server/port
if [ -z ${IDLE_MAX} ] || ((IDLE_MAX > 33)); then
  IDLE_MAX=32
fi
SMOD="${STF}"/addons/sourcemod
if [ -z ${IRC_SERVER} ]; then
  IRC_SERVER=irc.gamesurge.net
fi
if [ -z ${IRC_SERVER_PORT} ]; then
  IRC_SERVER_PORT=6667
fi
if [ -z ${IRC_CHANNEL} ]; then
  IRC_CHANNEL=mannsanto
fi
if [ -z ${IDLE_MAP} ]; then
  IDLE_MAP=itemtest
fi
COMMON_OPTS="-condebug -nobreakpad -nodev -nodns -nogamestats -nohltv -noipx"
COMMON_OPTS="${COMMON_OPTS} -nomaster -nominidumps -noassert"
function start_server()
{
  if [ -z ${PORT} ]; then
    for NUM in {01..99}; do
      if ! pgrep -f srcds_linux.*281${NUM} > /dev/null; then
        if [ -z ${PORT} ]; then
          PORT=pdl-${HOSTNAME}-281${NUM}
          unset PLAYER
        fi
      else
        PLAYER=$(server_playercount ${NUM})
        if ((PLAYER < IDLE_MAX)) || [[ $(client_connection) = *281${NUM} ]]; then
          PORT=pdl-${HOSTNAME}-281${NUM}
          break
        fi
      fi
    done

    # configure server and sourceirc
    if ! pgrep -f srcds_linux.*${PORT:(-5)} > /dev/null; then
      mkdir -p "${STF}"/${PORT}/addons/sourcemod/configs \
        "${STF}"/${PORT}/cfg/sourcemod
      {
        echo hostname ${HOSTNAME}=${USER}_${VERSION}
        echo -e "sv_cheats 1\nfps_max 10\nip 0.0.0.0\nmaxplayers 32"
        echo -e "mp_autoteambalance 0\nmp_timelimit 0\nmp_allowspectators 0"
        echo -e "mp_teams_unbalance_limit 0\nmp_idledealmethod 0"
        echo -e "sv_pure 0\nsv_timeout 0\nmap ${IDLE_MAP}"
      } > "${STF}"/${PORT}/cfg/autoexec.cfg
      sed -e "s/crosshair 0/crosshair 1/" -e "s/\ttf\/custom\//+vgui\ttf\/pdl\//" \
        -e "s/\tgame+mod\t\t\ttf\/tf2/\t\/\/\/game+mod\t\t\ttf\/tf2/" \
        -e 's/\tgame+game/\t\/\/\/game+game/' -e "s/\tgame_lv/\t\/\/\/game_lv/" \
        -e 's/\tgame\t\t\t\t|all_/\t\/\/\/game\t\t\t\t|all_/' \
        -e 's/\tgame+vgui/\t\/\/\/game+vgui/' \
        -e 's/\tgame+mod+vgui/\t\/\/\/game+mod+vgui/' \
        -e 's/\tplatform+vgui/\t\/\/\/platform+vgui/' \
        -e 's/\tplatform\t\t\t|all_/\t\/\/\/platform\t\t\t|all_/' \
        -e "s/\tgame+down/\t\/\/\/game+down/" -e "s/\tmod\t/\t\/\/\/mod\t/" \
        -e "s/pdl-.*/${PORT}/" "${ATF}"/gameinfo.txt > "${STF}"/gameinfo.txt
      rm -f "${STF}"/${PORT}/cfg/sourcemod/irc-connected.cfg \
        "${SMOD}"/plugins/sourceirc.smx
      if [ "${IRC_SERVER}" != none ]; then
        cp "${SMOD}"/plugins/disabled/sourceirc.smx "${SMOD}"/plugins
        sed -e "s/irc.gamesurge.net/${IRC_SERVER}/" -e "s/\"1.0\"/\"2.0\"/" \
          -e "s/6667/${IRC_SERVER_PORT}/" -e "s/\t\"cmd_/\/\/\"cmd_/" \
          -e "s/\" \/\/ The server/${IRC_SERVER_PASS}&/" \
          -e "s/\" \/\/ The channel/${IRC_CHANNEL_PASS}&/" \
          -e "s/\"#sourceirc.*\"/\"#${IRC_CHANNEL/\#}\"/" \
          -e "s/\t\"SourceIRC\"/\t\"$(echo ${HOSTNAME:0:13} \
          | sed -e s/-// -e s/_//)_${PORT:(-2)}-\"/" \
          "${SMOD}"/configs/sourceirc.cfg.def \
          > "${STF}"/${PORT}/addons/sourcemod/configs/sourceirc.cfg
        if [ ! -z ${IRC_SERVER_USER} ]; then
          echo "irc_send \"/authserv AUTH ${IRC_SERVER_USER} ${IRC_SERVER_PASS}\"" \
            > "${STF}"/${PORT}/cfg/sourcemod/irc-connected.cfg
        fi
      fi
      SCON="${STF}"/${PORT}/console.log

      # link/compile server plugin
      ln -sf "${PWD}"/pdl-idler_sourcemod.sp "${SMOD}"/scripting/pdl-idler.sp
      cd "${SMOD}"/scripting
      chmod +x compile.sh spcomp
      OPTS=$(./compile.sh pdl-idler 2> /dev/null)
      if ! mv compiled/pdl-idler.smx \
      ../plugins/pdl-idler.smx 2> /dev/null; then
        echo "${OPTS}"
        exit 1
      fi
      cd "${DIR}"

      # write version to console log, then start server
      echo "pdlv $(version $(grep Server "${STF}"/steam.inf 2> /dev/null \
        | grep -o \[0-9]*))" > "${SCON}"
      tprint "loading server..." \
        ${IDLE_MAP},\#${PORT:(-2)},v$(app_version 232250) | tee -a "${SCON}"
      screen -dmS idler-server${PORT:(-2)}$ "${STF}"/../srcds_run -norestart \
        ${COMMON_OPTS} -game tf -ignoresigint -replay -port ${PORT:(-5)}
    fi
  fi
}

steam_cellid()
{
  # get steam server cellid
  grep \"CurrentCellID ${CONFIG}/config.vdf | grep -o \[0-9]*
}

steam_auth_server()
{
  # get steam authentication server
  tac ${LOGS}/connection_log.txt | grep Completed \
    | grep -m1 -o "[0-9\.:]*, [A-Z]" | sed -e "s/, //" -e "s/:270/:/"
}

type_input()
{
  # type a string with the keyboard
  focus_window ${1}
  local DELAY=300
  if [ ! -z ${3} ]; then
    DELAY=${3}
  fi
  if [ ! -z ${4} ] ; then
    local SELECT=key\ Ctrl+a
  fi
  echo ${5} ${SELECT} type --delay ${DELAY} \"${2}\" | xdotool -
  idler_sleep $(echo "scale=4;${DELAY}/1000" | bc)
  rm -f .xdotool${DISPLAY:1}-${HOSTNAME}.lock
}

mouse_click()
{
  # mouse the mouse relative to a window and click
  focus_window ${1}
  local XPOS=0
  if [ ! -z ${2} ]; then
    XPOS=${2}
  fi
  local YPOS=0
  if [ ! -z ${3} ]; then
    YPOS=${3}
  fi
  local REPEAT=1
  if [ ! -z ${4} ]; then
    REPEAT=${4}
  fi
  local BUTTON=1
  if [ ! -z ${5} ]; then
    BUTTON=${5}
  fi
  local DELAY=300
  if [ ! -z ${6} ]; then
    DELAY=${6}
  fi
  xdotool ${7} mousemove --sync --window ${1} ${XPOS} ${YPOS} \
    click --delay ${DELAY} --repeat ${REPEAT} ${BUTTON} ${8}
  idler_sleep 0.${DELAY}
  rm -f .xdotool${DISPLAY:1}-${HOSTNAME}.lock
}

# check pid and swap space
export WINEDEBUG=-all
export WINEDLLOVERRIDES=mshtml,crashhandler,msi,winedbg.exe,services.exe,winedevice.exe,plugplay.exe,winemenubuilder.exe=d
idler_login()
{
  if steam_pid > /dev/null; then
    return 0
  elif (($(free_swap)<400)); then
    tprint "${ACCT}: error, not enough swap" $(free_swap)mb
    return 2
  fi

  # download package manifests once per invocation XXX share downloading?
  mkdir -p steam/appcache steam/depotcache steam/music steam/vr steam/package \
    ${APPS}/workshop ${APPS}/sourcemods ${APPS}/common
  if [ -z "${PACKAGE}" ]; then
    local PACKAGE=media.steampowered.com/client/steam_
    if ! download ${PACKAGE}client_win32 steam/package/steam_client_win32.manifest \
    || ! download ${PACKAGE}cmd_linux steam/package/steam_cmd_linux.manifest; then
      tprint "${ACCT}: error, cannot download package manifest(s)..."
      return 1
    fi

    # download/replace then extract steam package files with invocation block
    for ZIP in $(grep file steam/package/*.manifest | awk '{print $3}'); do
      if [ ! -e steam/package/${ZIP:1:(-1)} ]; then
        local ZIPS="${ZIPS} ${ZIP:1:(-1)}"
        let local UI_SIZE+=$(cat steam/package/*.manifest \
          | sed "0,/${ZIP}/d" | grep -m1 size | grep -o \[0-9]*)
      fi
    done
    if [ ! -z "${ZIPS}" ] && block_on_file steam/.package yes; then
      tprint "downloading/extracting "$(echo ${ZIPS} | wc -w)" packages..." \
        $(echo $((UI_SIZE/1000)))kb
      for ZIP in ${ZIPS}; do
        rm -f ${ZIP%.zip.*}.zip.*
        download media.steampowered.com/client/${ZIP} steam/package/${ZIP}
        while ! unzip -o steam/package/${ZIP} -d steam > /dev/null; do
          tprint "warning, redownloading corrupt ui package" ${ZIP:0:(-42)}
          download media.steampowered.com/client/${ZIP} steam/package/${ZIP}
        done
      done

      # add extra logs and client urls, then remove lock
      touch steam/debug.log steam/GameValidation.log steam/GameOverlayRenderer.log
      if ! grep -q pdl-idler steam/public/url_list.txt; then
        cat steam/public/url_list.txt pdl-idler_url.list \
          | tee steam/public/url_list.txt > /dev/null
      fi
      rm steam/.package-${HOSTNAME}.lock
    fi
  fi

  # (re)link client extractions inside prefix
  mkdir -p ${STEAM}
  if [ $(steam_ui_version) != $(steam_ui_cache_version) ]; then
    find ${STEAM} -maxdepth 1 -type l -exec rm -f {} \;
    find steam/ -mindepth 1 -maxdepth 1 -not -name steamapps \
      -exec ln -sf "${PWD}"/{} ${STEAM} \;
    steam_ui_cache_version > wine-${ACCT}/.ui.pdl
  fi

  # (re)make and/or link config.vdf and guard key
  mkdir -p ${LOGS} ${CONFIG} ${USERDATA%/}
  ln -sfn "${PWD}"/${CONFIG} ${STEAM}/config
  ln -sfn "${PWD}"/${LOGS} ${STEAM}/logs
  ln -sfn "${PWD}"/${USERDATA%/} ${STEAM}/userdata
  if [ ! -e ${CONFIG}/config.vdf ]; then
    {
      echo "\"InstallConfigStore\"{\"Software\"{\"Valve\"{\"Steam\"{"
      echo "\"SentryFile\"\"c:\\\\Steam\\\\ssfn-${ACCT}\""
      echo "\"SurveyDate\"\"2050-01-01\"}}}"
      echo -e "\"Music\"{\"CrawlSteamInstallFolders\"\"0\"}\n}"
    } > ${CONFIG}/config.vdf
  fi
  if [ ! -e share/${ACCT}/ssfn ]; then
    if [ -e share/ssfn ]; then
      cp share/ssfn share/${ACCT}/ssfn
    else
      dd if=/dev/urandom of=share/${ACCT}/ssfn bs=2k count=1 > /dev/null 2>&1
    fi
  fi
  ln -sf "${PWD}"/share/${ACCT}/ssfn ${STEAM}/ssfn-${ACCT}

  # change display if creating, or prep login prompt, then start X
  if [ ! -z ${EMAIL} ] && [ -z ${SUID} ]; then
    local OLD_DISPLAY=${DISPLAY}
    export DISPLAY=:99
  else
    echo '"SteamAppData"{"RememberPassword""1""AutoLoginUser""'${ACCT}'"}' \
      > ${CONFIG}/SteamAppData.vdf
  fi
  for DISPLAY in ${OLD_DISPLAY} ${DISPLAY}; do
    if ! xserver_pid ${DISPLAY} > /dev/null; then
      if [ ${DISPLAY} != :0 ]; then
        tprint "starting Xvfb..." ${DISPLAY}
        screen -dmS idler-X${DISPLAY:1}$ Xvfb ${DISPLAY} -screen 0 800x600x24
      else
        tprint "starting X..." ${DISPLAY}
        screen -dmS idler-X${DISPLAY:1}$ \
          xinit -geometry =40x40+9999+0 -- ${DISPLAY}
      fi
      while ! xserver_pid ${DISPLAY} > /dev/null; do
        idler_sleep 1
        if ! pgrep -f SCREEN.*idler-X${DISPLAY:1} > /dev/null; then
          tprint "error: could not start display server" ${DISPLAY}
          return 2
        fi
      done
    fi

    # optionally start x11vnc with or without password
    if [ "${X_X11VNC}" != no ] && [ ${DISPLAY} != :99 ] \
    && ! pgrep -fn x11vnc.*display\ ${DISPLAY} > /dev/null; then
      if [ "${X_X11VNC}" = yes ] || [ ${DISPLAY} != :0 ]; then
        if ! which x11vnc > /dev/null 2>&1; then
          tprint "warning, x11vnc is not installed"
          unset X_X11VNC
        else
          if [ ! -z ${X_X11VNC_PASS} ]; then
            rm -f .vnc_passwd
            x11vnc -storepasswd ${X_X11VNC_PASS} "${PWD}"/.vnc_passwd 2> /dev/null
            local RFBA="-rfbauth ${PWD}/.vnc_passwd"
          fi
          tprint "starting x11vnc..." \
            ${DISPLAY},@$(xserver_pid ${DISPLAY}),v$(x11vnc -V | awk '{print $2}')
          screen -dmS idler-Xvnc${DISPLAY:1}$ x11vnc -display ${DISPLAY} -forever ${RFBA}
        fi
      fi
    fi
  done

  # structure account wine prefix
  rm -f wine-${ACCT}/_*_lo*.reg wine/users/${USER}/My\ Documents 2> /dev/null
  local MODE=hi
  if [[ "${1}" = *lo* ]]; then
    local MODE=lo
  fi
  mkdir -p wine/Program\ Files_${MODE} wine/windows_${MODE} \
    wine-${ACCT}/dosdevices wine/users/${USER}/My\ Documents
  ln -sfn ../drive_c wine-${ACCT}/dosdevices/c:
  ln -sfn / wine-${ACCT}/dosdevices/z:
  ln -sfn "${PWD}"/wine/users wine-${ACCT}/drive_c/users
  ln -sfn "${PWD}"/wine/windows_${MODE} wine-${ACCT}/drive_c/windows
  ln -sfn "${PWD}"/wine/Program\ Files_${MODE} \
    wine-${ACCT}/drive_c/Program\ Files
  ln -sf "${PWD}"/wine-${ACCT}/._update-timestamp_${MODE} \
    wine-${ACCT}/.update-timestamp
  WINEINF=$(stat -c %Y /usr/share/wine/wine.inf)
  WINEINF_UPDATE={CP},
  for REG in user_${MODE} userdef_${MODE} system_${MODE}; do
    if [ ! -e wine-${ACCT}/_${REG}.reg ]; then
      if [ -e wine/${REG}.${WINEINF} ]; then
        cp wine/${REG}.${WINEINF} wine-${ACCT}/_${REG}.reg
      else
        local BACKUP="${BACKUP} ${REG} "
        echo "WINE REGISTRY Version 2" > wine-${ACCT}/_${REG}.reg
        rm -f wine/${REG}
        echo 0 > wine-${ACCT}/._update-timestamp_${MODE}
        unset WINEINF_UPDATE
      fi
    elif [ ${REG} = system_${MODE} ]; then
      unset WINEINF_UPDATE
    fi
    ln -f wine-${ACCT}/_${REG}.reg wine-${ACCT}/${REG//_*}.reg
  done
  if [ ! -z ${WINEINF_UPDATE} ]; then
    echo ${WINEINF} > wine-${ACCT}/._update-timestamp_${MODE}
  fi

  # create/upgrade wine prefix data and make backup files
  if [ $(cat wine-${ACCT}/.update-timestamp) != ${WINEINF} ]; then
    tprint "${ACCT}: prepping wine data..." ${WINEINF}_${MODE}
    WINEARCH=win64 wineboot > /dev/null 2>&1
    for ZIP in Music Pictures Videos; do
      ln -sfn "${PWD}"/wine/users/${USER}/My\ Documents \
        wine/users/${USER}/My\ ${ZIP}
    done
    regedit pdl-idler_registry.reg > /dev/null 2>&1
  fi
  if [ ! -z "${BACKUP}" ]; then
    tprint "${ACCT}: making registry backup..." ${MODE}_${WINEINF}
    wineserver -w
    for REG in ${BACKUP}; do
      if [ ! -e wine/${REG}.${WINEINF} ]; then
        cp wine-${ACCT}/_${REG}.reg wine/${REG}.${WINEINF}
      fi
    done
  fi

  # initiate steam launch or reset creation display
  LOGIN=yes
  if [ -e ${STEAM}/.crash ]; then
    local CRASH=${y}/C/${l},
  fi
  tprint "${ACCT}: starting steam..." \
    ${CRASH}${MODE},${WINEINF_UPDATE}${REGEDIT}${DISPLAY},\$$(\
    sha1sum share/${ACCT}/ssfn | cut -c1-4)+$(steam_connect_hash)
  while ! steam_pid > /dev/null; do
    if [ ! -z ${F2P} ]; then
      export DISPLAY=${OLD_DISPLAY}
    fi

    # block and check/update tf2 with steamcmd
    steam_ids
    if [ ! -z ${SCID} ]; then
      if [ -z ${TF2_VER} ]; then
        block_on_file steam/.steamapps
        TF2_VER=$(wget -qO- api.steampowered.com/IGCVersion_440/GetClientVersion/v1 \
          | grep -m1 version | grep -o \[0-9]*)${STEAMCMD}
        if [ -z ${TF2_VER} ]; then
          tprint "${ACCT}: error, cannot obtain tf2 version..."
          return 1
# XXX ni more password? okay back again
        elif ! grep -q ClientVersion=${TF2_VER} "${TF}"/steam.inf 2> /dev/null; then
          check_steamcmd_app 440 "+login ${ACCT} ${PASS}" \
            +@sSteamCmdForcePlatformType\ windows
        fi

        # extract/link farm resources
        if [ "$(cat "${TF}"/pdl/farm/ver 2> /dev/null)" != $(app_version 440)a ]; then
          tprint "constructing farm resources..." farm-v$(app_version 440)a
          chmod 700 "${TF}"/pdl/farm/streams 2> /dev/null
          rm -fr "${TF}"/pdl/farm
          mkdir -p "${TF}"/pdl/farm/cfg "${TF}"/pdl/farm/materials/vgui/hud \
            "${TF}"/pdl/farm/scripts/items "${TF}"/pdl/farm/streams
          chmod 000 "${TF}"/pdl/farm/streams
          ln -sf "${PWD}"/"${TF}"/maps "${TF}"/pdl/farm
          ln -sf "${PWD}"/"${STF}"/addons "${TF}"/pdl/farm
          echo -e "exec \"autoexec\"\nstuffcmds" > "${TF}"/pdl/farm/cfg/valve.rc
          vpk_extract "${TF}"/../hl2/hl2_textures "${TF}"/pdl/farm \
            materials/console/startup_loading.vtf
          cp "${TF}"/pdl/farm/materials/console/startup_loading.vtf \
            "${TF}"/pdl/farm/materials/console/background01.vtf
          echo '"UnlitGeneric"{"$basetexture""console/startup_loading"}' \
            > "${TF}"/pdl/farm/materials/console/startup_loading.vmt
          for RES in 800corner 800corner1 800corner2 800corner3 800corner4; do
            echo '"UnlitGeneric"{"$basetexture""vgui/hud/'${RES}'"}' \
              > "${TF}"/pdl/farm/materials/vgui/hud/${RES}.vmt
          done
          for RES in clientscheme gamemenu loadingdialog sourcescheme \
          loadingdialognobanner modevents ui/charinfoarmorysubpanel \
          ui/charinfoloadoutsubpanel ui/charinfopanel ui/craftingpanel \
          ui/craftingstatusdialog ui/econ/itempickuppanel \
          ui/econ/itemdiscardpanel ui/econ/store/v1/storestatusdialog \
          ui/hudalert ui/hudbosshealth ui/huditemattributetracker \
          ui/selectmosthelpfulfrienddialog ui/targetid \
          ui/hudpasstimeballstatus ui/hudpasstimepassnotify \
          ui/quests/questitempanel_base ui/lobbycontainerframe \
          ui/lobbycontainerframe_casual ui/lobbycontainerframe_comp \
          ui/lobbycontainerframe_mvm ui/lobbypanel ui/lobbypanel_casual \
          ui/lobbypanel_comp ui/lobbypanel_mvm ui/matchmakingpanel \
          ui/matchmakinggrouppanel ui/pvpcasualrankpanel ui/pvpcomprankpanel \
          ui/pvprankpanel; do
            FILES="${FILES}resource/${RES}.res "
          done
          vpk_extract "${TF}"/tf2_misc "${TF}"/pdl/farm ${FILES} \
            scripts/objects.txt scripts/dsp_presets.txt \
            scripts/items/paintkits_master.txt \
            models/vgui/12v12_badge.mdl models/vgui/competitive_badge.mdl
          echo "precache{}" > "${TF}"/pdl/farm/scripts/client_precache.txt
          ln -sf "${PWD}"/"${TF}"/../hl2/resource/gameui_english.txt \
            "${TF}"/pdl/farm/resource/gameui_english.txt
          echo "\"Resource/UI/MainMenuOverride.res\"{MainMenuOverride{}}" \
            > "${TF}"/pdl/farm/resource/ui/mainmenuoverride.res
          for RES in game_sounds soundscapes surfaceproperties; do
            echo "${RES}_manifest{}" > "${TF}"/pdl/farm/scripts/${RES}_manifest.txt
          done
          touch "${TF}"/pdl/farm/scripts/soundmixers.txt
          ln -sf "${PWD}"/"${TF}"/scripts/items/items_game.txt \
            "${TF}"/pdl/farm/scripts/items/items_game.txt
          ln -sf "${PWD}"/"${TF}"/scripts/items/items_game.txt.sig \
            "${TF}"/pdl/farm/scripts/items/items_game.txt.sig
          vpk_extract "${TF}"/../hl2/hl2_misc "${TF}"/pdl/farm \
            shaders/psh/unlitgeneric.vcs shaders/vsh/unlitgeneric_vs11.vcs \
            models/error.dx80.vtx models/error.dx90.vtx models/error.mdl \
            models/error.sw.vtx models/error.vvd resource/hltvevents.res \
            resource/replayevents.res resource/serverevents.res
          ln -sf "${PWD}"/"${TF}"/steam.inf "${TF}"/pdl/farm
          for WEP in $(wine "${TF}"/../bin/vpk.exe l \
          "${TF}"/tf2_misc_dir.vpk 2> /dev/null | grep tf_weapo | sed 's/\r$//'); do
            local WEPS="${WEPS}${WEP} "
          done
          for WAV in $(wine "${TF}"/../bin/vpk.exe l \
          "${TF}"/tf2_sound_misc_dir.vpk 2> /dev/null \
          | grep ui/item_.*_"\(drop\|pickup\)".wav | sed 's/\r$//'); do
            local WAVS="${WAVS}${WAV} "
          done
          for ARRAY in misc@"${WEPS}" sound_misc@"${WAVS}"; do
            VPK_FILE=${ARRAY%%@*}
            ARRAY=(${ARRAY#*@})
            vpk_extract "${TF}"/tf2_${VPK_FILE} "${TF}"/pdl/farm \
              ${ARRAY[@]:0:$((${#ARRAY[@]}/4))}
            vpk_extract "${TF}"/tf2_${VPK_FILE} "${TF}"/pdl/farm \
              ${ARRAY[@]:$((${#ARRAY[@]}/4)):$((${#ARRAY[@]}/4))}
            vpk_extract "${TF}"/tf2_${VPK_FILE} "${TF}"/pdl/farm \
              ${ARRAY[@]:$((${#ARRAY[@]}/2)):$((${#ARRAY[@]}/4))}
            vpk_extract "${TF}"/tf2_${VPK_FILE} "${TF}"/pdl/farm \
              ${ARRAY[@]:$((${#ARRAY[@]}/2+${#ARRAY[@]}/4)):$((${#ARRAY[@]}))}
          done
          vpk_extract "${TF}"/tf2_sound_misc "${TF}"/pdl/farm \
            sound/ui/notification_alert.wav
          mv "${TF}"/pdl/farm/sound/ui/notification_alert.wav \
            "${TF}"/pdl/farm/sound/ui/item_notify_drop.wav
          cp "${TF}"/pdl/farm/sound/ui/item_bag_pickup.wav \
            "${TF}"/pdl/farm/sound/ui/item_boxing_gloves_drop.wav
          cp "${TF}"/pdl/farm/sound/ui/item_cardboard_pickup.wav \
            "${TF}"/pdl/farm/sound/ui/item_cardboard_drop.wav
          cp "${TF}"/pdl/farm/sound/ui/item_default_pickup.wav \
            "${TF}"/pdl/farm/sound/ui/item_leather_pickup.wav
          cp "${TF}"/pdl/farm/sound/ui/item_metal_scrap_pickup.wav \
            "${TF}"/pdl/farm/sound/ui/item_medal_pickup.wav
          cp "${TF}"/pdl/farm/sound/ui/item_mtp_drop.wav \
            "${TF}"/pdl/farm/sound/ui/item_sandwich_drop.wav
          cp "${TF}"/pdl/farm/sound/ui/item_soda_can_pickup.wav \
            "${TF}"/pdl/farm/sound/ui/item_watch_drop.wav

          # alter select vgui properties to assist helper, then mark version
          sed -i -e  's/\t\t"SelectPlayerDialog"/&\n"wide""640"/' \
            -e 's/\t\t"CancelButton"/&\n"ypos""0""wide""640""tall""640"/' \
            -e s/buttonclick.wav/selectmosthelpfulfrienddialog.wav/ \
            "${TF}"/pdl/farm/resource/ui/selectmosthelpfulfrienddialog.res
          sed -i -e s/buttonclick.wav/craftingstatusdialog.wav/ \
            -e 's/\t\t"CraftingStatusDialog"/&\n"wide""800""tall""600"/' \
            -e 's/\t\t"CloseButton"/&\n"ypos""0""wide""640""tall""640"/' \
            "${TF}"/pdl/farm/resource/ui/craftingstatusdialog.res
          sed -i -e s/\"250\"/\"800\"/ -e s/\"150\"/\"600\"/ \
            -e s/\"100\"/\"800\"/ -e s/\"25\"/\"600\"/ \
            -e s/buttonclick.wav/storestatusdialog.wav/ \
            "${TF}"/pdl/farm/resource/ui/econ/store/v1/storestatusdialog.res
          sed -i -e /buttonclick.wav/d \
            -e 's/\t\t"CloseButton"/&\n"ypos""0""tall""600""wide""800"/' \
            "${TF}"/pdl/farm/resource/ui/econ/itempickuppanel.res
          echo $(app_version 440)a > "${TF}"/pdl/farm/ver
        fi

        # check/update tf2 server and item data, link farm, then install addons
        if [ "$(grep -om1 ${STEAMCMD}\[0-9]* "${TF}"/steam.inf)" \
        != "$(grep -om1 \[0-9]* "${STF}"/steam.inf 2> /dev/null)" ]; then
          check_steamcmd_app 232250 "+login anonymous"
          mkdir -p "${SMOD}"/configs
          sed -n '/^\t"items"/,/^\t"attributes"/{/^\t"attributes"/!p}' \
            "${TF}"/scripts/items/items_game.txt > "${SMOD}"/configs/items.kv
        fi
        ln -sfn "${PWD}"/"${TF}"/pdl "${STF}"/pdl
        MS=http://www.gsptalk.com/mirror/sourcemod/mmsource-1.10.6
        if [ ! -e "${STF}"/addons/${MS##*/}-linux.tar.gz ]; then
          tprint "installing/updating metamod:source..." v${MS/*mmsource-}
          mkdir -p "${STF}"/addons
          rm -fr "${STF}"/addons/mmsource-*.tar.* "${STF}"/addons/metamod/bin
          download ${MS}-linux.tar.gz "${STF}"/addons || exit 1
          tar -xzf "${STF}"/addons/${MS##*/}-linux.tar.gz -C "${STF}"
          echo '"Plugin"{"file""../tf/addons/metamod/bin/server"}' \
            > "${STF}"/addons/metamod.vdf
        fi
        SM=http://sourcemod.net/smdrop/1.7/sourcemod-1.7.3-git5321
        if [ ! -e "${STF}"/addons/${SM##*/}-linux.tar.gz ]; then
          tprint "installing/updating sourcemod..." v${SM/*sourcemod-}
          rm -fr "${STF}"/addons/sourcemod-*.tar.* "${SMOD}" "${STF}"/cfg/sourcemod
          download ${SM}-linux.tar.gz "${STF}"/addons || exit 1
          tar -xzf "${STF}"/addons/${SM##*/}-linux.tar.gz -C "${STF}"
          mv "${SMOD}"/plugins/*.smx "${SMOD}"/plugins/disabled
          mv "${SMOD}"/extensions/dbi.*.ext.so "${SMOD}"/plugins/disabled
          mv "${SMOD}"/plugins/disabled/basecommands.smx "${SMOD}"/plugins
          sed -i -e "s/Logging\"\t\t\"o[fn]*\"/Logging\"\t\t\"off\"/" \
            "${SMOD}"/configs/core.cfg
        fi
        if [ ! -d "${SMOD}"/plugins/SourceIRC ]; then
          tprint "installing sourceirc..." sircD
          if [ ! -e "${STF}"/sourceirc.zip ]; then
            OPTS=jenkins.azelphur.com/job/SourceIRC/lastSuccessfulBuild/artifact
            download http://${OPTS}/sourceirc.zip "${STF}"/sourceirc.zip || exit 1
          fi
          if [ ! -e "${STF}"/socket_3.0.1.zip ]; then
            download dropbox.com/s/kcwuii9g80xkdya/socket_3.0.1.zip?dl=0 \
              "${STF}"/socket_3.0.1.zip || exit 1
          fi
          unzip -d "${SMOD}" -o "${STF}"/sourceirc.zip > /dev/null
          unzip -d "${STF}" -o "${STF}"/socket_3.0.1.zip > /dev/null
          mv "${SMOD}"/plugins/SourceIRC/* "${SMOD}"/plugins/disabled
          mv "${SMOD}"/configs/sourceirc.cfg "${SMOD}"/configs/sourceirc.cfg.def
          sed -i -e "s/RegCmd\");/&\n\tMarkNativeAsOptional(\"IRC_MsgFlaggedChannels\");/" \
            "${SMOD}"/scripting/include/sourceirc.inc
        fi

        # remove apps block, then turn off app updating
        rm -f steam/.steamapps-${HOSTNAME}.lock
      fi
      sed -i -e "s/UpdateBehavior\"\t\t\".\"/UpdateBehavior\"\t\t\"1\"/" \
        ${APPS}/appmanifest_*.acf

      # create apps and tf2 client directory structure and files
      if [ -z ${CLIENT} ]; then
        for LOC in steamapps common Team\ Fortress\ 2 tf; do
          local BASE="${BASE}"/"${LOC}"
          rm -fr ${STEAM}"${BASE}"
          mkdir -p ${STEAM}"${BASE}"
          ln -sfn "${PWD}"/steam"${BASE}"/* ${STEAM}"${BASE}"
        done
        rm -f "${TF}"/cfg/banned_ip.cfg ${STEAM}/steamapps/appmanifest_232250.acf
        mkdir -p "${ATF}"/pdl-${ACCT}/cfg
        echo -e "cl_voice_filter \"\"\nsetinfo name \"\"" \
          > "${ATF}"/pdl-${ACCT}/cfg/audible.cfg
        echo > "${PWD}"/${CON}
        ln -sf "${PWD}"/${CON} "${ATF}"/pdl-${ACCT}/console.log
        ln -sf "${PWD}"/pdl-idler_autoexec.cfg "${ATF}"/pdl-${ACCT}/cfg/autoexec.cfg
        OPTS="\t\t|gameinfo_path|.\r\nmod+mod_write+default_write_path\t\ttf\/pdl-${ACCT}"
        sed -i -e "s/+mod_write+default_write_path\t\t|gameinfo_path|./${OPTS}/" \
          "${ATF}"/gameinfo.txt
        while [ -z ${LISTEN} ]; do
          local CLIENT=28$(printf "%03d\n" $(shuf -i 200-599 -n 1))
          if ! steam_pid -${CLIENT} > /dev/null; then
            local LISTEN=$((CLIENT+1))
          fi
        done
        {
          unset DLLS
          STREAMING=1
          GRAPHICS="-dxlevel 95 -w 1366 -h 768"
          FPS=132
          if [ ${MODE} = lo ]; then
            DLLS=${2}${WINEDLLOVERRIDES:0:(-2)},appoverlay,dwrite,gameoverlayui
            DLLS=${DLLS},gameoverlayrenderer,steamservice.exe,steamwebhelper.exe
            STREAMING=0
            GRAPHICS="-dxlevel 50 -w 640 -h 480 -nod3d9ex"
            FPS=30
            echo "cl_disablehtmlmotd 1"
          fi
          echo "alias _acmd \"exec banned_ip;wait $((${FPS}*4));_acmd\""
          echo "_acmd;_amove;_mping"
          echo "clientport \"${CLIENT}\""
          echo "fps_max \"${FPS}\""
        } > "${ATF}"/pdl-${ACCT}/cfg/${ACCT//./}+.cfg
      fi

      # reset ssfn from steamcmd and/or migrate new file
      if grep -q ssfn[0-9]*\" ${CONFIG}/config.vdf && [ -e ${STEAM}/ssfn[0-9]* ]; then
        tprint "${ACCT}: warning, migrated ssfn file" $(date +%s)
        mv share/${ACCT}/ssfn share/${ACCT}/ssfn.$(date +%s) 2> /dev/null
        mv ${STEAM}/ssfn[0-9]* share/${ACCT}/ssfn
      fi
      sed -i -e 's/.*SentryFile.*/"SentryFile""C\:\\\\Steam\\\\ssfn-'${ACCT}\"/ \
        ${CONFIG}/config.vdf

      # (re)set local steam/tf2 settings
      mkdir -p ${USERDATA}/${SCID}/440/remote ${USERDATA}/${SCID}/config \
        ${USERDATA}/${SCID}/760/remote/440/screenshots/thumbnails
      cat pdl-idler_localconfig.vdf ${LCONFIG} > lcfg.tmp
      mv lcfg.tmp ${USERDATA}/${SCID}/config/localconfig.vdf
      LAUNCH="${COMMON_OPTS} ${GRAPHICS} -nocrashdialog -nojoy -nomessagebox"
      LAUNCH="${LAUNCH} -novid -port ${LISTEN} -sw +exec ${ACCT//./}+"
      sed -i -e "s/PersonaStateDesired\"\s*\"[0-9]/PersonaStateDesired\"\"0/" \
        -e "/LaunchOptions.*nojoy/ s/^.*$/\"LaunchOptions\" \"${LAUNCH}\"/" \
        -e "s/EnableStreaming\"\s*\"[0-9]/EnableStreaming\"\"${STREAMING}/" \
        -e "/ShowAvatars/d" ${LCONFIG}

      # embed screenshot file and entry for socialize
      if [ ! -e ${USERDATA}/${SCID}/760/screenshots.vdf ]; then
        if [ ! -s share/primarydataloop.jpg ]; then
          download http://i.imgur.com/4kNwKCP.jpg share/primarydataloop.jpg
        fi
        ln -sf "${PWD}"/share/primarydataloop.jpg \
          ${USERDATA}/${SCID}/760/remote/440/screenshots
        ln -sf "${PWD}"/share/primarydataloop.jpg \
          ${USERDATA}/${SCID}/760/remote/440/screenshots/thumbnails
        {
          echo '"Screenshots"{"440"{"0"{"imported""1"'
          echo '"filename""440/screenshots/primarydataloop.jpg"'
          echo '"thumbnail""440/screenshots/thumbnails/primarydataloop.jpg"'
          echo '"width""200""height""150""gameid""440"'
          echo '"creation""1234567890""caption""""permissions""2"'
          echo '"hscreenshot""18446744073709551615"}}}'
        } > ${USERDATA}/${SCID}/760/screenshots.vdf
      fi

      # preemptively start server if farm login
      if [ ! -z ${3} ]; then
        start_server
      fi
    fi

    # reset crash file, then start steam XXX  -no-cef-sandbox
    rm -f ${STEAM}/.crash
    WINEDLLOVERRIDES=${DLLS}=d screen -dmS idler-${ACCT}$ \
      wine C:/Steam/steam.exe -${ACCT} -console -${CLIENT} ${MODE}_${DISPLAY} \
      -single_core -noverifyfiles -silent -language english \
      steam://friends/settings/showavatars
    while true; do

      # get authentication state, then restart/fail if no pid
      auth_state > /dev/null
      if ! steam_pid > /dev/null; then
        if [ ! -z ${AUTH} ] && [ "${AUTH_ERROR}" != 3 ]; then
          let local AUTH_ERROR+=1
          tprint "${ACCT}: warning, auth error retry..." \
            x${AUTH_ERROR},$(steam_connect_hash)
        elif [ -z ${LOGOUT_TIMEOUT} ]; then
          if [ ! -z ${AUTH} ]; then
            tprint "${ACCT}: error, auth error failure..." $(steam_connect_hash)
          elif [ ! -z ${ERROR} ]; then
            tprint "${ACCT}: error, steam server problem"
          elif [ ! -z ${CRED} ]; then
            tprint "${ACCT}: error, user canceled login"
          else
            tprint "${ACCT}: error, unknown launch failure"
          fi
          idler_logout
          return 1
        fi
        unset LOGOUT_TIMEOUT
        continue 2

      # if greeting window arrives, create account, then alter conf
      elif [ -z ${AUTH}${GUARD}${CRED}${F2P} ] \
      && window_id \"Steam\" _WM_STATE\(ATOM\) > /dev/null \
      && xprop -id ${WID} | grep -q 432\ by; then
        local F2P=${WID}
        tprint "${ACCT}: filling fields..." "" "" 1
        for PRESS in {1..3}; do
          printf ${PRESS}
          key_press ${WID} Return 500
        done
        printf a
        type_input ${WID} ${ACCT} ""
        printf p
        key_press ${WID} Tab
        type_input ${WID} ${PASS} ""
        while ! grep -q MsgClientLogOnResp.*OK ${LOGS}/connection_log.txt; do
          idler_sleep 1
        done
        printf c
        key_press ${WID} Tab 3000
        type_input ${WID} ${PASS} ""
        idler_sleep 1
        key_press ${WID} Return
        while ! grep -q AsyncDisconnect ${LOGS}/connection_log.txt; do
          if ! window_id "Create a Steam" > /dev/null; then
            echo
            tprint "${ACCT}: error, bad password/server, deleting..."
            idler_delete yes > /dev/null
            return 1
          fi
          idler_sleep 0.3
        done
        printf e
        type_input ${WID} ${EMAIL}
        key_press ${WID} Tab
        printf m
        type_input ${WID} ${EMAIL}
        echo
        tprint "${ACCT}: creating account..." ${SECRET},$(steam_memory)
        key_press ${WID} Return
        while ! window_id Working > /dev/null; do
          idler_sleep 0.5
        done
        while window_id Working > /dev/null; do
          if grep -q Operation\ Failed.*OK ${LOGS}/connection_log.txt; then
            tprint "${ACCT}: warning, i/o operation problem..."
            idler_logout yes no > /dev/null
          fi
          idler_sleep 1
        done
        while window_id Create opacity -v > /dev/null; do
          key_press ${WID} Return 1000
        done
        rm -fr ${USERDATA}/anonymous ${USERDATA}/????? ${USERDATA}/??????
        sed -i -e "s/#${EMAIL}//" share/pdl-idler.conf 2> /dev/null

      # wait for authentication
      elif [ -z ${AUTH} ] && [[ ${AUTH_STATE} = *\'OK\'* ]]; then
        local AUTH=$(steam_cellid)\|$(steam_auth_server)
        close_window "${GUARD}" no no Return
        tprint "${ACCT}: authenticated..." ${RETRY}${CRED}${AUTH//.},$(steam_memory)

      # if guard window arrives, prompt for guard code entry
      elif [ -z ${AUTH}${GUARD} ] && window_id Guard > /dev/null; then
        echo -e "read -n 5 -d + -e -t 90 INPUT && echo \${INPUT} || echo _" \
          > wine-${ACCT}/passwd-${ACCT}.sh
        {
          while ! auth_state > /dev/null && steam_pid > /dev/null; do
            sleep 1
          done
          if pgrep -f bash.*passwd-${ACCT}.sh > /dev/null; then
            kill -1 $(pgrep -f bash.*passwd-${ACCT}.sh)
            echo
          fi
        } &
        PASSWD_PID=$!
        tprint "${ACCT}: input guard code:" @${PASSWD_PID},$(steam_memory) "" 1
        INPUT=$(bash wine-${ACCT}/passwd-${ACCT}.sh)
        { kill ${PASSWD_PID} && wait ${PASSWD_PID}; } 2> /dev/null
        if [ "${INPUT}" = _ ]; then
          echo
          tprint "${ACCT}: error, guard timeout" @${PASSWD_PID},$(steam_memory)
          idler_logout > /dev/null
          return 1
        elif [ ! -z ${INPUT} ]; then
          key_press ${WID} Tab\ Return
          type_input ${WID} ${INPUT}
          key_press ${WID} Return
        fi
        local GUARD=${WID}
      elif [[ ${AUTH_STATE} = *Auth\ Code* ]] \
      || [[ ${AUTH_STATE} = *code\ mismatch* ]]; then
        unset GUARD

      # input password if login window arrives # XXX does password entry keep going for a while?
# XXX grep: share/ptendtenlten/config/config.vdf: No such file or directory
# XXX broken: needs to computer cid and whatever cause I deleted userdata erased pakcage doo
      elif [ -z ${AUTH}${CRED} ] && window_id Login > /dev/null; then
        local CRED=${y}/P/${l},
        type_input ${WID} ${PASS}
        key_press ${WID} Return
      elif [[ ${AUTH_STATE} = *Limit\ Exceed* ]]; then
        tprint "${ACCT}: error, hit password limit" $(steam_memory)
        idler_logout > /dev/null
        return 1
      elif [[ ${AUTH_STATE} = *Invalid\ Pass* ]]; then
        let local RETRY+=1
        if [ ${RETRY} = 3 ]; then
          tprint "${ACCT}: error, bad pass/server" $(steam_memory)
          idler_logout > /dev/null
          return 1
        fi
        unset CRED

      # if there is no connection, wait then retry
      elif window_id Connection\ Error > /dev/null; then
        tprint "${ACCT}: warning, offline wait/retry..." 60s,$(steam_memory)
        idler_logout yes no > /dev/null
        idler_sleep 60 > /dev/null

      # close miscellaneous error windows
      elif [ -z ${ERROR} ] && window_id Steam\ -\ Error > /dev/null; then
        local ERROR=${y}*er*${l},
        close_window ${WID}
      elif [ -z ${WARNING} ] && window_id Warning > /dev/null; then
        local WARNING=${y}*wn*${l},
        key_press ${WID} Return

      # wait until logged in
      elif ! grep -q ShowAvatars ${LCONFIG} 2> /dev/null; then
        idler_sleep 1
      else
        break
      fi
    done

    # bypass steam guard location notification
    if window_id Guard\ Notification > /dev/null; then
      tprint "${ACCT}: warning, guard location notify..." $(steam_memory)
      close_window ${WID} no no
    fi

    # restart for initial configuration or finish
    if ! grep -q LaunchOptions ${LCONFIG}; then
      tprint "${ACCT}: restarting for configuration..." $(steam_memory)
      idler_logout "" no > /dev/null
    else
      tprint "${ACCT}: logged in" ${ERROR}${WARNING}$(account_size),$(\
        steam_connect_hash),@${SPID}/$(steam_memory)
      unset LOGIN
    fi
  done
}

# check chatroom id variable and declare node chat code
if [ -z ${CHATROOM} ]; then
  CHATROOM=103582791435720285
fi
prep_chat()
{
  if [ ! -z ${1} ]; then
    if [[ ${1} =~ ^[0-9]*$ ]] && (( $(expr length ${1}) >= 18 )); then
      CHAT=${1}
    else
      tprint "${ACCT}: error, invalid chat id"
      return 1
    fi
  else
    CHAT=${CHATROOM}
  fi
  OPTS=$(cat << EOF 
  var enter_interval = 0;
  while (1) {
    var enter_index = log.indexOf('ENTER_', log_index-1);
    if (enter_index = -1) {
      break;
    }
    log_index = log.indexOf('__n', enter_index);
    setTimeout(function(start, end) {
      steam.sendMessage('${CHATROOM}', log.substring(start+6, end));
    }, enter_interval*750, enter_index, log_index);
    enter_interval++;
  }
EOF
  )
}

node_module_version()
{
  # get version of installed node module
  if ! grep -m 1 \"version\": steamnode/node_modules/$(echo ${1##*node-} \
  | sed s/.git//)/package.json 2> /dev/null | grep -o \[0-9\.]*; then
    echo none
  fi
}

install_node_module()
{
  # download and install specified node module with npm
  local INSTALLED=$(node_module_version ${1})
  local VERSION=${2}
  if [ ! -e steamnode/node_modules/$(echo ${1##*node-} \
  | sed s/.git//)/package.json ] || [ ${VERSION} != ${INSTALLED} ]; then
    if [ -d ${HOME}/.npm ]; then
      NPM=yes
    fi
    if [ ${INSTALLED} = none ]; then
      tprint "installing node-${1##*node-}..." v${VERSION}
    else
      tprint "upgrading node-${1##*node-}..." v${INSTALLED}\>${VERSION}
    fi
    if [[ ${1} = git* ]]; then
      VERSION=\#v${VERSION}
    else
      VERSION=@${VERSION}
    fi
    mkdir -p steamnode
    cd steamnode
    npm install ${1}${VERSION} > /dev/null 2>&1 || exit 1
    cd ..
    if [ -z ${NPM} ]; then
      rm -fr ${HOME}/.npm ${HOME}/.node-gyp
    fi
    for NPM_DIR in /tmp/npm-*; do
      if [ -d ${NPM_DIR} ] \
      && ! ps $(echo ${NPM_DIR:9} | sed "s/-.*//") | grep npm; then
        rm -fr ${NPM_DIR}
      fi
    done
    rm -f npm-debug.log
    rmdir ${HOME}/tmp 2> /dev/null
  fi
}

node_fake_appid()
{
  # get game appids being faked by node
  tac ${NODEJS} | grep -om 1 "gamesPlayed([\[0-9,]*\])" | grep -o \[0-9,]*
}

prep_node_login()
{
# XXX wip
if [ ! -e share/${ACCT}/ssfn ]; then
  mkdir -p share/${ACCT}
  cp -v share/ssfn share/${ACCT}/ssfn
fi
  # check api key+ssfn, install node-steam, and prep script once per execution
  if [ -z ${APIKEY} ]; then
    tprint "error, web api key not set" steamcommunity.com/dev/apikey
    return 1
  elif [ ! -e share/${ACCT}/ssfn ]; then
    tprint "${ACCT}: error, no ssfn file"
    return 1
  elif ! grep -q "\(exit, 4444\)" ${NODEJS} 2> /dev/null || [ ! -z ${1} ]; then
    install_node_module ref 1.1.3
    install_node_module protobufjs 5.0.1
    install_node_module steam 0.6.8

    # check node server list
    if [ -e steamnode/servers ] && [ ! -s steamnode/servers ]; then
      tprint "${ACCT}: warning, reset empty node servers file"
      rm steamnode/servers
    fi

    # wait for a previous execution to complete or suspend fake session
    unset BREAK NODE_WAIT
    if [ -e ${NODELOG} ]; then
      while ! is_node_login_available; do
        if [ -z ${NODE_WAIT} ]; then
          if grep -q BREAK_FAKE ${NODELOG}; then
            BREAK=$(node_fake_appid)
            RELOGIN=re
            stop_node_login > /dev/null
          else
            NODE_WAIT=yes
            tprint "${ACCT}: warning, waiting on prior node finish..." \<60sec
          fi
        fi
        idler_sleep 1
      done
    fi

    # make account specific web script
    touch ${NODEJS}
    cat << EOF > ${NODEJS}
    //${HOSTNAME}
    //@$$
    var broken = 0, counter = 0, exit_action, exit_retry, exit_timeout,
      exiting = 2, first_line, fs = require('fs'), logged_on, Steam = require(
        '${PWD}/steamnode/node_modules/steam'), steam = new Steam.SteamClient(),
      util = require('util'), log_index = 0;
    require('${PWD}/steamnode/node_modules/ref');
    function exit(value) {
      if (exiting == 2) {
        if (logged_on) {
          steam.gamesPlayed([]);
          steam.logOff();
        }
        console.error('EXIT');
        if (!first_line) {
          util.print('\n');
        }
        process.exit(value);
      } else {
        exiting = 1;
      }
    }
    process.on('SIGINT', function() {
      console.error('SIGINT');
      exit(0);
    });
    process.on('SIGTERM', function() {
      console.error('SIGTERM');
      exit(0);
    });
    setInterval(function() {
      var log = fs.readFileSync('${NODELOG}', 'utf8');
      if (log.indexOf('QUIT') > -1) {
        exit(0);
      }
      ${2}
      counter++;
      if (counter == 4) {
        time = Math.round((new Date()).getTime() / 1000);
        fs.utimesSync('${NODELOG}', time, time);
        counter = 0;
      }
    }, 5000);
    if (fs.existsSync('steamnode/servers')) {
      Steam.servers = JSON.parse(fs.readFileSync('steamnode/servers'));
    }
    function pad(i) {
      return (i < 10) ? "0" + i : "" + i;
    }
    function tprint(line, first) {
      if (!broken) {
        var date = new Date();
        var prefix = '[' + pad(date.getHours().toString()) + ':'
          + pad(date.getMinutes().toString()) + ':'
          + pad(date.getSeconds().toString()) + '] ' + process.argv[2] + ': ';
        if (first_line === undefined) {
          first_line = 0;
          line = prefix + line;
        }
        if (!first_line) {
          if (!first) {
            first_line = 1;
            util.print('\n');
          } else {
            if (first == 2) {
              first_line = 1;
              line += '\n';
            }
            util.print(line);
            return 0;
          }
        }
        if (first_line) {
          console.log(prefix + line);
        }
      }
    }
    function exitTimeout() {
      if (!exit_retry) {
        tprint('error, node action "' + exit_action + '" timed out {!}');
      } else {
        tprint('warning, node action "' + exit_action + '" timed out {*}');
      }
      console.error('FAIL' + exit_retry);
      exit(1);
    }
    function setExitTimeout(time, action, retry) {
      exit_timeout = setTimeout(exitTimeout, time);
      exit_action = action;
      exit_retry = retry;
    }
    setExitTimeout(30000, 'logon', 'RETRY');
    function exitBreak(action, broke) {
      if (!first_line) {
        first_line = 1;
        util.print('\n');
      }
      console.error('BREAK_' + action);
      broken = broke;
    }
    tprint('${RELOGIN}logon... ', 1);
    steam.logOn({
      accountName: process.argv[2],
      password: '${PASS}',
      shaSentryfile: require('crypto').createHash('sha1').update(
        fs.readFileSync('share/' + process.argv[2] + '/ssfn')).digest()
    });
    steam.on('servers', function(servers) {
      fs.writeFile('steamnode/servers', JSON.stringify(servers));
      if (exiting == 1) {
        exiting = 2;
        exit(1);
      }
      exiting = 2;
    });
    steam.on('loggedOn', function() {
      if (!logged_on) {
        exiting = 0;
        logged_on = 1;
        clearTimeout(exit_timeout);
        setTimeout(exit, 4444);
      }
    });
    steam.on('loggedOff', function() {
      console.error('LOGOFF');
      logged_on = 0;
    });
    steam.on('error', function(error) {
      if (error.cause == 'logonFail') {
        console.error('FAILLOGON_' + error.eresult);
      }
      exit(1);
    });
EOF
    unset RELOGIN
  fi
}

prep_node_enter()
{
  # enter chatroom
  if ! grep -q joinChat ${NODEJS}; then
    OPTS=$(cat << EOF 
    tprint('entering chatroom...'${2});
    steam.joinChat('${1}');
EOF
    )
    sed -i -e "s/setTimeout(exit, 4444);/${OPTS//$'\n'/\\$'\n'}/g" ${NODEJS}
    cat << EOF >> ${NODEJS}
    steam.on('chatEnter', function(chatid, response) {
      if (response != 1) {
        tprint('error, chat entry failure code: ' + response + ' {!}');
        console.error('FAIL');
        exit(1);
      }
      setTimeout(exit, 4444);
    });
EOF
  fi
}

prep_node_http()
{
  # use http requests to the web api
  if ! grep -q http_opt ${NODEJS}; then
    cat << EOF >> ${NODEJS}
    var http = require('http');
    var http_opt = { host: 'api.steampowered.com' };
EOF
  fi
}

idler_fake()
{
  # feign play activity for tf2 or specified underscore-seperated game appid(s)
  local APPID=440
  if [ ! -z ${1} ]; then
    APPID=${1//-/,}
    APPID=${1//_/,}
  fi
  if ! is_node_login_available && grep -q BREAK_FAKE ${NODELOG} \
  && [ $(node_fake_appid) != ${APPID} ]; then
    stop_node_login > /dev/null
    RELOGIN=re
  fi
  if is_node_login_available; then
    prep_node_login ${2} || return 1
    OPTS="tprint('faking play on ${APPID}...', 2);"
    if [ ! -z ${BREAK} ]; then
      OPTS="tprint('resumed faking play on ${APPID}...', 2);"
    fi
    OPTS="${OPTS}\nsteam.setPersonaState(Steam.EPersonaState.Busy);"
    if [ ${APPID} != 440 ] || ! grep -q "\(\[440\]\)" ${NODEJS}; then
      OPTS="${OPTS}\nsteam.gamesPlayed([${APPID}]);"
    fi
    sed -i -e "s/setTimeout(exit, 4444);/${OPTS}\n&/" ${NODEJS}
    cat << EOF >> ${NODEJS}
    steam.on('friendMsg', function(user, msg, status) {
      if (status == Steam.EChatEntryType.ChatMsg) {
        console.error(user + ': ' + msg)
      }
    });
EOF
    FAKE=yes
    return 0
  elif [ $(node_fake_appid) != ${APPID} ]; then
    tprint "${ACCT}: error, node action running"
  fi
  return 1
}

set_xfce_power()
{
  # set xfce power manager ac suspend setting
  xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/inactivity-on-ac \
    -s ${1}
  DBUS_SESSION_BUS_ADDRESS=$(cat /proc/${XFCE_PID}/environ | tr '\0' '\n' \
    | grep _SESSION_BUS_ADDRESS | cut -d '=' -f2-) xfce4-power-manager --restart
  idler_sleep 1
  DISPLAY=:0 xdotool mousemove $(shuf -i 0-800 -n 1) $(shuf -i 0-600 -n 1)
}

# deduce node binary
if node --help 2> /dev/null | grep -q script.js; then
  NODE=$(which node)
elif which nodejs > /dev/null 2>&1; then
  NODE=$(which nodejs)
else
  tprint "fatal, node binary could not be found"
  exit 1
fi

run_node_login()
{
  # insert refake instruction and/or break (disabling pm), then execute script
  if [ ! -z ${BREAK} ]; then
    idler_fake ${BREAK}
  fi
  if [ ! -z ${FAKE} ] ; then
    sed -i -e "s/setTimeout(exit, 4444);/exitBreak('FAKE', 1);/" ${NODEJS}
  else
    sed -i -e "s/setTimeout(exit, 4444);/exit(0);/" ${NODEJS}
  fi
  unset BREAK FAKE
  ${NODE} ${NODEJS} ${ACCT} 2> ${NODELOG} &
  while ! pgrep -f "${NODE} ${NODEJS}" > /dev/null; do
    idler_sleep 0.3
  done
  while pgrep -f "${NODE} ${NODEJS}" > /dev/null; do
    if tac ${NODELOG} | grep -q ^BREAK; then
      if tac ${NODELOG} | grep -q ^BREAK_[E-F]; then
        disable_power_management
      fi
      return 0
    fi
    idler_sleep 1
  done
  touch -d "1 hour ago" ${NODELOG}
  if grep -q ^FAILLOGON ${NODELOG}; then
    tprint "${ACCT}: error, node steam login failure"
    return 1
  elif grep -q ^FAILRETRY ${NODELOG}; then
    run_node_login
    return $?
  elif grep -q ^FAILCONTINUE ${NODELOG}; then
    return 1
  elif grep -q ^FAIL ${NODELOG} || grep -q ^SIGINT ${NODELOG}; then
    return 2
  elif grep -q Error: ${NODELOG}; then
    cat ${NODELOG}
    return 2
  fi
}

player_items()
{
  # get player item data from web api
  ITEMS="http://api.steampowered.com/IEconItems_440/GetPlayerItems"
  ITEMS="${ITEMS}/v0001?key=${APIKEY}&steamid=$(steam_uid ${ACCT})"
  ITEMS=$(wget -qO- "${ITEMS}")
  echo "${ITEMS}"
}

steam_name()
{
  # get steam community profile name
  echo $(grep PersonaName ${LCONFIG} | awk '{$1=""; print $0}' | sed s/\"//g)
}

check_item_safety()
{
  # compare current account to item safety variable
  if echo ${ITEM_SAFETY} | grep -q "\<${ACCT}\>"; then
    tprint "${ACCT}: error, protected by safety variable" ${ACTION}
    sed -i -e "/setTimeout(exit, 4444);/d" ${NODEJS}
    return 1
  fi
}

prep_node_coordinator()
{
  # act on init reply from GC for item changes
  if ! grep -q fromGC ${NODEJS}; then
    prep_node_http
    OPTS=$(cat << EOF 
    tprint('game... ', 1);
    steam.gamesPlayed([440]);
    coordinate_timeout = setTimeout(function() {
      var buffer = new Buffer(8);
      buffer.writeUInt64LE(1);
      steam.toGC(440, 4006 | 0x80000000, buffer);
    }, 3000);
    setExitTimeout(30000, 'game');
EOF
    )
    sed -i -e "s/setTimeout(exit, 4444);/${OPTS//$'\n'/\\$'\n'}/g" ${NODEJS}
    cat << EOF >> ${NODEJS}
    var coordinate = 0, coordinate_timeout;
    steam.on("fromGC", function(appid, type, message, args) {
      var msg = type & ~0x80000000;
      console.error(msg);
      if (!coordinate && (msg == 1049 || msg == 6500 || msg == 4004)) {
        clearTimeout(coordinate_timeout);
        clearTimeout(exit_timeout);
        coordinate = 1;
        setTimeout(exit, 4444);
      } // ELSEGC
    });
EOF
  fi
  if [ ! -z "${1}" ]; then
    sed -i -e "s/setTimeout(exit, 4444);/${1//$'\n'/\\$'\n'}/g" ${NODEJS}
  fi
  if [ ! -z "${2}" ]; then
    OPTS="${2//$'\n'/\\$'\n'}"
    sed -i -e "s/.*} \/\/ ELSEGC/${OPTS//&/\\&}\n&/g" ${NODEJS}
  fi
}

idler_sort()
{
  # arrange player backpack by id, then delete drops file
  check_item_safety || return 1
  prep_node_login || return 1
  OPTS=$(cat << EOF 
  tprint('sorting player backpack...');
  var buffer = new Buffer(2);
  buffer.writeUInt16LE(4, 0);
  steam.toGC(440, 1041 | 0x80000000, buffer);
EOF
  )
  OPTS1=$(cat << EOF 
  if (fs.existsSync('share\/${ACCT}\/drops')) {
    fs.unlinkSync('share\/${ACCT}\/drops');
  }
  setTimeout(exit, 4444);
EOF
  )
  prep_node_coordinator "${OPTS}" \
    "} else if (msg == 1058) {\n${OPTS1}" || return 1
}

prep_node_backpack()
{
  # use webapi backpack data retrieval
  if ! grep -q function\ getBackpack ${NODEJS}; then
    cat << EOF >> ${NODEJS}
    var backpack, backpack_errors = 0, craft_count;
    function getBackpack(callback) {
      if (backpack === undefined) {
        tprint('item... ', 1);
        backpack = 0;
      }
      console.error('BACKPACK');
      http_opt.path = '/IEconItems_440/GetPlayerItems/v0001/?SteamID='
        + steam.steamID + '&key=${APIKEY}';
      http.get(http_opt, function(response) {
        var output = '';
        response.on('data', function(chunk) {
          output += chunk;
        });
        response.on('end', function() {
          backpack = JSON.parse(output).result.items;
          if (!backpack) {
            tprint('error, backpack private or other problem {!}');
            exit(1);
          }
          backpack_errors = 0;
          callback();
        });
        response.on('error', function(error) {
          console.error(error);
          if (backpack_errors == 10) {
            tprint('error, tf2 backpack service down {!}');
            exit(1);
          }
          backpack_errors++;
          setTimeout(1000, getBackpack, callback);
        });
      });
    }
EOF
  fi
}

# delete common crates or all of the specified underscore-seperated defindexes
CRATES=${CRATES}5734,5735,5742,5752,5781,5802,5803,5859,5849
idler_waste()
{
  check_item_safety || return 1
  prep_node_login || return 1
  DEFINDEX=${CRATES}
  if [ ! -z ${1} ]; then
    DEFINDEX=${1//_/,}
    DEFINDEX=${DEFINDEX//crates/${CRATES}}
  fi
  OPTS1=$(cat << EOF 
  if (craft_count == -1) {
    waste();
  } else {
    getBackpack(waste);
  }
EOF
  )
  OPTS2=$(cat << EOF 
  } else if (msg == 23 && waste_count) {
    if (!--waste_count) {
      setTimeout(exit, 4444);
    }
EOF
  )
  prep_node_coordinator "${OPTS1}" "${OPTS2}" || return 1
  prep_node_backpack
  cat << EOF >> ${NODEJS}
  var waste_count, waste_delay = 0;
  function waste() {
    items = backpack.filter(function(item) {
      return [${DEFINDEX}].indexOf(item.defindex) != -1;
    });
    if (items.length == 0) {
      tprint('no items to delete');
      setTimeout(exit, 4444);
    } else {
      waste_count = items.length;
      tprint('deleting ' + items.length + '/' + backpack.length + ' items...');
      items.forEach(function(item) {
        var buffer = new Buffer(8);
        buffer.writeUInt64LE(item.id);
        setTimeout(function() {
          steam.toGC(440, 1004, buffer);
        }, 200*waste_delay++);
      });
    }
  }
EOF
}

prep_node_schema()
{
  # use webapi item schema retrieval
  if ! grep -q var\ schema ${NODEJS}; then
    prep_node_http
    echo "var schema, schema_url;" >> ${NODEJS}
    OPTS=$(cat << EOF 
    http_opt.path =
      '/IEconItems_440/GetSchemaURL/v1/?language=en&key=${APIKEY}';
    http.get(http_opt, function(response) {
      var output = '';
      response.on('data', function(chunk) {
        output += chunk;
      });
      response.on('end', function() {
        var obj = JSON.parse(output);
        schema_url = obj.result.items_game_url;
        if (fs.existsSync('steamnode/schema')
        && fs.existsSync('steamnode/.schema_url')
        && schema_url == fs.readFileSync('steamnode/.schema_url')) {
          schema = JSON.parse(fs.readFileSync('steamnode/schema'));
          setTimeout(exit, 4444);
        } else {
          tprint('schema... ', 1);
          http_opt.path = 
            '/IEconItems_440/GetSchema/v0001/?language=en&key=${APIKEY}';
          http.get(http_opt, function(response) {
            var output = '';
            response.on('data', function(chunk) {
              output += chunk;
            });
            response.on('end', function() {
              var obj = JSON.parse(output);
              schema = {};
              obj.result.items.forEach(function(item) {
                schema[item.defindex] = item;
              })
              fs.writeFileSync('steamnode/schema', JSON.stringify(schema));
              fs.writeFileSync('steamnode/.schema_url', schema_url);
              setTimeout(exit, 4444);
            });
          });
        }
      });
    });
EOF
    )
    OPTS="${OPTS//\//\\/}"
    OPTS="${OPTS//&/\\&}"
    sed -i -e "s/setTimeout(exit, 4444);/${OPTS//$'\n'/\\$'\n'}/g" ${NODEJS}
  fi
}

idler_craft()
{
  # create metal with optional underscore-seperated weapon defindex negations
  check_item_safety || return 1
  DEFINDEX=266,433,452,466,572,574,587,638,727,850,851,863,933,947
  if [ ! -z ${1} ]; then
    DEFINDEX=${DEFINDEX},${1//_/,}
  fi
  prep_node_login || return 1
  OPTS=$(cat << EOF 
  } else if (msg == 1003) {
    if (!--craft_count) {
      craft();
    }
EOF
  )
  prep_node_coordinator "" "${OPTS}" || return 1
  prep_node_backpack
  prep_node_schema
  sed -i -e "s/setTimeout(exit, 4444);/getBackpack(_craft);/" ${NODEJS}
  cat << EOF >> ${NODEJS}
  var craft_mode = 1, craft_available;
  function _craft() {
    if (craft_mode == 1) {
      var items = backpack.filter(function(item) {
        return schema[item.defindex].craft_material_type == 'weapon'
        && !('flag_cannot_trade' in item) && !('flag_cannot_craft' in item)
        && item.quality == 6 && [${DEFINDEX}].indexOf(item.defindex) == -1
        && schema[item.defindex].name.indexOf('TF_WEAPON_') == -1
        && schema[item.defindex].name.indexOf('Festive') == -1
        && schema[item.defindex].name.indexOf('Botkiller') == -1
        && schema[item.defindex].item_class != 'saxxy';
      });
      craft_available = items.length;
      var craft_total = backpack.filter(function(item) {
        return schema[item.defindex].craft_material_type == 'weapon';
      }).length;
    } else {
      var items = backpack.filter(function(item) {
        if (craft_mode == 2) {
          return item.defindex == 5000 && !('flag_cannot_trade' in item);
        }
        return item.defindex == 5001 && !('flag_cannot_trade' in item);
      });
      var craft_total = items.length;
    }
    var crafts = [];
    while (true) {
      if ((craft_mode == 1 && items.length < 2)
      || ((craft_mode > 1 && items.length < 3))) {
        break;
      }
      if (craft_mode == 1) {
        var first = items.shift();
        var classes = schema[first.defindex].used_by_classes || [];
        var choices = items.filter(function(item) {
          return schema[item.defindex].craft_material_type == 'weapon'
          && classes.filter(function(n) {
            return schema[item.defindex].used_by_classes.indexOf(n) != -1
          }).length;
        });
        if (!choices.length) {
          continue;
        }
        crafts.push(
          [first.id, items.splice(items.indexOf(choices.shift()), 1)[0].id]);
      } else {
        crafts.push([items.shift().id, items.shift().id, items.shift().id]);
      }
    }
    if (crafts.length) {
      craft_count = crafts.length;
      if (craft_mode == 1) {
        tprint('smelting ' + craft_count*2 + '/' + craft_available
          + '/' + craft_total + ' weapons... ');
      } else if (craft_mode == 2) {
        tprint('combining ' + craft_count*3 + '/' + craft_total + ' scrap... ');
      } else {
        tprint('joining ' + craft_count*3 + '/' + craft_total + ' reclaimed... ');
      }
      var craft_delay = 0;
      crafts.forEach(function(craft) {
        var buffer = new Buffer(2 + 2 + 8 * craft.length);
        buffer.writeInt16LE(-2, 0);
        buffer.writeInt16LE(craft.length, 2);
        var i = 0;
        craft.forEach(function(item) {
          buffer.writeUInt64LE(item, 4 + i * 8);
          i++;
        });
        setTimeout(function() {
          steam.toGC(440, 1002, buffer);
        }, 200*craft_delay++);
      });
    } else {
      if (craft_count !== undefined) {
        craft_count = -1;
      }
      craft();
    }
  }
  function craft() {
    if (++craft_mode == 4) {
      if (craft_count === undefined) {
        tprint('nothing crafted');
        craft_count = -1;
      }
      setTimeout(exit, 4444);
    } else if (craft_count == 0) {
      getBackpack(_craft);
    } else {
      _craft();
    }
  }
EOF
}

idler_deterge()
{
  # craft, waste, then sort in one node login
  idler_craft ${1%%:*}
  if [[ ${1} = *:* ]]; then
    idler_waste ${1##*:}
  else
    idler_waste
  fi
  idler_sort
}

idler_play()
{
  # initiate app launch after prior stop wait and blocking
  tprint "${ACCT}: preparing app..." \
    $(app_size 440 yes),v$(app_version 440),$(steam_memory),\#440
  wait_for_stop
  block_on_file steam/.steamapps

  # close ready/updated windows, then (re)initiate launch when ready
  while ! hl2_pid > /dev/null; do
    if ! app_state > /dev/null; then
      if close_window $(window_id Ready) \
      || close_window $(window_id Updating); then
        local READIED=${y}R${l},
        unset READY
      fi
      if [ "${READY}" = 10 ]; then
        unset READY
      fi
      if [ -z ${READY} ]; then
        wine_run C:/Steam/steam.exe -applaunch 440 ${1}
      fi
      let local READY+=1
    fi
    idler_sleep 1

    # check activity and error/update windows and login override
    app_activity 440
    if window_id Update\ Available > /dev/null; then
      tprint "${ACCT}: warning, available update..." $(steam_memory)
      close_window ${WID} no no Return
    elif window_id Error\ -\ Steam > /dev/null; then
      tprint "${ACCT}: warning, consuming other login..." $(steam_memory)
      close_window ${WID} no ""
    elif window_id latest\ DirectX > /dev/null; then
      tprint "${ACCT}: fatal, directx problem..." $(steam_memory)
      exit 1

    # if game is unavailable, warn then retry 3 times
    elif window_id Steam\ -\ Error > /dev/null; then
      let local ERRORS+=1
      if [ ${ERRORS} = 1 ]; then
        tprint "${ACCT}: warning, game unavailable..." $(steam_memory)
      fi
      close_window ${WID}
      unset READY
      if [ "${ERRORS}" = 3 ]; then
        tprint "${ACCT}: fatal, steam servers down" $(steam_memory)
        exit 1
      fi

    # if cloud conflicts, warn then bypass
    elif [ -z ${CLOUD} ]; then
      if window_id "Warning" > /dev/null; then
        local CLOUD=yes
        tprint "${ACCT}: warning, cloud warning..." $(steam_memory)
        close_window ${WID} no no Return
      elif window_id "Cloud Sync Conflict" > /dev/null; then
        local CLOUD=yes
        tprint "${ACCT}: warning, cloud conflict..." $(steam_memory)
        mouse_click ${WID} 300 165 2
      fi
    fi
  done

  # write version file, wait on client load, then disable pm
  tprint "${ACCT}: loading app..." ${READIED}@${HPID},$(both_memory)
  unset DOWNLOADING VALIDATING COMMITTING
  rm -f steam/.steamapps-${HOSTNAME}.lock
  app_version 440 > "${ATF}"/pdl-${ACCT}/ver
  while true; do
    if ! hl2_pid > /dev/null; then
      tprint "${ACCT}: error, app crashed" $(steam_memory)
      return 1
    elif tac ${CON} | grep -m1 ": Disconnect\|: Shutdown function" \
    | grep -q Disconnect; then
      tprint "${ACCT}: client started" v$(app_version 440),$(both_memory)
      break
    fi
    idler_sleep 1
  done
  disable_power_management
}

client_connection()
{
  # get connection time and status of client
  CONNECTION=$(tac ${CON} \
    | grep -m1 ": Disconnect\|: Connected to\| connected\|: Compact freed")
  local TIME=$(($(date +%s)-$(date -d "$(echo "${CONNECTION}" \
    | sed -e 's/: .*//' -e 's/ - / /')" +%s)))
  TIME=$(echo - | awk \
    '{printf "%02d:%02d",'${TIME}'/(60*60),'${TIME}'%(60*60)/60}')\|
  if echo "${CONNECTION}" | grep -q Disconnect; then
    CONNECTION=${TIME}\ Disconnect
    echo ${TIME} Disconnect
    return 1
  elif echo "${CONNECTION}" | grep -q Compact; then
    IP=Listen
  else
    IP=$(echo "${CONNECTION}" | grep -o Connected\ to.* | grep -o \[0-9.:]*)
  fi
  CONNECTION="${TIME} ${IP}"
  echo ${CONNECTION}
  if [ -z ${IP} ]; then
    return 1
  fi
  return 0
}

net_address()
{
  # get host network address
  ip route get 8.8.8.8 | awk '{print $7}'
}

# parse or accept input then run command on the client
idler_command()
{
  if ! is_commandable; then
    tprint "${ACCT}: error, manual client has not loaded aliases"
    return 1
  else
    COMMAND="${1}"
    if [ -z "${COMMAND}" ]; then
      tprint "${ACCT}: input command:" @${HPID} "" 1
      read -e COMMAND
      if [ -z "${COMMAND}" ]; then
        tprint "${ACCT}: fatal, no input"
        exit 1
      fi
    fi
    tprint "${ACCT}: running '${ARG//^/ }'..." $(both_memory)
    echo -e "${1}\nwriteip" > "${ATF}"/pdl-${ACCT}/cfg/banned_ip.cfg
    while ! grep -q addip "${ATF}"/pdl-${ACCT}/cfg/banned_ip.cfg; do
      idler_sleep 0.3
      let local CMD_TIMEOUT+=1
      if [ ${CMD_TIMEOUT} = 240 ]; then
        tprint "${ACCT}: error, command failed" X,$(both_memory)
        return 1
      fi
    done
    echo "//${1}" > "${ATF}"/pdl-${ACCT}/cfg/banned_ip.cfg
    return 0
  fi
}

idler_disconnect()
{
  # disconnect client from server
  if client_connection > /dev/null; then
    if [[ ${CONNECTION} = *$(net_address):281[0-9][0-9] ]]; then
      local PLAYER={$(server_playercount ${CONNECTION:(-2)}\
        )/$((IDLE_MAX+1))},\#${CONNECTION:(-2)},
    fi
    tprint "${ACCT}: disconnecting..." ${PLAYER}${CONNECTION:0:5},$(both_memory)
    idler_command "mmute;disconnect;echo Disconnect" > /dev/null || return 1
  fi
}

server_memory()
{
  # get memory usage of a server process via port number
  memory $(pgrep -f srcds_linux.*281${1:(-2)})
}

item_schema()
{
  # get item schema from specified log
  SCHEMA=$(tac "${1}" | grep -om1 version\ \[A-F0-9]* | awk '{print $2}')
  if [ -z ${SCHEMA} ]; then
    echo noschema
    return 1
  fi
  echo \&${SCHEMA}
}

client_map()
{
  # get map load status of client
  if tac ${CON} | grep -m 1 ": Disconnect\|: Compact free" | grep -q Compact; then
    echo $(tac ${CON} | grep -om 1 ^Map:\ \[[:graph:]]* | awk '{print $2}')
    return 0
  fi
  return 1
}

idler_connect()
{
  # if specified, check location server/map
  unset LOCATION TEST
  if [ ! -z ${1} ]; then
    TEST=${1}
    if [[ ${TEST} = *.* ]]; then
      TEST=${1}
      if [[ ${TEST} != *:* ]]; then
        TEST="${TEST} 27015"
      fi
      TEST="${TEST/:/ }"
      if ! nc -vzu ${TEST} 2> /dev/null; then
        tprint "warning, no server on ${1}"
        unset TEST
      else
        LOCATION="connect ${1}"
        if [[ ${LOCATION} != *:* ]]; then
          LOCATION="connect ${1}:27015"
        fi
      fi
    else
      LOCATION="map ${1}"
    fi
  fi

  # start normal client if connecting to a location server or if not started
  if hl2_pid noshaderapi > /dev/null; then
    if [ ! -z "${LOCATION}" ] && [[ ${LOCATION/*:} != 281[0-9][0-9] ]]; then
      tprint "${ACCT}: warning, restarting farm client..." $(both_memory)
      idler_stop
    else
      local NOSHADERAPI=yes
    fi
  elif ! hl2_pid > /dev/null; then
    idler_play || return 1
  fi

  # if no location server, use idle server on first available server or port
  if [ -z "${TEST}" ]; then
    start_server
    LOCATION=connect\ $(ip addr | grep -v \ lo \
      | grep -om1 "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*/" | sed "s/\///"):${PORT:(-5)}
    if [ ! -z "${SCON}" ]; then
      while ! grep -q "VAC secure mode is activated" "${SCON}"; do
        idler_sleep 1
      done
      tprint "getting server schema..." \
        @$(pgrep -f srcds_linux.*${PORT:(-5)}),$(server_memory ${PORT})
      while ! item_schema "${SCON}" > /dev/null; do
        idler_sleep 1
      done
      tprint "server started" $(item_schema "${SCON}"),$(server_memory ${PORT})
    fi
    unset SCON PORT
  fi

  # proceed if not already connected to specified server
  if ! tac ${CON} | grep -m 1 ": Disconnect\|: Connected to" \
  | grep -q ${LOCATION/* /}; then
    idler_disconnect

    # issue location command then wait till connected or in-game
    if [[ "${LOCATION}" != map* ]]; then
      tprint "${ACCT}: querying server..." $(echo ${LOCATION:8} | \
        sed -e "s/:.*//" -e "s/[0-9]*\.[0-9]*\./*/"),$(item_schema ${CON}),$(\
        both_memory)
    fi
    if ! idler_command "${LOCATION}" > /dev/null; then
      return 1
    else
      if [[ "${LOCATION}" != map* ]]; then
        local SKIP CONNECT RETURN
        while ! client_connection > /dev/null; do
          if [ -z ${SKIP} ]; then
            if [ -z ${NOSHADERAPI} ]; then
              if tac ${CON} | grep "Bad password\|pdlconnect" \
              | grep -q password; then
                tprint "${ACCT}: error, wrong password..." $(both_memory)
              elif tac ${CON} | grep "Server is full\|pdlconnect" \
              | grep -q full; then
                tprint "${ACCT}: error, server is full..." $(both_memory)
              elif tac ${CON} | grep "have been banned\|pdlconnect" \
              | grep -q banned; then
                tprint "${ACCT}: error, account banned..." $(both_memory)
              fi
            fi
            if tac ${CON} | grep -m 1 "correct\ chall\|Bad\ chall\|pdlconnect" \
            | grep -q challenge; then
              tprint "${ACCT}: warning, bad challenge..." $(both_memory)
              idler_command retry > /dev/null
              SKIP=no
              RETURN=no
            elif tac ${CON} | grep -m1 "er version of\|pdlconnect" \
            | grep -q version; then
              tprint "${ACCT}: error, version mismatch..." $(both_memory)
              if [ ! -z ${NOSHADERAPI} ]; then
                idler_stop > /dev/null
                return 1
              fi
            elif grep -qm1 "are in insecure\|VAC banned" ${CON}; then
              tprint "${ACCT}: error, insecure client log out..." $(both_memory)
              idler_logout yes
            else
              CONNECT=no
              RETURN=no
            fi
            if [ -z ${CONNECT} ]; then
              idler_command echo\ pdlconnect > /dev/null
            fi
            if [ -z ${RETURN} ]; then
              return 1
            fi
          fi
          idler_sleep 1
        done
      fi
      if [[ ${LOCATION/*:} = 281[0-9][0-9] ]]; then
        local MAP={$((PLAYER+1))/$((IDLE_MAX+1))},\#"${LOCATION:(-2)}",
      else
        tprint "${ACCT}: loading map..." $(both_memory)
        while ! client_map > /dev/null; do
          idler_sleep 1
        done
        local MAP=$(client_map),
      fi
      tprint "${ACCT}: connected" ${MAP}$(both_memory)
    fi
  fi
}

auxiliary_pid()
{
  # find auxiliary pid tied to current account prefix
  for XPID in $(pgrep -f ${1}); do
    if grep -q ${WINEPREFIX} /proc/${XPID}/environ; then
      echo ${XPID}
      return 0
    fi
  done
  return 1
}

# check player items in background
if [ -z ${DROP_IRC} ]; then
  DROP_IRC=yes
fi
if [ -z ${DROP_CHAT} ]; then
  DROP_CHAT=yes
fi
idler_farm()
{
  if [[ "${1}${DROP_DETERGE}" = [1-9][0-9]* ]]; then
    if [ -z ${SUID} ]; then
      tprint "error, account uid unknown, skipping deterge"
    else
      player_items > .items-${ACCT}.pdl &
    fi
  fi

  # find first available X display, login, set xroot color, then kill explorer
  if ! steam_pid _:[1-9][0-9]* > /dev/null; then
    if steam_pid > /dev/null; then
      tprint "${ACCT}: warning, restarting steam..." $(both_memory)
      idler_logout > /dev/null
    fi
    while true; do
      export DISPLAY=:$((${DISPLAY:1}+1))
      if [ $(pgrep -f steam.exe.*_${DISPLAY} | wc -l) != $((32*2)) ]; then
        break
      fi
    done
    DLLS=audio,mss32,binkw32,bsppack,bugreporter,bugreporter_filequeue
    DLLS=${DLLS},bugreporter_public,commedit,datamodel,dmserializers
    DLLS=${DLLS},hammer_dll,haptics,icudt,icudt42,libsasl,mysql_wrapper
    DLLS=${DLLS},pet,plugplay.exe,serverplugin_empty,shadercompile_dll,sixense
    DLLS=${DLLS},sixense_utils,soundsystem,sourcevr,telemetry32
    DLLS=${DLLS},texturecompile_dll,unicows,unitlib,valvedeviceapi,vaudio_miles
    DLLS=${DLLS},video_bink,video_quicktime,vmt,vrad_dll,vtex,
    idler_login lo ${DLLS} farm || return $?
    xsetroot -solid \#3a342e
    kill $(auxiliary_pid explorer.exe)

    # manage console links, change gameinfo pdl directory, then add cvars
    rm -f "${ATF}"/con-*.log
    ln -sf "${PWD}"/${CON} "${TF}"/con-${ACCT}.log
    sed -e "s/${HOSTNAME}-[0-9]*/${ACCT}/" "${STF}"/gameinfo.txt > "${ATF}"/gameinfo.txt
    sed -i -e "/_acmd;/d" "${ATF}"/pdl-${ACCT}/cfg/${ACCT//./}+.cfg
    {
      echo "alias _acmd \"exec banned_ip;wait 8;_acmd\""
      echo "_acmd"
      echo "sv_cheats \"1\""
      echo "fps_max \"1\""
      echo "datacachesize \"32\""
      echo "tv_nochat \"1\""
      echo "voice_enable \"0\""
      echo "mat_loadtextures \"0\""
      echo "mat_managed_textures \"0\""
      echo "mat_mipmaptextures \"0\""
      echo "mat_norendering \"1\""
      echo "mat_phong \"0\""
      echo "mat_showlowresimage \"1\""
      echo "mat_stub \"1\""
      echo "mem_min_heapsize \"1\""
      echo "mem_max_heapsize \"16\""
    } >> "${ATF}"/pdl-${ACCT}/cfg/${ACCT//./}+.cfg
  fi

  # clean inventory (if desired) before load
  if ! hl2_pid > /dev/null; then
    if [[ "${1}${DROP_DETERGE}" = [1-9][0-9]* ]] \
    && [ -e .items-${ACCT}.pdl ]; then
      while [ ! -s .items-${ACCT}.pdl ]; do
        idler_sleep 0.5
      done
      ITEMS=$(cat .items-${ACCT}.pdl)
      ITEMS_SLOTS=$(echo "${ITEMS}" | grep -m1 _slots | grep -o [0-9]*)
      ITEMS_COUNT=$(echo "${ITEMS}" | grep original_id | wc -l)
      rm .items-${ACCT}.pdl
      if ((ITEMS_SLOTS-ITEMS_COUNT < DROP_DETERGE)); then
        idler_deterge
        run_node_login
      else
        tprint "${ACCT}: backpack has ${ITEMS_COUNT}/${ITEMS_SLOTS} items" \
          free=$((ITEMS_SLOTS-ITEMS_COUNT))_min=${DROP_DETERGE}
      fi
    fi

    # if no client, start for farm, remove pa entries, then connect
    idler_play "-threads 1 -nomouse -noshaderapi -noborder" || return 1
  fi
  if pgrep -x pulseaudio > /dev/null; then
    for PA in $(pacmd list-clients \
    | grep -A0 -B7 "process.id = \"\(${SPID}\|${HPID}\)\"" \
    | grep index: | awk '{print $2}'); do
      pacmd kill-client ${PA}
    done
  fi
  if [ ! -z ${PA} ]; then
    tprint "${ACCT}: removed pulseaudio client(s)" @$(pgrep pulseaudio)
  fi
  idler_connect || return 1

  # start node chatroom bot, check capabilities, then initiate farm helper
  if ! pgrep -fn sh\ pdl-idler_helper.sh > /dev/null; then
    tprint "starting helper..." \
      ${DROP_IRC:0:1}\|${DROP_CHAT:0:1}\|${DROP_SOUND:0:1}\|${DROP_SPEECH:0:1}
    if [ "${DROP_CHAT}" = no ]; then
      unset DROP_CHAT
    else
      DROP_CHAT=${ACCT}
      if ! is_node_login_available; then
        if [ $(node_login_background) != DROP ]; then
          tprint "error, node login occupied, drop chat disabled"
          unset DROP_CHAT
        fi
      elif ! prep_chat || ! prep_node_login yes "${OPTS}"; then
        tprint "${ACCT}: error, drop chat error"
        unset DROP_CHAT
      else
        prep_node_enter ${CHAT} ", 1"
        prep_node_http
        OPTS="steam.setPersonaState(Steam.EPersonaState.Away);"
        OPTS="${OPTS}\nexitBreak('DROP', 1);"
        sed -i -e "s/setTimeout(exit, 4444);/${OPTS}/g" ${NODEJS}
        if ! run_node_login > /dev/null; then
          tprint "${ACCT}: error, drop chat disabled for error or limited acct"
          unset DROP_CHAT
        fi
      fi
    fi
    if [ "${DROP_IRC}" != no ] && [ "${IRC_SERVER}" = none ]; then
      tprint "error, irc server disabled, drop irc disabled"
      unset DROP_IRC
    fi
    if [ "${DROP_SOUND}" = yes ] && ! which aplay > /dev/null 2>&1; then
      tprint "error, aplay not installed, drop sound disabled"
      unset DROP_SOUND
    fi
    if [ "${DROP_SPEECH}" = yes ] && ! which flite > /dev/null 2>&1; then
      tprint "error, flite not installed, drop speech disabled"
      unset DROP_SPEECH
    fi
    screen -dmS idler-helper$ bash pdl-idler_helper.sh \
      "${DROP_CHAT}" "${DROP_IRC}" "${DROP_SOUND}" "${DROP_SPEECH}"
  fi
}

# source user config file
if [ -e share/pdl-idler.conf ]; then
  source ./share/pdl-idler.conf
fi
ACCOUNTS_STRING="${ACCOUNTS}"
