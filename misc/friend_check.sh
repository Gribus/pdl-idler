#!/bin/bash

cd /mnt/Datavault/Work/Tampermonkey

# // get friends list and sort by id
function get_list()
{
  wget -qO- "https://api.steampowered.com/ISteamUser/GetFriendList/v1/?key=&format=json&steamid=76561197961017729" \
    | grep -o "765611[0-9]*" | sort -n
}

# // check for uf/dupe
if [ ! -z ${1} ] ; then
  STEAMIDS=$(get_list)
  for STEAMID in $(grep -o "76561[0-9]*" friends.js); do
    if [[ ${STEAMIDS} != *${STEAMID}* ]]; then
      grep ${STEAMID} friends.js
    fi
  done
  for STEAMID in $(grep -o "765611[0-9][0-9]*" friends.js); do
    if [ $(grep ${STEAMID} friends.js | wc -l) != 0 ] \
    && [ $(grep ${STEAMID} friends.js | wc -l) != 1 ]; then
      echo ${STEAMID}
    fi
  done

# // track changes
else
  if [ ! -e .friends ]; then
    get_list > .friends
  fi
  while true; do
    get_list > /tmp/friends
    if ! grep -q 765611 /tmp/friends; then
      echo failure
    elif ! diff .friends /tmp/friends > /dev/null; then
      {
        for STEAMID in $(diff .friends /tmp/friends | grep -o "765611[0-9]*"); do
          NAME="$(wget -qO- https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=\&steamids=${STEAMID} \
          | grep personaname | sed -e s/.*personaname\":\ // -e s/\"//g)"
          if grep -q ${STEAMID} /tmp/friends; then
            printf "$(date +%m/%d-%H:%M) (add)"
          else
            printf "$(date +%m/%d-%H:%M) <b>{DEL}</b>"
          fi
          echo "=$(cat /tmp/friends | wc -l) '<a href=\"http://steamcommunity.com/profiles/${STEAMID}\">http://steamcommunity.com/profiles/${STEAMID}'</a>, // ${NAME:0:(-1)}<br/>"
        done
      } >> .friends.html
      cp -v /tmp/friends .friends
    fi
    rm /tmp/friends
    sleep $((120+$(shuf -n 1 -i 60-180)))
  done
fi