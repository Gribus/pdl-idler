#!/bin/bash
# pdl-idler.sh (0.9026+)
# Copyright (c) 2011-2017 byteframe@primarydataloop

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
export WINEARCH=64
# check shell, then change pwd
if [ $(readlink "/proc/$$/exe" | sed "s/.*\///") != bash ]; then
  echo "warning, only bash is supported as the shell"
  exec bash ${0} $*
fi
cd "$( cd "$( dirname "$0" )" && pwd )"
DIR="${PWD}"

finish()
{
  # if no hl2/node processes, enable power management
  export DISPLAY=:0
  if ! pgrep -fn hl2\\.exe.*-nocrashdialog > /dev/null \
  && ! pgrep -fn ${NODE}\ share/ > /dev/null; then
    XFCE_PID=$(pgrep -fx xfce4-power-manager)
    if [ -e .xfce4pm.pdl ] && [ ! -z ${XFCE_PID} ]; then
      XFCE_AC=$(cat .xfce4pm.pdl)
      tprint "enabling xfce4-power-manager..." 0\>${XFCE_AC},@${XFCE_PID}
      set_xfce_power ${XFCE_AC}
      rm .xfce4pm.pdl
    fi
  fi

  # delete junk and wine temporary internet files
  if ! pgrep -fa sh\ .*pdl-idler.*\\.sh | grep -v pdl-idler_helper\\.sh \
  | grep -qv $$; then
    rmdir /tmp/dumps 2> /dev/null
    rm -f npm-debug.log .xdotool*.lock
    if ! pgrep -f wget.*GetPlayerItems > /dev/null; then
      rm -f .items-*.pdl
    fi
    if ! pgrep -fn steam\\.exe.*-noverifyfiles > /dev/null; then
      rm -fr wine/users/${USER}/"Local Settings/Temporary Internet Files"/* \
        wine/users/${USER}/"Local Settings/Application Data"/* \
        wine-*/drive_c/Steam/steamapps "${TF}"/con-*.log .vnc_passwd
    fi

    # if there are no steam processes, stop relevant X server(s)
    for X in $(pgrep -fal idler-X | grep -o \ :[0-9]*); do
      if ! pgrep -fn steam\\.exe.*_${X} > /dev/null; then
        VNC=$(pgrep -fn "vnc.*display ${X} ")
        if [ ! -z ${VNC} ]; then
          tprint "stopping x11vnc..." ${X},@${VNC}
          kill ${VNC}
        fi
        if pgrep -f idler-X${X:1} > /dev/null; then
          tprint "stopping X/Xvfb..." ${X},@$(xserver_pid ${X})
          kill $(xserver_pid ${X})
          while [ -e /tmp/.X${X:1}-lock ]; do
            idler_sleep 0.5
          done
        fi
      fi
    done
  fi

  # reset terminal attributes
  stty sane
  tput setf 9
  tput sgr0
}

sigint()
{
  # capture sigint to conditionally end, perform finishing operations, then exit
  trap - SIGINT
  if [ ! -z ${END_ECHO} ]; then
    echo
  fi
  tprint "cancelling script invocation..." ${ACTION},@$$
  if [ ! -z ${LOGIN} ] && steam_pid > /dev/null; then
    if window_id Login > /dev/null; then
      idler_logout
    elif window_id Create > /dev/null; then
      idler_delete yes
    else
      idler_logout yes
    fi
  fi
  finish
  exit 2
}

# print action description or usage text
PDLIDLER=${0##*/}
idler_help()
{
  local HELP=${1}
  if ! grep -q "^  \[ ${1}" HELP; then
    unset HELP
  fi
  if [ ! -z ${HELP} ]; then
    sed -n '/^  \[ '${HELP}'/,/^$/p' HELP | head -n-1
  else
    printf "\n${p}Usage: ${g}${PDLIDLER}${x} ${b}ACTION1${z}${m}{,/%%}${x}"
    echo "${b}ACTION2${z}${y}=arg^x\;y... ${l}{acct1 acct2/pw#email ...}${x}"
    echo -e "\n${u}ACTION{=ARGS}${v}\t ${u}DESCRIPTION {(default)parameters}${v}\n"
    for HELP in $(grep "^  \[ " HELP | awk '{print $2}'); do
      echo -e "${p}${HELP}${x}\t $(grep -m1 "  \[ ${HELP}" HELP \
        | grep -o "/.*" | sed -e s/\\//${b}/ -e s/{/${z}${l}{/)${z}"
    done
    echo
  fi
}

page_files()
{
  # view a set of files the less paper or another program in the background
  SAVEIFS=$IFS
  IFS=$'\n'
  for FILE in $@; do
    if [ -s ${FILE} ]; then
      if [ ${1} = _ ]; then
        less -K +G "${FILE}"
      else
        if [[ ${1} = _* ]]; then
          DISPLAY=:0 ${1:1} "${FILE}" &
        else
          DISPLAY=:0 ${1} "${FILE}"
        fi
        idler_sleep 0.5
      fi
    fi
  done
  IFS=${SAVEIFS}
}

idler_log()
{
  # page various output and config files
  PAGER="page_files _"
  if [[ ${1} = *:* ]]; then
    PAGER="page_files ${1%%:*}"
  fi
  if [ -z ${1} ] || [[ ${1} = *all* ]]; then
    LOG="tf-sv-app-boot-cloud-conn-content-library-parental-remote-stats-
      workshop-ccfg-lcfg-scfg-node"
  else
    LOG=$(echo ${1} | tr [:upper:] [:lower:])
  fi
  if [[ "${LOG}" = *sv* ]]; then
    LOG=${LOG//sv}
    for SRCDS in "${STF}"/pdl-*; do
      ${PAGER} "${SRCDS}"/console.log \
        "${SRCDS}"/addons/sourcemod/configs/sourceirc.cfg \
        "${SRCDS}"/cfg/sourcemod/irc-connected.cfg || return 1
    done
  fi
  if [[ "${LOG}" = *tf* ]]; then
    ${PAGER} ${CON} "${ATF}"/pdl-${ACCT}/cfg/${ACCT//./}+.cfg \
      "${ATF}"/pdl-${ACCT}/cfg/banned_ip.cfg \
      ${USERDATA}/440/remote/cfg/config.cfg || return 1
  fi
  for FILE in ${LOGS}/*_log.txt; do
    FILE=${FILE##*/}
    if [[ ${LOG} = *${FILE:0:4}* ]]; then
      ${PAGER} ${LOGS}/${FILE} || return 1
    fi
  done
  if [[ ${LOG} = *ccfg* ]]; then
    ${PAGER} ${CONFIG}/*.vdf || return 1
  fi
  if [[ ${LOG} = *lcfg* ]]; then
    ${PAGER} ${LCONFIG} || return 1
  fi
  if [[ ${LOG} = *scfg* ]]; then
    ${PAGER} ${USERDATA}/7/remote/sharedconfig.vdf || return 1
  fi
  if [[ ${LOG} = *node* ]] && [ -e ${NODELOG} ]; then
    ${PAGER} ${NODEJS} ${NODELOG} || return 1
  fi
}

idler_list()
{
  # print listing with item counts, steamid, connect hash, versions, and status
  unset ITEM
  LINE="${g}@${SUID/76561}${x} ${l}[$(steam_cellid)$(steam_connect_hash)]${x} ${u}$(
    account_size 2> /dev/null | sed -e :a -e 's/^.\{1,3\}$/0&/;ta')${v}"
  if [ -z ${SUID} ]; then
    LINE=${p}"-|${x} ${LINE} nonexistant |"
  else
    cache_backpack ${1} > /dev/null
    if [ -z "${WGET}" ]; then
      LINE=${p}'!|'"${x} ${LINE}"
    elif echo ${WGET} | grep -q pack\ is\ private; then
      LINE=${p}"?|${x} ${LINE}"
    else
      ITEM=$(echo ${WGET} | grep -o \[0-9][0-9]*/[0-9][0-9]* | sed "s/\/.*//")
      if [ -z ${ITEM} ]; then
        ITEM=0
      fi
      LINE=${p}${ITEM}\|${x}\ ${LINE}
    fi
    if ! steam_ui_version > /dev/null; then
      LINE="${LINE} uninstalled |"
    elif [ $(steam_ui_version) != $(steam_ui_cache_version) ]; then
      LINE="${LINE} <$(steam_ui_version) |"
    else
      LINE="${LINE} ^$(steam_ui_version) |"
    fi
  fi
  if ! steam_pid > /dev/null; then
    LINE="${LINE}--"
  else
    PERSONA=$(grep StateDesired\".*\"[1-9]\" ${LCONFIG} | grep -o \[1-9])
    if window_id Group\ Chat opacity -v > /dev/null; then
      LINE="${LINE}${m}C${x}-"
    elif [ ! -z ${PERSONA} ]; then
      LINE="${LINE}${m}${PERSONA}${x}-"
    else
      LINE="${LINE}${y}A${x}-"
    fi
    if hl2_pid > /dev/null; then
      if client_map > /dev/null; then
        LINE="${LINE:0:(-1)}${r}G${x}"
      elif client_connection > /dev/null; then
        LINE="${LINE:0:(-1)}${r}C${x}"
      else
        LINE="${LINE:0:(-1)}${y}S${x}"
      fi
    fi
  fi
  LINE="${LINE}-"
  if ! is_node_login_available; then
    if tac ${NODELOG} | grep -q BREAK_FAKE; then
      LINE="${LINE:0:(-1)}${p}F${x}"
    else
      LINE="${LINE:0:(-1)}${y}N${x}"
    fi
  fi
  print ${b}${ACCT}${z} "${LINE}   "
}

idler_backpack()
{
  # list account then detail backpack contents
  idler_list ${1} || return 1
  if [ -z "${WGET}" ]; then
    print "" "{website error}" 46
  elif [ -z ${ITEM} ]; then
    print "" "{backpack empty}" 46
  else
    for WORD in $(echo ${WGET} | sed -e "s/ /_/g" -e 's/<[^>]*>/ /g'); do
      if [ ${WORD} != \# ] && [ ${WORD} != " " ]; then
        if echo ${WORD} | grep -qi items; then
          QUALITY="${b}${y}"
          if [[ ${WORD} = Genuine_* ]]; then
            QUALITY=${g}G.
          elif [[ ${WORD} = Haunted_* ]]; then
            QUALITY=${m}H.
          elif [[ ${WORD} = Strange_* ]]; then
            QUALITY=${y}S.
          elif [[ ${WORD} = Vintage_* ]]; then
            QUALITY=${l}V.
          elif [[ ${WORD} = Unusual_* ]]; then
            QUALITY=${p}U.
          fi
        elif [[ ${WORD} = [0-9]* ]]; then
          print "" "${QUALITY}${NAME}${z}${x} (x${WORD})" 46
        elif [[ ${WORD} = *[a-zA-Z]* ]]; then
          NAME=$(echo ${WORD} | sed "s/_/ /g")
        fi
      fi
    done
    print "" {$(echo ${WGET} | grep -o \[0-9][0-9]*/[0-9][0-9]*)} 46
  fi
}

process_usage()
{
  # get cpu usage of specified process
  USAGE=$(echo "scale=1; ($(ps aux | grep -P ^.*?\ ${1}\ [0-9]*\.[0-9] \
    | grep -v grep | awk {'print $3*100'})/100)/$(nproc)" | bc)
  printf "%0.1f" ${USAGE}
}

steam_backend()
{
  # get backend connection status from specified log
  if tac "${1}" | grep -om 1 logged\ on\ =\ \[0-9] | grep -q 0; then
    echo 0
    return 1
  fi
  echo 1
}

# list then show system and process statistics
VERSION=$(grep -om1 \(.* pdl-idler.sh | grep -o "[0-9]*\.[0-9]*")
WINE=$(wine --version | awk '{print $1}' | sed s/wine-//)
idler_status()
{
  if [ -z ${ONCE} ]; then
    ONCE=yes
    if lsmod | grep -q "^vboxquest "; then
      VENDOR=80ee
      DEV=beef
    elif lsmod | grep -q "^vmxnet "; then
      VENDOR=15ad
      DEV=0405
    else
      VENDOR=1002
      DRIVER=$(lsmod | grep -om1 "^nvidia\|^nouveau\|^fglrx\|^radeon\|^i915")
      if [ -z ${DRIVER} ]; then
        DRIVER=vesafb
        VENDOR=10de
      elif [ ${DRIVER} = i915 ]; then
        VENDOR=8086
      fi
      DEV=$(grep ${DRIVER} /proc/bus/pci/devices | awk '{print $2}' | cut -c5-8)
    fi
    if [ -z $(find share/ -maxdepth 1 -name pci.ids -mtime -28) ]; then
      tprint "updating pci id list..." v2.2
      download pciids.sourceforge.net/v2.2/pci.ids share/pci.ids || exit 1
      touch share/pci.ids
    fi
    KIT=$(echo $(grep -m 1 model\ name /proc/cpuinfo)~$(cat share/pci.ids \
      | sed -ne /^${VENDOR}/,'$'p | grep -m 1 ${DEV}) \
      | sed -e "s/model name *://" -e "s/${DEV}//" -e "s/\\[//" -e "s/\\]//" \
      -e "s/\ //g" -e "s/([m-tM-T]*)//g" -e "s/@[0-9.]*//" \
      -e "s/CPU\|GHz\|Intel\|AMD \|Processor\|Dual-Core//g" \
      -e "s/Controller\|Adapter\|Device\|Chipset\|AMD\|NVIDIA\|Mobile//g" \
      -e "s/Express\|Integrated\|Graphics//g" -e "s/SVGA II/VMware &/")
    DOMAIN=$(dnsdomainname 2> /dev/null)
    if [ ! -z ${DOMAIN} ]; then
      DOMAIN=.${DOMAIN}
    fi
    print "${b}<${HOSTNAME}${DOMAIN}>${z}" "${b}dev: ${z}${g}${KIT}${x}" 46
    read Z A B C IDLE1 REST < /proc/stat
    PASS1=$((A+B+C+IDLE1))
    idler_sleep 1
    read Z A B C IDLE2 REST < /proc/stat
    PASS2=$((A+B+C+IDLE2))
    CPU=$((100*( (PASS2-PASS1) - (IDLE2-IDLE1) ) / (PASS2-PASS1) ))
    RAM=$(($(grep MemFree /proc/meminfo | awk '{print $2}')/1000))
    RAM=${RAM}/$(($(grep MemTotal /proc/meminfo | awk '{print $2}')/1000))
    SWP=$(free_swap)/$(($(grep SwapTotal /proc/meminfo | awk '{print $2}')/1000))
    DISTRO=$(echo $(cat /etc/*-release | grep ^NAME= | cut -c 6-)\ $(cat \
      /etc/*-release | grep ^VERSION= | awk '{print $1}' | cut -c 9-) \
      | sed -e s/\"//g -e s/,// -e s/\ $//)
    print "${p}[${DISTRO}]${x}" \
      "${b}sys:${z} ${g}CPU=${CPU}% RAM=${RAM} SWP=${SWP}${x}" 46
    print ${p}\<${USER}\>${x} "${b}net:${z} ${g}$(ip route get 8.8.8.8 \
      | awk '{print $5}' | cut -c 1-4) ($(net_address) >> $(\
      wget -qO- icanhazip.com))${x}" 46
    print "${p}\"${PDLIDLER} ${VERSION}\"${x}" "${b}run:${z}${g} proc{$(\
      ps ux | wc -l)}, load{$(uptime | grep -o average.*\
      | awk '{print $2,$3,$4}' | sed s/,\ /_/g)}, core{$(nproc)}${x}" 46
    print "${p}/helper: @$(pgrep -fn bash\ pdl-idler_helper || echo n/a)/${x}" \
      "${b}ver:${z} ${g}tf2=$(app_version 440), srcds=$(app_version 232250\
      ), wine=${WINE}${x}" 46
    t=$(tput cols)
    printf "%$((${t}-1))s\n" | tr ' ' -
    for X in $(pgrep -fl Xorg\|Xvfb | grep -vi screen | sort -k 2 \
    | awk '{print $1}'); do
      NUM=$(ps ${X} | grep -o \ :[0-9]* | grep -o [0-9]*)
      if xserver_pid :${NUM} > /dev/null; then
        STARTED=N
        if pgrep -fn "x11vnc.*display :${NUM} " > /dev/null; then
          STARTED=V
        elif pgrep -f idler-X${NUM} > /dev/null; then
          STARTED=Y
        fi
        XVFB=Xorg-HI_[${DRIVER}]
        if ps $(xserver_pid :${NUM}) | grep -q Xvfb; then
          XVFB="Xvfb-LO_[$(echo $(glxinfo -display :${NUM} 2> /dev/null \
            | grep -om1 LLVM\ [0-9.]* | sed -e s/LLVM\ /llvm-/))]"
          if [ ${XVFB} = Xvfb-LO_\[\] ]; then
            XVFB=Xvfb-LO_[null]
          fi
        fi
        print "${b}DISPLAY=:${NUM}${z}" "${g}($(process_usage\
          $(xserver_pid :${NUM}))%) @$(printf %05d $(xserver_pid :${NUM}\
          )) ${l}<${XVFB/_*}>${x} $(\
          memory $(xserver_pid :${NUM})) ${STARTED}=${XVFB/*_}" 46
      fi
    done
    for SRCDS in $(pgrep -fl cds_linux.*281 | sort -k 16 | awk '{print $1}'); do
      NUM=$(ps ${SRCDS} | grep -o port\ 281[0-9]* | grep -o [0-9]*)
      printf "%$((${t}-1))s\n" | tr ' ' -
      SERVER_VERSION=$(version $(grep -m 1 pdlv \
        "${STF}"/pdl-${HOSTNAME}-281${NUM:(-2)}/console.log | awk '{print $2}'))
      print "${b}(server:${NUM})" "srcds:${z} ${g}($(process_usage ${SRCDS}\
        )%) ${l}[${SERVER_VERSION}]${x} $(server_memory \
        ${NUM})${z} Players ${b}{$(server_playercount ${NUM})/$((IDLE_MAX+1))}${z}" 46
      print "" "${g}@$(printf %05d ${SRCDS}) ${l}$(item_schema \
        "${STF}"/pdl-${HOSTNAME}-${NUM}/console.log)${x} game=$(steam_backend \
        "${STF}"/pdl-${HOSTNAME}-${NUM}/console.log)" 39
    done
  fi
  printf "%$((${t}-1))s\n" | tr ' ' -
  idler_list ${1} || return 1
  if steam_pid > /dev/null; then
    LINE="${b}steam:${z} ${g}($(process_usage ${SPID})%) ${l}{lo_mode"
    if steam_pid _hi> /dev/null; then
      LINE="${LINE:0:(-7)}hi_mode"
    fi
    XPID=$(auxiliary_pid wineserver)
    print "${p}|ws: @$(printf %05d ${XPID}), ($(process_usage ${XPID}))|${x}" \
      "${LINE}}${x} $(steam_memory) @$(grep Rate ${CONFIG}/config.vdf \
      | grep -o \[0-9]*)kb" 46
    if auxiliary_pid explorer.exe > /dev/null; then
      XPID="|ex: @$(printf %05d ${XPID}), ($(process_usage ${XPID}))|"
    else
      XPID="|ex: n/a|"
    fi
    print "${p}${XPID}${g}" "@$(printf %05d ${SPID}) ${l}/#$(\
      sha1sum share/${ACCT}/ssfn | cut -c1-6)/${x} $(steam_auth_server)" 39
    if auxiliary_pid services.exe > /dev/null; then
      XPID="|sv: @$(printf %05d ${XPID}), ($(process_usage ${XPID}))|"
    else
      XPID="|sv: n/a|"
    fi
    print "${p}${XPID}${x}" "${g}\"$(echo $(steam_name))\"${x}" 39
    if hl2_pid > /dev/null; then
      print "" "--------------------------------------" 39
      LINE="${b}hl2:${z} ${g}($(process_usage ${HPID})%) ${l}(normalc"
      if hl2_pid noshaderapi > /dev/null; then
        LINE="${LINE:0:(-7)}noshade"
      fi
      print "" "${LINE})${x} $(hl2_memory) game=$(steam_backend ${CON})" 44
      print "" "${g}@$(printf %05d ${HPID}) ${l}|$(cat "${TF}"/pdl-${ACCT}/ver \
        2> /dev/null || echo none)| ${x}$(item_schema ${CON})" 39
      if client_map > /dev/null; then
        local MAP=\($(client_map)\)
      fi
      print "" "${MAP}${p}${CONNECTION/\|/\|${g}}${x}" 39
    fi
  fi
}

idler_utility()
{
  # run shell commands or execute steam urls if steam is running
  if [ -d wine-${ACCT} ]; then
    UTILITY=regedit
    if [ ! -z "${1}" ]; then
      UTILITY=${1}
      if steam_pid > /dev/null; then
        UTILITY=${1//steam\:/wine_run \"'${STEAM}'\"\/steam.exe steam\:}
      elif echo ${1} | grep -q steam\:; then
        tprint "${ACCT}: error, steam not running"
        return 1
      fi
    fi
    tprint "${ACCT}: running utility..."
    echo "${UTILITY//^/ }" > wine-${ACCT}/.utility.sh
    source wine-${ACCT}/.utility.sh > wine-${ACCT}/.utility.log 2>&1
  fi
}

idler_website()
{
  # open relevant website in the default browser
  if [ -z ${SUID} ]; then
    tprint "${ACCT}: error, not installed"
  else
    if [ "${1/.tf}" = backpack ]; then
      SITE=backpack.tf/id/${SUID}
    elif [ "${1/.com}" = tf2items ]; then
      SITE=tf2items.com/profiles/${SUID}
    elif [ "${1/.com}" = willitcraft ]; then
      SITE=willitcraft.com/'#!'${SUID}/
    elif [[ "${1/.com}" = stm_com* ]]; then
      if [[ ${1} = */* ]]; then
        SITE=${1#*/}
      fi
      SITE=steamcommunity.com/profiles/${SUID}/${SITE}
    elif [ "${1/.com}" = tf2b ]; then
      SITE=tf2b.com/tf2/${SUID}
    else
      SITE=steamcommunity.com/profiles/${SUID}/inventory/\#753
    fi
    tprint "${ACCT}: opening website..." $(echo ${SITE} | sed "s/\/.*//")
    DISPLAY=:0 xdg-open http://${SITE} 2> /dev/null
    if [ ${ACCT} = ${ACCOUNTS_ARRAY[1]%%/*} ]; then
      WEBSITE_DELAY=200
    fi
    let WEBSITE_DELAY+=25
    idler_sleep $(echo "scale=4;${WEBSITE_DELAY}/1000" | bc)
  fi
}

idler_create()
{
  # prompt and/or parse input for account creation then login
  if [ ! -z ${SUID} ]; then
    tprint "${ACCT}: error, account exists"
  elif [[ ${ACCT} = *steam* ]] || [[ ${ACCT} = *valve* ]]; then
    tprint "${ACCT}: error, invalid username"
  else
    CONFIRM=${PASS}
    if [ -z ${PASS} ]; then
      tprint "${ACCT}: input password:" "" "" 1
      read -s PASS
      echo
      tprint "${ACCT}: confirm password:" "" "" 1
      read -s CONFIRM
      echo
    fi
    if [ ${PASS} != "${CONFIRM}" ]; then
      tprint "${ACCT}: error, passwords don't match"
    else
      if [ -z ${EMAIL} ]; then
        tprint "${ACCT}: input email:" "" "" 1
        read -e EMAIL
      fi
      if check_account_input; then
        idler_login && return 0
      fi
    fi
  fi
  return 1
}

idler_offline()
{
  # set friend presense to offline
  if steam_pid > /dev/null && ! grep -q "\"ateDesired\".*\"0\"" ${LCONFIG}; then
    tprint "${ACCT}: signing off of friends..." $(both_memory)
    OFFLINE_TIMEOUT=0
    while ! grep -q "\"PersonaStateDesired\".*\"0\"" ${LCONFIG}; do
      if [ ${OFFLINE_TIMEOUT} = 8 ]; then
        OFFLINE_TIMEOUT=0
      fi
      if [ ${OFFLINE_TIMEOUT} = 0 ]; then
        wine_run C:/Steam/steam.exe steam://friends/status/offline
      fi
      let OFFLINE_TIMEOUT+=1
      idler_sleep 1
    done
  fi
}

idler_online()
{
  # set friend presense to online
  local ONLINE=1online
  if [ "${1}" = 2 ] || echo ${1} | grep -qi busy; then
    ONLINE=2busy
  elif [ "${1}" = 3 ] || echo ${1} | grep -qi away; then
    ONLINE=3away
  elif [ "${1}" = 5 ] || echo ${1} | grep -qi trade; then
    ONLINE=5trade
  elif [ "${1}" = 6 ] || echo ${1} | grep -qi play; then
    ONLINE=6play
  fi
  if steam_pid > /dev/null \
  && ! grep -q "\"PersonaStateDesired\".*\"${ONLINE:0:1}\"" ${LCONFIG}; then
    tprint "${ACCT}: changing persona status..." ${ONLINE:1},$(both_memory)
    if [ ${ONLINE} != 1online ] && grep -q "\"Desired\".*\"0\"" ${LCONFIG}; then
      idler_online > /dev/null
    fi
    ONLINE_TIMEOUT=0
    while ! grep -q "\"PersonaStateDesired\".*\"${ONLINE:0:1}\"" ${LCONFIG}; do
      if [ ${ONLINE_TIMEOUT} = 8 ]; then
        ONLINE_TIMEOUT=0
      fi
      if [ ${ONLINE_TIMEOUT} = 0 ]; then
        wine_run C:/Steam/steam.exe steam://friends/status/${ONLINE:1}
      fi
      let ONLINE_TIMEOUT+=1
      idler_sleep 1
    done
  fi
}

idler_enter()
{
  # join chatroom and mark persona status or lurk with node if not logged in
  prep_chat ${1}
  if steam_pid > /dev/null; then
    if ! window_id Group\ Chat > /dev/null; then
      tprint "${ACCT}: entering chat..." \#${CHAT},$(both_memory)
      if grep -q "\"PersonaStateDesired\".*\"0\"" ${LCONFIG}; then
        rm -f wine-${ACCT}/.friends.pdl
      else
        touch wine-${ACCT}/.friends.pdl
      fi
      ENTER_TIMEOUT=0
      while ! window_id Group\ Chat > /dev/null; do
        if [ ${ENTER_TIMEOUT} = 8 ]; then
          ENTER_TIMEOUT=0
        fi
        if [ ${ENTER_TIMEOUT} = 0 ]; then
          wine_run C:/Steam/steam.exe steam://friends/joinchat/${CHAT}
        fi
        if window_id Open\ Chat > /dev/null; then
          tprint "${ACCT}: error, chat unavailable on limited account"
          close_window $(window_id Open\ Chat) no no
          return 1
        fi
        let ENTER_TIMEOUT+=1
        idler_sleep 1
      done
    fi
  else
    if is_node_login_available; then
      prep_node_login yes "${OPTS}" || return 1
      prep_node_enter ${CHAT} ", 1"
      prep_node_http
      OPTS="steam.setPersonaState(Steam.EPersonaState.Snooze);"
      OPTS="${OPTS}\nexitBreak('ENTER', 1);"
      sed -i -e "s/setTimeout(exit, 4444);/${OPTS}/g" ${NODEJS}
      cat << EOF >> ${NODEJS}
      steam.on('chatMsg', function(chatid, msg, type, user) {
        http_opt.path = '/ISteamUser/GetPlayerSummaries/v0002/'
          + '?key=${APIKEY}&steamids=' + user;
        http.get(http_opt, function(response) {
          var output = '';
          response.on('data', function(chunk) {
            output += chunk;
          });
          response.on('end', function() {
            console.error(
              JSON.parse(output).response.players[0].personaname + ': ' + msg);
          });
        });
      });
      steam.on('chatStateChange', function(change, user, chatid, kicker) {
        http_opt.path = '/ISteamUser/GetPlayerSummaries/v0002/'
          + '?key=${APIKEY}&steamids=' + user;
        http.get(http_opt, function(response) {
          var output = '';
          response.on('data', function(chunk) {
            output += chunk;
          });
          response.on('end', function() {
            var name = JSON.parse(output).response.players[0].personaname;
            if (change == 1) {
              console.error(name + ' entered chat.');
            } else if (change == 2) {
              console.error(name + ' left chat.');
            } else if (change == 4) {
              console.error(name + ' disconnected.');
            } else if (change == 8) {
              console.error(name + ' was kicked by ' + kicker + '.');
            } else if (change == 10) {
              console.error(name + ' was banned by ' + kicker + '.');
            }
          });
        });
      });
EOF
      run_node_login
    elif ! tac ${NODELOG} | grep -q BREAK_ENTER; then
      tprint "${ACCT}: error, node login in use"
    fi
  fi
}

idler_exit()
{
  # leave public chatroom then restore prior friends status or end node lurker
  if window_id Group\ Chat > /dev/null; then
    tprint "${ACCT}: exiting chatroom..." $(both_memory)
    close_window $(window_id Group\ Chat)
    if [ ! -e wine-${ACCT}/.friends.pdl ]; then
      idler_offline
    fi
  fi
  if ! is_node_login_available \
  && tac ${NODELOG} | grep -q BREAK_ENTER; then
    stop_node_login
  fi
}

is_friend()
{
  # check if this account is friends via the community id or uid if using node
  OPTS="http://api.steampowered.com/ISteamUser/GetFriendList/v0001/"
  OPTS="${OPTS}?key=${APIKEY}&steamid=$(steam_uid ${1})&relationship=friend"
  if ! wget -qO- "${OPTS}" | grep -q ${SUID}; then
    return 1
  fi
}

invite_friend()
{
  # send friend invite with steam client or node login
  if [ ! -z ${2} ]; then
    if [ -d "${PWD}"/wine-${2} ] || steam_uid ${2} > /dev/null; then
      set_account ${2}
    else
      tprint "error, unknown account specified as friend inviter" ${2}
      return 1
    fi
  fi
  if steam_pid > /dev/null; then
    idler_sleep 8
    wine_run C:/Steam/steam.exe steam://friends/add/$(steam_uid ${1})
    FRIEND_TIMEOUT=0
    while ! window_id Friends\ -\ > /dev/null; do
      idler_sleep 1
      let FRIEND_TIMEOUT+=1
      if [ ${FRIEND_TIMEOUT} = 3 ]; then
        break
      fi
    done
    if window_id Friends\ -\ > /dev/null; then
      close_window $(window_id Friends\ -) no
    fi
  else
    prep_node_login yes || return 1
    OPTS="steam.addFriend('$(steam_uid ${1})');"
    OPTS="${OPTS}\nsetTimeout(function() { setTimeout(exit, 4444); }, 2500);"
    sed -i -e "s/setTimeout(exit, 4444);/${OPTS}/g" ${NODEJS}
    run_node_login > /dev/null
  fi
  if [ ! -z ${2} ]; then
    set_account ${OLD_ACCT}
  fi
}

idler_friend()
{
  # send/queue invites between initiated accounts or send one to a uid
  FRIEND="${ACCOUNTS}"
  if [ ! -z ${1} ]; then
    FRIEND=$(echo ${1} | tr [:upper:] [:lower:] | sed s/-/\ /g)
    for ADD in ${FRIEND}; do
      if [[ ${FRIEND} = *\+[0-9]* ]]; then
        FRIEND=${FRIEND/${ADD}/${ACCOUNTS_ARRAY[${FRIEND:1}]}}
      fi
    done
  fi
  unset QUEUED
  for ADD in ${FRIEND}; do
    ADD=${ADD%%\/*}
    if [[ ${ADD} = 765611* ]]; then
      if ! is_friend ${ADD}; then
        if is_node_login_available; then
          tprint "${ACCT}: node invite to uid..." ${ADD}
          invite_friend ${ADD}
        elif steam_pid > /dev/null; then
          tprint "${ACCT}: invite to uid..." ${ADD}
          invite_friend ${ADD}
        else
          tprint "${ACCT}: error, steam offline and node client in use" \
            ${ACCT}\>${ADD:6}
        fi
      fi
    else
      if [ ${ADD} != ${ACCT} ] && [ -e share/${ADD}/ssfn ] \
      && ! is_friend ${ADD}; then
        DATE=$(date +%s)
        if ! steam_pid > /dev/null && ! steam_pid "" ${ADD}; then
          if is_node_login_available && is_node_login_available ${ADD}; then
            tprint "sending/receiving node invite..." ${ACCT}\>\<${ADD}
            invite_friend ${ADD}
            invite_friend ${ACCT} ${ADD}
          else
            tprint "${ACCT}: error, node client(s) in use" ${ACCT}\>\<${ADD}
          fi
        elif steam_pid > /dev/null && steam_pid "" ${ADD}; then
          tprint "sending/receiving invite..." ${ACCT}\>\<${ADD}
          invite_friend ${ADD}
          invite_friend ${ACCT} ${ADD}
        elif ! steam_pid "" ${ADD}; then
          if is_node_login_available ${ADD}; then
            tprint "${ACCT}: response from node invite..." ${ADD}
            invite_friend ${ACCT} ${ADD}
            invite_friend ${ADD}
          else
            tprint "${ACCT}: error, node client in use" ${ADD}
          fi
        else
          if is_node_login_available; then
            tprint "${ACCT}: node invite with response..." ${ADD}
            invite_friend ${ADD}
            invite_friend ${ACCT} ${ADD}
          else
            tprint "${ACCT}: error, node client in use" ${ACCT}
          fi
        fi
      fi
    fi
  done
}

idler_register()
{
  # use steam ui to prompt for a email confirmation request
  idler_login || return 1
  tprint "${ACCT}: requesting confirmation e-mail..." $(steam_memory)
  wine_run C:/Steam/steam.exe steam://settings/account
  while ! window_id Settings bitmap\ id > /dev/null; do
    idler_sleep 0.5
  done
  mouse_click ${WID} 250 160
  local REGISTER_TIMEOUT=0
  while ! window_id Verify\ Email > /dev/null; do
    idler_sleep 0.3
    let REGISTER_TIMEOUT+=1
    if [ ${REGISTER_TIMEOUT} = 20 ]; then
      tprint "error, register error/failure"
      break
    fi
  done
  if [ ${REGISTER_TIMEOUT} = 20 ]; then
    return 1
  else
    key_press "" Return 3000
    key_press "" Escape 500
  fi
  close_window $(window_id Settings)
}

cache_backpack()
{
  # download player item data
  unset WGET ATTEMPTS
  while [ "${ATTEMPTS}" != 4 ] && [ -z "${WGET}" ]; do
    if [ "${1}" != no ]; then
      WGET=$(find -L share/${ACCT}/ -maxdepth 1 -name tf2b -mmin -5)
      if [ "${1}" = yes ] || [ -z ${WGET} ]; then
        download tf2b.com/tf2/txt/${SUID} \
          "${PWD}"/share/${ACCT}/tf2b > /dev/null 2>&1
      fi
    fi
    WGET=$(cat share/${ACCT}/tf2b 2> /dev/null)
    if [[ "${WGET}" != *Total\ ite* ]] && [[ "${WGET}" != *is\ private* ]] \
    && [[ "${WGET}" != *body\>?\</body* ]]; then
      unset WGET
      rm -f cat share/${ACCT}/tf2b
      let ATTEMPTS+=1
    fi
  done
  echo ${WGET}
}

open_url()
{
  # open steam component/url or other page in the client ui then wait/adjust
  STEAM_WID=$(window_id Steam)
  if [[ ${1} = steam:* ]]; then
    wine_run C:/Steam/steam.exe ${1}
  else
    wine_run C:/Steam/steam.exe steam://open/console
  fi
  idler_sleep 1
  if [[ ${1} != steam:* ]]; then
    type_input ${STEAM_WID} "open ${1}" 250 yes
    key_press ${STEAM_WID} Return
  fi
  idler_sleep 4
  if [[ ${1} != steam://open* ]]; then
    key_press ${STEAM_WID} "Home Left Left Left Left"
  fi
}

idler_exhibit()
{
  # unlock bp privacy and open up comments
  local EXHIBIT=ic
  if [ ! -z ${1} ]; then
    if [[ ${1} = *i* ]] || [[ ${1} = *c* ]]; then
      EXHIBIT=${1//[!ic]/}
    else
      tprint "${ACCT}: error, invalid exhibit flag" ${1}
    fi
  fi
  local KEYS=Tab
  if [[ ${EXHIBIT} = *c* ]]; then
    OPTS="http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/"
    OPTS="${OPTS}?key=${APIKEY}&steamids=${SUID}"
    if [ "$(wget -qO- "${OPTS}" | grep mentpermission | grep -o 1)" != 1 ]; then
      KEYS="Down Down ${KEYS}"
    else
      EXHIBIT=${EXHIBIT//c/}
    fi
  fi
  if [[ ${EXHIBIT} = *i* ]]; then
    OPTS="http://api.steampowered.com/IEconItems_440/GetPlayerItems/v0001/"
    OPTS="${OPTS}?SteamID=${SUID}&key=${APIKEY}"
    if ! wget -qO- "${OPTS}" | grep -q \"status\":\ 1, \
    || cache_backpack | grep -q pack\ is\ private; then
      KEYS="${KEYS} Down Down Tab Tab Down"
    else
      EXHIBIT=${EXHIBIT//i/}
    fi
  fi
  if [[ ${KEYS} = *Down* ]]; then
    idler_login || return 1
    tprint "${ACCT}: relaxing profile privacy..." flag=${EXHIBIT}
    while [ 1 ]; do
      open_url steam://url/SteamIDEditSettingsPage
      key_press ${STEAM_WID} "Tab Tab Tab Tab Down Down Tab ${KEYS} Return"
      idler_sleep 2
      if ! window_id Valve > /dev/null && ! window_id Agreemen > /dev/null; then
        break
      fi
    done
  fi
}

check_badge_task()
{
  # download and/or check community badge task completion
  if [ -z ${1} ]; then
    unset TASKS
  fi
  if [ -z ${1} ] || [[ "${TASKS}" = *${1}* ]]; then
    if [[ "${TASKS}" = *${1}* ]]; then
      idler_sleep 3
    fi
    download http://steamcommunity.com/profiles/${SUID}/badges/2 \
      share/${ACCT}/badges || exit 1
  fi
  if [ ! -z ${1} ] && [ -z ${2} ] \
  && ! grep -q ${1}_on share/${ACCT}/badges; then
    TASKS=${TASKS},${1}
    return 1
  fi
}

check_obtainable_badge_tasks()
{
  # check for an obtainable badge task
  if cat share/${ACCT}/badges | grep -v Facebook | grep -v OnMarket \
  | grep -v InOverlay | grep -v PostVideo | grep -v Trade \
  | grep -v CraftGameBadge | grep -v ${ICON_TASK} | grep -q _off.png; then
    return 1
  fi
  return 0
}

random_word()
{
  # generate random dictionary word
  local WORD
  while (( ${#WORD} < 6 )); do
    WORD=$(cat -n /usr/share/dict/words | grep -w $(shuf -i 1-$(\
      cat /usr/share/dict/words | wc -l) -n 1) | cut -f2)
  done
  echo ${WORD}
}

idler_socialize()
{
  # check for sale event or obtainable badge objective
  if (($(date +%s) < 1434931200)); then
    SALE=yes
  fi
  unset INCOMPLETE BADGE_INIT TASKS
  if [ -e share/${ACCT}/badges ] \
  && ! grep -q "</body>" share/${ACCT}/badges 2> /dev/null; then
    rm -f share/${ACCT}/badges
    local BODY=X
  fi
  if [ ! -e share/${ACCT}/badges ]; then
    BADGE_INIT=yes
    check_badge_task
  fi
  ICON_TASK=UseEmoticonInChat
  if ! check_badge_task UseEmoticonInChat no; then
    ICON=http://steamcommunity.com/profiles/${SUID}/inventory/json/753/6
    ICON=$(wget -q ${ICON} -O- \
      | grep -oi -m1 \"name\":\":[[:graph:]]*:\",\"market_hash)
    if [ ! -z ${ICON} ]; then
      ICON_TASK=NoEmoticonInChat
    fi
  fi
  if ! check_obtainable_badge_tasks && [ -z ${BADGE_INIT} ]; then
    check_badge_task
  fi
  TOTAL=$((26-$(grep _off share/${ACCT}/badges | wc -l)))

  # login, go online, initialize, resize window, then remove search/email
  if [ ! -z ${SALE} ] || ! check_obtainable_badge_tasks; then
    idler_login || return 1
    idler_online
    open_url steam://url/SteamIDEditPage
    xdotool windowsize --sync ${STEAM_WID} 900 600
    idler_sleep 1
    mouse_click ${STEAM_WID} 865 110 2
    mouse_click ${STEAM_WID} 850 125 2
  fi

  # start tf2 fake if needed and if node is installed
  if ! check_obtainable_badge_tasks; then
    tprint "${ACCT}: completing objectives... ${BODY}" "" "" 1
    if ! check_badge_task PlayGame; then
      printf p
      idler_stop
      idler_fake
      run_node_login > /dev/null
      local FAKED=yes
    fi

    # set profile attributes
    while ! check_badge_task SetupCommunityRealName; do
      printf n
      key_press ${STEAM_WID} "Tab Tab Tab Tab Tab"
      type_input ${STEAM_WID} $(random_word)
      key_press ${STEAM_WID} "Shift+Tab Shift+Tab Shift+Tab Shift+Tab Shift+Tab Shift+Tab \
        Shift+Tab Shift+Tab Shift+Tab Shift+Tab Shift+Tab Shift+Tab Return"
    done

    # post a status notice then rate it positively
    while ! check_badge_task PostStatusToFriends \
    || ! check_badge_task RateUpContentInActivityFeed; do
      printf v
      open_url steam://url/SteamIDControlPage
      mouse_click ${STEAM_WID} 200 200 2 1 300 "key Home"
      type_input ${STEAM_WID} $(random_word)\ $(random_word)
      mouse_click ${STEAM_WID} 625 235 2
      idler_sleep 3
      key_press ${STEAM_WID} "Tab Tab Tab Tab Return"
      idler_sleep 5
      mouse_click ${STEAM_WID} 50 315 2
    done

    # join a group
    while ! check_badge_task JoinGroup; do
      printf g
      open_url steam://url/GroupSteamIdPage/103582791435720285
      key_press ${STEAM_WID} "Tab Return"
    done

    # if able, provide a friends-only recommendation for tf2
    if ! check_badge_task RecommendGame; then
      if idler_enter 103582791435720285 > /dev/null; then
        idler_exit > /dev/null
        printf r
        while ! check_badge_task RecommendGame; do
          open_url steam://url/RecommendGame/440
          mouse_click ${STEAM_WID} 250 400 2
          type_input ${STEAM_WID} $(random_word)\ $(random_word)
          key_press ${STEAM_WID} \
            "Tab Tab Return Down Down Return Tab Tab Return Tab Tab Return"
        done
      else
        printf R
        INCOMPLETE=${INCOMPLETE}R
      fi
    fi

    # add application to the wishlist
    while ! check_badge_task AddItemToWishlist; do
      printf i
      open_url steam://url/StoreRecommendationsPage
      key_press ${STEAM_WID} "Tab Tab Tab Tab Tab Tab Tab Tab Tab Return"
    done

    # send and recieve a friend request
    if ! check_badge_task AddFriendToFriendsList; then
      if [ ! -z ${1} ]; then
        printf f
        idler_friend ${1} > /dev/null
      elif [[ ${INCOMPLETE} != *R* ]]; then
        printf f
        unset SOCIALIZE_TIMEOUT
        BOTSTF=(76561198100287118 76561198100255457 76561198100313270)
        while ! window_id Bots.tf > /dev/null; do
          wine_run C:/Steam/steam.exe \
            steam://friends/add/${BOTSTF[$(shuf -i 0-2 -n 1)]}
          let SOCIALIZE_TIMEOUT+=1
          if [ ${SOCIALIZE_TIMEOUT} = 3 ]; then
            printf X
            INCOMPLETE=${INCOMPLETE}F
            break
          fi
        done
        close_window $(window_id Bots.tf)
        if window_id Friends\ -\ ; then
          close_window $(window_id Friends\ -)
        fi
      else
        printf F
        INCOMPLETE=${INCOMPLETE}F
      fi
    fi

    # post a comment on own profile page
    while ! check_badge_task PostCommentOnFriendsPage; do
      printf c
      open_url steam://url/SteamIDPage/${SUID}
      key_press ${STEAM_WID} Ctrl+F
      type_input ${STEAM_WID} "dd a comm"
      mouse_click ${STEAM_WID} 100 200
      key_press ${STEAM_WID} End
      mouse_click ${STEAM_WID} 850 128 3 1 300
      mouse_click ${STEAM_WID} 100 200
      key_press ${STEAM_WID} Ctrl+F
      type_input ${STEAM_WID} "dd a comm"
      mouse_click ${STEAM_WID} 200 315 2 1 300
      type_input ${STEAM_WID} $(random_word)\ $(random_word)
      mouse_click ${STEAM_WID} 600 350
    done

    # upload a screenshot then comment on it
    if ! check_badge_task PostScreenshot; then
      printf s
      open_url steam://open/screenshots
      mouse_click $(window_id Uploader) 50 100 1
      mouse_click ${WID} 660 385 2
      SOCIALIZE_TIMEOUT=0
      while ! window_id Uploading > /dev/null; do
        if [ ${SOCIALIZE_TIMEOUT} = 3 ]; then
          SOCIALIZE_TIMEOUT=0
        fi
        if [ ${SOCIALIZE_TIMEOUT} = 0 ]; then
          mouse_click ${WID} 455 385
          mouse_click ${WID} 555 385
        fi
        let SOCIALIZE_TIMEOUT+=1
        idler_sleep 1
      done
      while window_id Uploading > /dev/null; do
        idler_sleep 1
      done
      close_window $(window_id Uploader)
    fi
    if ! check_badge_task PostCommentOnFriendsScreenshot; then
      if [[ ${INCOMPLETE} != *R* ]]; then
        printf z
        while ! check_badge_task PostCommentOnFriendsScreenshot; do
          open_url steam://url/CommunityScreenshots
          mouse_click ${STEAM_WID} 200 400
          idler_sleep 6
          key_press ${STEAM_WID} "Tab Tab Tab Tab Tab Tab"
          type_input ${STEAM_WID} $(random_word)
          key_press ${STEAM_WID} Tab
          mouse_click ${STEAM_WID} 775 330
          idler_sleep 3
          if window_id Formatting > /dev/null; then
            printf \*
            close_window $(window_id Formatting)
            mouse_click ${STEAM_WID} 1015 400 1
            idler_sleep 3
          fi
        done
      else
        printf Z
        INCOMPLETE=${INCOMPLETE}Z
      fi
    fi

    # if an emoticon is possessed, use it in a chatroom
    if [ ! -z ${ICON} ]; then
      while ! check_badge_task UseEmoticonInChat; do
        printf e
        idler_enter > /dev/null
        mouse_click $(window_id Group\ Chat) 100 300
        type_input ${STEAM_WID} $(echo ${ICON:8} | sed "s/\",.*//")
        key_press ${STEAM_WID} Return
        idler_exit
      done
    fi

    # post in a recent discussion thread on tf2
    if ! check_badge_task PostInDiscussions; then
      if [[ ${INCOMPLETE} != *R* ]]; then
        printf d
        unset SOCIALIZE_TIMEOUT
        while ! check_badge_task PostInDiscussions; do
          open_url steam://url/GameHubDiscussions/440
          key_press ${STEAM_WID} Page_Down
          mouse_click ${STEAM_WID} 100 $(shuf -i 150-500 -n 1)
          idler_sleep 5
          key_press ${STEAM_WID} End
          key_press ${STEAM_WID} Ctrl+F
          type_input ${STEAM_WID} "type you"
          key_press ${STEAM_WID} Escape
          mouse_click ${STEAM_WID} 150 325
          type_input ${STEAM_WID} $(random_word)\ $(random_word)\ $(random_word)
          mouse_click ${STEAM_WID} 550 400
          idler_sleep 3
          key_press ${STEAM_WID} "End Page_Up"
          mouse_click ${STEAM_WID} 500 435
          mouse_click ${STEAM_WID} 600 435
          idler_sleep 1
          mouse_click ${STEAM_WID} 250 380
          let SOCIALIZE_TIMEOUT+=1
          if [ ${SOCIALIZE_TIMEOUT} = 5 ]; then
            printf X
            INCOMPLETE=${INCOMPLETE}D
            break
          fi
        done
      else
        printf D
        INCOMPLETE=${INCOMPLETE}D
      fi
    fi

    # rate up a recent piece of tf2 workshop content
    X=(100 300 500)
    Y=(200 500)
    if ! check_badge_task RateWorkshopItem; then
      if [[ ${INCOMPLETE} != *R* ]]; then
        printf w
        while ! check_badge_task RateWorkshopItem; do
          open_url steam://url/SteamWorkshopPage/440
          key_press ${STEAM_WID} Page_Down
          mouse_click ${STEAM_WID} ${X[$(shuf -i 0-2 -n 1)]} \
            ${Y[$(shuf -i 0-1 -n 1)]}
          idler_sleep 4
          key_press ${STEAM_WID} Ctrl+F
          type_input ${STEAM_WID} "Add to coll"
          key_press ${STEAM_WID} Escape 
          mouse_click ${STEAM_WID} 500 420
          key_press ${STEAM_WID} Left Left Left Left Left Left
          mouse_click ${STEAM_WID} 50 420
        done
      else
        printf W
        INCOMPLETE=${INCOMPLETE}W
      fi
    fi

    # subscribe to a capable workshop item
    if ! check_badge_task SubscribeToWorkshopItem; then
      printf h
      WORKSHOP=(272283552 280373247 291105804 294781969)
      while ! check_badge_task SubscribeToWorkshopItem; do
        open_url steam://url/CommunityFilePage/${WORKSHOP[$(shuf -i 0-3 -n 1)]}
        key_press ${STEAM_WID} Ctrl+F
        type_input ${STEAM_WID} "Subscribe to"
        key_press ${STEAM_WID} Escape
        mouse_click ${STEAM_WID} 555 315 2
        idler_sleep 3
      done
    fi

    # vote on a greenlight title
    if ! check_badge_task VoteOnGreenlight; then
      if [[ ${INCOMPLETE} != *R* ]]; then
        printf l
        while ! check_badge_task VoteOnGreenlight; do
          open_url steam://url/CommunityFilePage/262075165
          key_press ${STEAM_WID} "Page_Down Page_Down"
          mouse_click ${STEAM_WID} 50 225
        done
      else
        printf L
        INCOMPLETE=${INCOMPLETE}L
      fi
    fi

    # show uncompletable objectives
    wine_run C:/Steam/steam.exe steam://url/SteamIDBadgePage
    printf =\(${TOTAL}\>$((26-$(grep _off share/${ACCT}/badges | wc -l)))\)
    echo
    if [ ! -z ${INCOMPLETE} ]; then
      local DELETE=yes
    fi
    for TASK in EUseEmoticonInChat BCraftGameBadge TTrade AFacebook OInOverlay \
    MOnMarket YPostVideo; do
      if ! check_badge_task ${TASK:1}; then
        INCOMPLETE=${INCOMPLETE}${TASK:0:1}
      fi
    done
    if [ ! -z ${INCOMPLETE} ]; then
      tprint "${ACCT}: incompletable objectives remain" ${INCOMPLETE}_\($((\
        26-$(grep _off share/${ACCT}/badges | wc -l)))\)
    fi
    if [ ! -z ${DELETE} ]; then
      rm share/${ACCT}/badges
    fi
  fi

  # reset window size and finish
  xdotool windowsize --sync ${STEAM_WID} 1153 677
  if [ ! -z ${FAKED} ]; then
    idler_stop
  fi
}

idler_discover()
{
  # login and/or click through store discovery queue XXX
  DISCOVER_CYCLES=28
  if [ ! -z ${1} ]; then
    DISCOVER_CYCLES=${1}
  fi
  idler_login || return 1

  # open store, resize window, and attempt to turn off auto play
  tprint "${ACCT}: started discovery queue"
  open_url steam://store/463150
  key_press ${STEAM_WID} Page_Down
  mouse_click ${STEAM_WID} 570 420
  mouse_click ${STEAM_WID} 573 424
  sleep 2.6
  #open_url steam://url/StoreExploreStart
  #xdotool windowsize --sync ${STEAM_WID} 1024 743
  #xdotool windowmove --sync ${STEAM_WID} 0 25

return 0
  # scroll to bottom, and click on either next in queue
  for CYCLE in $(seq 1 ${DISCOVER_CYCLES}); do
    key_press ${STEAM_WID} End
    mouse_click ${STEAM_WID} 500 330
    mouse_click ${STEAM_WID} 600 190
    idler_sleep 1
    key_press ${STEAM_WID} Home
    mouse_click ${STEAM_WID} 730 380

    # scroll to top, click on next queue, down once, then click on next item

    mouse_click ${STEAM_WID} 575 615
    xdotool click 5
    #idler_sleep 1
    mouse_click ${STEAM_WID} 900 679
# VIEW QUEUE>>
    mouse_click ${STEAM_WID} 900 642

    # if [ $((CYCLE%2)) = 0 ]; then
    #  mouse_click ${STEAM_WID} 545 555
    #  key_press ${STEAM_WID} 1
    #  mouse_click ${STEAM_WID} 600 555 2
    #fi
    ### just click next in queue woot

    # click on create queue location, then on review/store back
    #### 593>>600
    #mouse_click` ${STEAM_WID} 925 155
    #mouse_click ${STEA`M_WID} 725 380
    # scroll down once, then click on next button

    # on every odd cycle, scroll to the end and click on nsfw/review location
    #if [ $((CYCLE%2)) = 1 ]; then
    #  mouse_click ${STEAM_WID} 450 225
    #fi

    # abort account if window is closed
    if [ $(echo $((16#${STEAM_WID:2}))) != $(xdotool getwindowfocus) ]; then
      tprint "${ACCT}: warning, lost window, skipping account"
      break
    fi
  done
  tprint "${ACCT}: finished discovery queue"
  wine_run C:/Steam/steam.exe steam://url/CommunityInventory
}

check_offer_input()
{
  # prompt for and/or process item transfer offer input string
  unset TRADE_LOCAL
  if [ -z ${RECEIVER} ]; then
    OFFER=${1}
    if [ ! -z ${OFFER} ] && [[ ${OFFER} != *@* ]]; then
      OFFER=${OFFER}@
    fi
    while [ -z ${RECEIVER} ]; do
      if [[ ${OFFER} = +[0-9]* ]]; then
        OFFER=${OFFER/${OFFER%%@*}/${ACCOUNTS_ARRAY[${OFFER%%@*}]%%/*}}
      fi
      if [ -z ${OFFER} ] || [[ ${OFFER} = @* ]]; then
        tprint "input receiver account/uid: " "" "" 1
        read -e OPTS
        OFFER=${OPTS//@}${OFFER}
      else
        RECEIVER=${OFFER%@*}
      fi
    done
    if [ ${RECEIVER} = ${ACCT} ]; then
      tprint "${ACCT}: error, receiver specified as trader"
      return 1
    elif [[ ${RECEIVER} != 765611* ]] && ! steam_uid ${RECEIVER%/*} > /dev/null; then
      tprint "error, invalid receiver uid/account" ${RECEIVER}
      return 2
    else
      if steam_pid "" ${RECEIVER} > /dev/null \
      && ! grep -q "\"PersonaStateDesired\".*\"0\"" \
      share/${RECEIVER}/userdata/*/config/localconfig.vdf; then
        TRADE_LOCAL=yes
        RECEIVER=$(steam_uid ${RECEIVER})
      fi
      OFFER=${OFFER##*@}
      unset NOSC NOSG
      if [[ ${OFFER} = *nosc* ]]; then
        OFFER=${OFFER/nosc}
        NOSC=yes
      fi
      if [[ ${OFFER} = *nosg* ]]; then
        OFFER=${OFFER/nosg}
        NOSG=yes
      fi
      if [ -z ${OFFER} ]; then
        OFFER=_all_-crates
      elif [ ${OFFER:0:1} != _ ]; then
        OFFER=_${OFFER}
      fi
      OFFER=${OFFER//-crates/-${CRATES//,/_-}}
      OFFER=${OFFER//crates/${CRATES//,/_}}
      if [[ ${OFFER} = *all* ]]; then
        OFFER="'"$(echo ${OFFER} | sed -e "s/all//" -e "s/_[0-9][0-9]*//g" \
          -e "s/_-/,/g" -e "s/^[_,]*//" -e "s/,/','/g")"'"
        OFFER="return ([${OFFER}].indexOf(item.app_data.def_index) == -1)"
      else
        OFFER="'"$(echo ${OFFER} | sed -e "s/_-[0-9][0-9]*//g" \
          -e "s/_/,/g" -e "s/^[_,]*//" -e "s/,/','/g")"'"
        OFFER="return ([${OFFER}].indexOf(item.app_data.def_index) != -1)"
      fi
      OFFER="${OFFER} \&\& item.tradable;"
    fi
  fi
}

prep_node_trade()
{
  # wait for trade web cookies/session id and common trade conditions
  install_node_module git://github.com/seishun/node-steam-trade.git 0.2.4
  if ! grep -q var\ SteamTrade ${NODEJS}; then
    OPTS=$(cat << EOF 
    setExitTimeout(30000, 'session', 'RETRY');
    tprint('session... ', 1);
EOF
    )
    sed -i -e "s/setTimeout(exit, 4444);/${OPTS//$'\n'/\\$'\n'}/" ${NODEJS}
    cat << EOF >> ${NODEJS}
    var SteamTrade = require('${PWD}/steamnode/node_modules/steam-trade'),
      steam_trade = new SteamTrade(), truncated;
    function webLogOn() {
      steam.webLogOn(function(cookies) {
        cookies.forEach(function(cookie) {
          steam_trade.setCookie(cookie);
        });
        ${1}
        clearTimeout(exit_timeout);
        setTimeout(exit, 4444);
      });
    }
    steam.on('webSessionID', function(sessionID) {
      tprint('web... ', 1);
      steam_trade.sessionID = sessionID;
      webLogOn();
    });
    steam.on('sessionStart', function(user) {
      steam_trade.open(user, function() {
        // SESSIONSTART
      });
    });
    steam_trade.on('ready', function() {
      clearTimeout(exit_timeout);
      steam_trade.ready(function() {
        steam_trade.confirm();
      });
    });
    steam_trade.on('error', function(e) {
      tprint('error, refreshing web login... {!}');
      webLogOn();
    });
EOF
  fi
}

idler_trade()
{
  # logout and/or start node receiver session
  check_offer_input ${1} || return $?
  if [[ ${RECEIVER} = 765611* ]]; then
    OPTS="http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/"
    OPTS="${OPTS}?key=${APIKEY}&steamids=${RECEIVER}"
    if [ -z ${TRADE_LOCAL} ] \
    && wget -qO- "${OPTS}" | grep personastate\" | grep -qo 0; then
      tprint "${ACCT}: error, uid receiver offline" \<${RECEIVER:6}
      return 2
    elif ! is_friend ${RECEIVER}; then
      tprint "${ACCT}: error, uid receiver unfriendly" \<${RECEIVER:6}
      return 1
    fi
    tprint "warning, contacting ui client receiver" ${RECEIVER}
  else
    if is_node_login_available ${RECEIVER%/*} \
    || [ "$(node_login_background ${RECEIVER%/*})" = FAKE ]; then
      if ! set_account ${RECEIVER}; then
        EXIT=yes
      else
        RECEIVER=${ACCT}
        OPTS=$(cat << EOF 
        if (!receiver_stop && log.indexOf('STOP_RECEIVER') > -1) {
          stop_receiver();
        }
EOF
        )
        if ! prep_node_login yes "${OPTS}"; then
          EXIT=yes
        else
          prep_node_http
          OPTS="if (trades.length) {\n  steam_trade.open(trades[0]);\n}"
          prep_node_trade "$(echo -e ${OPTS})"
          sed -i -e "s/\/\/ SESSIONSTART/trade_count = 0;/" ${NODEJS}
          prep_node_enter ${CHATROOM}
          OPTS="steam.setPersonaState(Steam.EPersonaState.LookingToTrade);"
          OPTS="${OPTS}\nexitBreak('RECEIVER');"
          sed -i -e "s/setTimeout(exit, 4444);/${OPTS}/g" ${NODEJS}
          unset OPTS
          for SENDER in ${ACCOUNTS} ; do
            if steam_uid ${SENDER%%/*} > /dev/null; then
              OPTS=${OPTS},\'$(steam_uid ${SENDER%%/*})\'
            fi
          done
          cat << EOF >> ${NODEJS}
          var trade_count = 0, trades = [];
          function trade() {
            setTimeout(function() {
              steam.trade(trades[0]);
            }, 250);
          }
          steam.on('chatStateChange', function(change, user, chat, kicker) {
            if (change == 1 && [${OPTS:1}].indexOf(user) > -1) {
              if (trades.length) {
                tprint('queued uid ' + user + ' for receiving');
              }
              trades.push(user);
              if (trades.length == 1) {
                trade();
              }
            } else if ((change == 2 || change == 4)
            && trades.indexOf(user) > -1) {
              if (trades.indexOf(user) != 0) {
                tprint('warning, removed uid ' + user
                  + ' from receiver queue {*}');
              }
              if (user == ${OPTS##*,}) {
                stop_receiver();
              }
              trades.splice(trades.indexOf(user));
            }
          });
          steam.on('friendMsg', function(user, msg, entry) {
            if (user == trades[0] && msg == 'retry') {
              trade();
            }
          });
          steam_trade.on('chatMsg', function(msg) {
            if (trade_count == 0) {
              trade_count = Math.round(msg);
              if (trade_count == 256) {
                truncated = 1;
              }
            }
          });
          steam_trade.on('offerChanged', function(action, item) {
            if (action) {
              if (trade_count == 1) {
                http_opt.path = '/IEconItems_440/GetPlayerItems/v0001/?SteamID='
                  + steam.steamID + '&key=${APIKEY}';
                http.get(http_opt, function(response) {
                  var output = '';
                  response.on('data', function(chunk) {
                    output += chunk;
                  });
                  response.on('end', function() {
                    var result = JSON.parse(output).result;
                    if (steam_trade.themAssets.length + result.items.length
                    > result.num_backpack_slots) {
                      tprint('error, receiver backpack full {!}');
                      steam_trade.chatMsg('full');
                    } else {
                      tprint('confirming offer...');
                      steam_trade.chatMsg('ready');
                    }
                  });
                });
              }
              trade_count--;
            } else {
              tprint('error, item ' + item.name + ' removed {!}');
            }
          });
          var receiver_stop;
          function stop_receiver() {
            if (!receiver_stop) {
              receiver_stop = 1;
              setTimeout(function() {
                steam.leaveChat('${CHATROOM}');
                setTimeout(exit, 4444);
              }, 1000);
            }
          }
          steam.on('tradeResult', function(tradeid, result, user) {
            if (result != Steam.EEconTradeResponse.Accepted) {
              if (result == 22) {
                tprint('error, target account cannot trade {!}');
              } else {
                tprint('error, trade failure code ' + result + ' {!}');
              }
              if (trades[0] == ${OPTS##*,}) {
                stop_receiver();
              }
            }
          });
          steam_trade.on('end', function(status) {
            if (status != 'complete' && status != 'cancelled'
            && status !== undefined) {
              steam.sendMessage(trades[0], status);
            } else {
              if (truncated) {
                truncated = 0;
                trade();
              } else {
                if (trades[0] == ${OPTS##*,}) {
                  stop_receiver();
                } else {
                  trade_count = 0;
                  trades.splice(0);
                  if (trades.length) {
                    trade();
                  }
                }
              }
            }
          });
EOF
          if ! run_node_login; then
            EXIT=yes
          fi
        fi
      fi
      set_account ${OLD_ACCT}
      if [ ! -z ${EXIT} ]; then
        return 1
      fi
    elif [ "$(node_login_background ${RECEIVER%/*})" != RECEIVER ]; then
      tprint "error, receiver node login in use" ${RECEIVER}
      return 2
    fi
  fi

  # send items via trading session
  if [[ ${RECEIVER} != 765611* ]] && [ -z ${SUID} ]; then
    tprint "${ACCT}: error, no uid stored for sender"
  else
    check_item_safety || return 1
    prep_node_login || return 1
    prep_node_trade
    if [[ ${RECEIVER} = 765611* ]]; then
      OPTS="tprint('contacting friend...');"
      OPTS="${OPTS}\nsteam.setPersonaState(Steam.EPersonaState.LookingToPlay);"
      OPTS="${OPTS}\nsteam.trade('${RECEIVER}');"
    else
      prep_node_enter ${CHATROOM}
      OPTS="steam.setPersonaState(Steam.EPersonaState.LookingToPlay);"
      OPTS="${OPTS}\nsetExitTimeout(32000, 'sender');"
    fi
    sed -i -e "s/setTimeout(exit, 4444);/${OPTS}/g" ${NODEJS}
    OPTS=$(cat << EOF 
    if (!truncated) {
      tprint('loading inventories...');
    }
    truncated = 0;
    var inventories = [[],[],[]], totals = [];
    steam_trade.loadInventory(440, 2, function(inventory) {
      totals[1] = inventory.length;
      inventories[1] = inventory.filter(function(item) {
        ${OFFER}
      });
      steam_trade.loadInventory(753, 1, function(inventory) {
        if ('${NOSG}' != 'yes') {
          totals[2] = inventory.length;
          inventories[2] = inventory.filter(function(item) {
            return item.tradable;
          });
        }
        steam_trade.loadInventory(753, 6, function(inventory) {
          if ('${NOSC}' != 'yes') {
            totals[2] += inventory.length;
            inventories[2] = inventories[2].concat(
              inventory.filter(function(item) {
                return item.tradable;
              })
            );
          }
          inventories[0] = inventories[2].concat(inventories[1]);
          if (inventories[0].length) {
            if (inventories[0].length > 256) {
              tprint('warning, truncating oversized offer... {*}');
              truncated = 1;
              inventories[0] = inventories[0].slice(0, 256);
              inventories[1] = inventories[1].slice(0, 256);
              inventories[2] = inventories[2].slice(0,
                256-inventories[1].length);
            }
            setExitTimeout(80000, 'adding', 'RETRY');
            if (inventories[2].length) {
              tprint('adding ' + inventories[1].length + '\/' + totals[1]
                + ' + ' + inventories[2].length + '\/' + totals[2]
                + ' items...');
            } else {
              tprint('adding ' + inventories[1].length + '\/' + totals[1]
                + ' items...');
            }
            steam_trade.chatMsg(inventories[0].length, function() {
              inventories[0].forEach(function(item) {
                steam_trade.addItem(item);
              });
            });
          } else {
            tprint('no items to trade');
            steam_trade.cancel(function() {
              steam.leaveChat('${CHATROOM}');
              setTimeout(exit, 4444);
            });
          }
        });
      });
    });
EOF
    )
    sed -i -e "s/\/\/ SESSIONSTART/${OPTS//$'\n'/\\$'\n'}/g" ${NODEJS}
    cat << EOF >> ${NODEJS}
    steam.on('friendMsg', function(user, msg, entry) {
      if (user == $(steam_uid ${RECEIVER})) {
        tprint('error, trade error, ' + msg + ' {!}');
        steam.sendMessage(user, 'retry');
      }
    });
    steam_trade.on('chatMsg', function(msg) {
      if (msg == 'ready') {
        tprint('accepting trade...');
        steam_trade.ready();
      } else if (msg == 'full') {
        steam_trade.cancel(function() {
          console.error('FAIL');
          steam.leaveChat('${CHATROOM}');
          setTimeout(exit, 4444);
        });
      }
    });
    steam.on('tradeProposed', function(tradeid, user) {
      if (user == $(steam_uid ${RECEIVER})) {
        clearTimeout(exit_timeout);
        steam.respondToTrade(tradeid, true);
      } else {
        tprint('error, trade declined from unknown user {!}');
        steam.respondToTrade(tradeid, false);
      }
    });
    steam.on('tradeResult', function(tradeid, result, user) {
      if (result != Steam.EEconTradeResponse.Accepted) {
        if (result == Steam.EEconTradeResponse.Declined) {
          tprint('error, trade declined {!}');
        } else if (result != Steam.EEconTradeResponse.Accepted) {
          tprint('error, trade failure code ' + result + ' {!}');
        }
        console.error('FAILCONTINUE');
        steam.leaveChat('${CHATROOM}');
        setTimeout(exit, 4444);
      }
    });
    steam_trade.on('end', function(status) {
      if (status === undefined) {
        tprint('warning, trade confirmation required {*}');
        steam.leaveChat('${CHATROOM}');
        setTimeout(exit, 4444);
      } else if (status == 'complete' && !truncated) {
        steam.leaveChat('${CHATROOM}');
        setTimeout(exit, 4444);
      }
    });
EOF
  fi
}

idler_harvest()
{
  # craft, waste, trade, then sort in one node login
  check_offer_input ${1} || return $?
  prep_node_login yes || return 1
  unset HARVEST_BREAK
  if [ ! -z ${BREAK} ]; then
    HARVEST_BREAK=${BREAK}
  fi
  prep_node_trade
  if [[ ${1} = *:* ]] || [[ ${1} = *.* ]]; then
    idler_craft ${1%%[.:]*}
  else
    idler_craft
  fi
  if [[ ${1} = *:* ]]; then
    idler_waste $(echo ${1} | sed -e s/\\..*// -e s/.*://)
  else
    idler_waste
  fi
  idler_trade ${1##*.} || return $?
  idler_sort
  if [ ! -z ${HARVEST_BREAK} ]; then
    BREAK=${HARVEST_BREAK}
  fi
}

idler_rename()
{
  # generate and/or assign a profile name
  prep_node_login || return 1
  NAME="~word-~INT_~WORD~INDEX"
  if [ ! -z ${1} ]; then
    NAME="${1//^/ }"
  fi
  while [[ ${NAME} = *~word* ]]; do
    NAME=${NAME/~word/$(random_word)}
  done
  while [[ ${NAME} = *~WORD* ]]; do
    NAME=${NAME/~WORD/$(random_word | tr [:lower:] [:upper:])}
  done
  NAME=${NAME//\'/}
  NAME=$(echo ${NAME} | sed -e s/steam/pdl/g -e s/STEAM/pdl/g -e s/valve/pdl/g \
    -e s/VALVE/pdl/g)
  while [[ ${NAME} = *~INT* ]]; do
    NAME=${NAME/~INT/${RANDOM:(-1)}}
  done
  unset INDEX FOUND
  for RENAME in ${ACCOUNTS_ARRAY}; do
    let INDEX+=1
    if [ ${RENAME} = ${ACCT} ]; then
      FOUND=${INDEX}
      break
    fi
  done
  if [ ! -z ${FOUND} ]; then
    NAME=${NAME//~INDEX/+${FOUND}}
  else
    NAME=${NAME//~INDEX/}
  fi
  NAME=${NAME//~ACCT/${ACCT}}
  OPTS="steam.setPersonaState(Steam.EPersonaState.Online);"
  sed -i -e "s/setTimeout(exit, 4444);/${OPTS}/" ${NODEJS}
  cat << EOF >> ${NODEJS}
  var rename;
  steam.on('user', function(user) {
    if (user.friendid == steam.steamID) {
      if (!rename) {
        if (user.playerName == '${NAME}') {
          rename = 2;
          tprint('error, cannot apply the same name {!}', 2);
          setTimeout(exit, 4444);
        } else {
          rename = 1;
          tprint('renaming to "${NAME}"...', 2);
          steam.setPersonaName('${NAME}');
        }
      } else if (rename == 1) {
        rename = 2;
        setTimeout(exit, 4444);
      }
    }
  });
EOF
}

# check script name/user/directory, source, check apikey, then trap
if [[ ${PDLIDLER} != pdl-idler* ]]; then
  tprint "fatal, renamed scripts must start with pdl-idler*" ${PDLIDLER}
  exit 1
elif [ ${USER} = root ]; then
  tprint "fatal: cannot be run as root"
  exit 1
elif [ -d share ] && [ ! -w share/ ] || [ ! -w . ]; then
  tprint "fatal, pwd or share directory is unwriteable" $(pwd)
  exit 1
fi
unset APIKEY
source ./pdl-idler_common.sh
if [ -z ${APIKEY} ]; then
  tprint "${ACCT}: fatal, apikey not specified"
  exit 1
fi
trap sigint SIGINT

# enforce dependencies, and check wine version
for DEP in git glxinfo ip nc npm screen wget xdotool xwininfo xprop Xvfb; do
  if ! which ${DEP} > /dev/null 2>&1; then
    tprint "fatal, missing dependency '${DEP}'"
    exit 1
  fi
done
if [[ ${WINE} != 1.[8-9]* ]]; then
  tprint "fatal, wine is not installed or is too old" wine\<1.8
  # XXX exit 1
fi

# check for script updates
mkdir -p share/.gist
if [ -z ${UPGRADE} ] && [ ${PDLIDLER} = pdl-idler.sh ]; then
  if [ -z $(find share/.gist/ -maxdepth 1 -name pdl-idler.sh -mmin -1440) ] \
  || [ "${GIST_FORCE}" = yes ]; then
    tprint "checking for gist update..." http://gist.github.com
    if download gist.github.com/primarydataloop/1432762/download .gist.zip; then
      unzip -od share/.gist .gist.zip > /dev/null
      mv -f share/.gist/1432762-*/* share/.gist
      NEW=$(grep -om1 \(.* share/.gist/pdl-idler.sh | grep -o "[0-9]*\.[0-9]*")
      if (( 1${VERSION//./} < 1${NEW//./} )); then
        cat share/.gist/CHANGELOG | tail -n+3 \
          | sed -e "/\[version ${VERSION}\]/q" | head -n-1
        tprint "enter y to logout and upgrade script" "${VERSION}>${NEW}:" "" 1
        read -e -t 60 INPUT || echo
        if [ "${INPUT}" != y ]; then
          tprint "warning, update skipped" "${VERSION}>${NEW}"
        else
          UPGRADE=yes bash ${PDLIDLER} logout
          cp share/.gist/* .
          tprint "upgraded pdl-idler" "${VERSION}>${NEW}"
          exec bash pdl-idler.sh $*
        fi
      fi
    fi
    touch share/.gist/pdl-idler.sh
  fi
fi
rm -rf .gist.zip share/.gist/1432762-master

# select target accounts
INPUT="$* "
INPUT="${INPUT#* }"
for STRING in $(echo ${INPUT} | tr ' ' '\n' \
| grep [-]*[+:][0-9][0-9]*\\.*.*[0-9][0-9]*); do
  unset MINUS
  if [ ${STRING:0:1} = - ]; then
    MINUS=-
    STRING=${STRING:1}
  fi
  TYPE=${STRING:0:1}
  RANGE=${STRING//[+:]}
  unset NUM
  if ((${RANGE%%.*} > ${RANGE##*.})); then
    tprint "error, invalid account range specified" ${RANGE}
    exit 1
  else
    COUNT=${RANGE%%.*}
    while ((COUNT <= ${RANGE##*.})); do
      NUM=${NUM}${MINUS}${TYPE}${COUNT}\ 
      let COUNT+=1
    done
  fi
  INPUT=${INPUT/${MINUS}${STRING}/${NUM}}
done
if [ ! -z "${ACCOUNTS}" ]; then
  for BLOCK in $(echo ${INPUT} | tr ' ' '\n' | grep \:[0-9]*); do
    unset MINUS
    if [ ${BLOCK:0:1} = - ]; then
      MINUS=-
      BLOCK=${BLOCK:1}
    fi
    unset ACCTS
    for ACCT in ${ACCOUNT_BLOCKS[${BLOCK:1}]}; do
      ACCTS="${ACCTS} ${MINUS}${ACCT}"
    done
    if [ -z "${ACCTS}" ]; then
      tprint "error, invalid group index specified" \#${BLOCK:1}
      exit 1
    fi
    INPUT=${INPUT/${MINUS}${BLOCK}/${ACCTS}}
  done
else
  for ACCT in wine-*; do
    if [ -d ${ACCT} ]; then
      ACCOUNTS="${ACCOUNTS} ${ACCT/wine-/} "
    fi
  done
  for ACCT in share/*; do
    if [ -e ${ACCT}/ssfn ]; then
      if [[ ${ACCOUNTS} != *${ACCT:11}\ * ]]; then
        ACCOUNTS="${ACCOUNTS} ${ACCT:11} "
      fi
    fi
  done
fi
ACCOUNTS_ARRAY=(null ${ACCOUNTS})
for INDEX in $(echo ${INPUT} | tr ' ' '\n' | grep -o ^[-]*[+][0-9]*); do
  unset MINUS
  if [ ${INDEX:0:1} = - ]; then
    MINUS=-
    INDEX=${INDEX:1}
  fi
  if [[ ${INDEX} = *[0-9]* ]] && [ ! -z ${ACCOUNTS_ARRAY[${INDEX}]} ]; then
    INPUT=" ${INPUT/${MINUS}${INDEX}/${MINUS}${ACCOUNTS_ARRAY[${INDEX:1}]}} "
  else
    tprint "error, invalid account index specified" ${INDEX}
    exit 1
  fi
done
INPUT=\ ${INPUT}\ 
ACCOUNTS=\ ${ACCOUNTS}\ 
for MINUS in $(echo ${INPUT} | tr ' ' '\n' | grep \\-.*); do
  INPUT=${INPUT// ${MINUS} / }
  MINUS=${MINUS:1}
  INPUT=${INPUT// ${MINUS} / }
  INPUT="$(echo \ ${INPUT} | sed -e "s/\ ${MINUS%%\/*}\/[[:graph:]]*\ /\ /") "
  ACCOUNTS=${ACCOUNTS// ${MINUS} / }
  ACCOUNTS="$(echo \ ${ACCOUNTS} \
    | sed -e "s/\ ${MINUS%%\/*}\/[[:graph:]]*\ /\ /") "
done
if echo \ ${INPUT} | grep -oiq -m 1 " [a-z0-9]"; then
  ACCOUNTS="${INPUT}"
fi

# check script input
if [ -z "${1}" ]; then
  idler_help
  tprint "error, no supplied actions"
  exit 1
elif [ -z "$(echo ${ACCOUNTS})" ]; then
  tprint "error, no initiated or specified accounts"
  exit 1
fi
for ACTION in $(echo ${1} | tr '[%,]' '\n' | tr [:upper:] [:lower:]); do
  if ! declare -f | grep -q ^idler_$(echo ${ACTION/=*})\ ; then
    idler_help
    tprint "fatal, invalid action '${ACTION/=*}'"
    exit 1
  fi
done

# delete unused passwd scripts, remove dead screens, then kill defunct processes
for LINE in $(screen -wipe idler- | grep -o \\-.*Removed | awk '{print $1}'); do
  tprint "removed dead ${LINE:1:${#LINE}-2} screen session"
done
for DPID in $(pgrep -fx steam\\.exe\|hl2\\.exe); do
  tprint "killing defunct steam/hl2 process..." @${DPID}
  kill -9 ${DPID}
done

# clutch the merging of steamwindows/steamcmd directories with kill/rm if needed
if [ -d steamwindows ]; then
  tprint "warning, performing steam_cmd/windows merge clutch..." 0.9019
  killall -vw wineserver
  find steamcmd/steamapps -maxdepth 2 -type l -exec rm {} \;
  mv steamcmd steam
  mv steamwindows/steamapps/appmanifest*.acf steam/steamapps 2> /dev/null
  mv steamwindows/steamapps/common/* steam/steamapps/common 2> /dev/null
  rm -fr steamwindows steam/config steam/logs steam/userdata steam/package \
    steam/ssfn* steam/.crash steam/dumps "${STF}"/*.tar.gz "${STF}"/pdl* \
    "${TF}"/cfg/config.cfg "${TF}"/cfg/autoexec.cfg "${TF}"/cfg/personal.cfg \
    "${TF}"/cfg/audible.cfg "${TF}"/pdl/farm/ver .pdl-idler_helper.log wine wine-*
fi

# run action sets with specified accounts
for ACTIONS in $(echo ${1} | tr ',' '\n'); do
  for ACCT in ${ACCOUNTS}; do
    if [ "${OLD_ACCT%%/*}" != ${ACCT%%/*} ]; then
      ACTION_TIME=$(date +%s)
    fi
    if set_account ${ACCT}; then
      for ACTION in $(echo ${ACTIONS} | tr '%' '\n'); do
        ARG=$(echo ${ACTION} | sed -e "s/[a-z_]*=*//" -e "s/__*/_/g")
        ACTION=$(echo ${ACTION/=*} | tr [:upper:] [:lower:])
        case ${ACTION} in
        sleep )
          if [ -z ${ARG} ]; then
            ARG=5
          fi
          tprint "sleeping..." ${ARG}
          idler_sleep ${ARG}
          if [[ ${ACTIONS} != *%* ]]; then
            break 2
          fi
          ;;
        stop )
          idler_stop ${ARG}
          ;;
        logout )
          idler_logout ${ARG}
          ;;
        uninstall )
          idler_uninstall ${ARG}
          ;;
        delete )
          idler_delete ${ARG}
          ;;
        login )
          idler_login ${ARG} || break $?
          ;;
        play )
          if ! hl2_pid > /dev/null; then
            idler_login ${ARG} || break $?
            idler_play
          fi
          ;;
        command )
          if hl2_pid > /dev/null; then
            idler_command "${ARG//^/ }"
          fi
          ;;
        disconnect )
          if hl2_pid > /dev/null; then
            idler_disconnect
          fi
          ;;
        connect )
          idler_connect ${ARG} || break
          ;;
        farm )
          idler_farm || break $?
          ;;
        help )
          idler_help ${ARG}
          break 2
          ;;
        log )
          idler_log ${ARG} || break 2
          ;;
        list )
          idler_list ${ARG}
          ;;
        backpack )
          idler_backpack ${ARG}
          ;;
        status )
          idler_status ${ARG}
          ;;
        utility )
          idler_utility "${ARG//^/ }"
          ;;
        website )
          idler_website ${ARG}
          ;;
        create )
          idler_create || break
          ;;
        offline )
          idler_offline
          ;;
        online )
          idler_online ${ARG}
          ;;
        enter )
          idler_enter ${ARG} || break
          ;;
        exit )
          idler_exit
          ;;
        friend )
          idler_friend ${ARG}
          ;;
        register )
          idler_register
          ;;
        exhibit )
          idler_exhibit ${ARG}
          ;;
        socialize )
          idler_socialize ${ARG}
          ;;
        discover )
          idler_discover ${ARG}
          ;;
        * )
          case ${ACTION} in
          fake )
            idler_fake "${ARG}" yes || break
            ;;
          craft )
            idler_craft "${ARG}" || break
            ;;
          waste )
            idler_waste "${ARG}" || break
            ;;
          sort )
            idler_sort || break
            ;;
          deterge )
            idler_deterge "${ARG}" || break
            ;;
          trade )
            idler_trade "${ARG}"
            ;;
          harvest )
            idler_harvest "${ARG}"
            ;;
          rename )
            idler_rename "${ARG}" || break
            ;;
          esac
          RETURN=$?
          if [ ${RETURN} = 1 ]; then
            continue
          elif [ ${RETURN} = 2 ]; then
            break 2
          fi
          run_node_login || break $?
          ;;
        esac
      done
    fi
  done

  # manage offer receiver stop and/or finish
  if [ ! -z ${RECEIVER} ]; then
    while node_login_pid ${RECEIVER} > /dev/null \
    && [ $(node_login_background ${RECEIVER}) != FAKE ]; do
      if [ -z ${RECEIVER_STOP} ]; then
        RECEIVER_STOP=yes
        echo STOP_RECEIVER >> share/${RECEIVER}/node.log
      fi
      idler_sleep 1
    done
    unset RECEIVER RECEIVER_STOP
  fi
done
finish
