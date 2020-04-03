if [ "${1}" = "dir" ]; then
  while [ 1 ]; do
    FILE=$(ls -1 *.jpg 2> /dev/null | head -n1)
    if [ -z "${FILE}" ]; then
      break
    fi
    APPID=$(echo "${FILE}" | tr '_' "\n" | sed -n 2p)
    mkdir -p ${APPID}
    mv -v *_${APPID}_*.jpg ${APPID}
  done
else
  for DIR in *; do
  if [ -d ${DIR} ]; then
  mv ${DIR} ${DIR%-*} 2> /dev/null
  mv ${DIR%-*} ${DIR%-*}-$(find ${DIR%-*}/ -type f | wc -l)/
  fi
  done
fi
ISTEAMUSER=https://api.steampowered.com/ISteamUser
if [ ! -z ${1} ]; then
  STEAMIDS=$*
  STEAMIDS=${STEAMIDS//http:////steamcommunity.com//profiles///}
else
  STEAMIDS=$(grep -o "765611[0-9]*', //+" post.js | grep -o \[0-9]*)
fi
for STEAMID in ${STEAMIDS}; do
  if ! ls -1 | grep -q "${STEAMID}.*"; then
    NAME="$(wget -qO- ${ISTEAMUSER}/GetPlayerSummaries/v0002/?key=${KEY}\&steamids=${STEAMID} \
      | grep personaname | sed -e s/.*personaname\":\ // -e s/\"//g -e s/[^a-zA-Z0-9]//g)"
    mkdir -vp ${STEAMID}_${NAME,,}
  fi
  STEAMID=$(ls -1 | grep ${STEAMID})
  for IMAGE in $(ls ${STEAMID}/[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].* 2> /dev/null); do
    mv -v ${IMAGE} ${IMAGE:0:(-4)}_.jpg
  done

  # process each page from download or saved file
  unset PAGE
  while true; do
    let PAGE+=1
    unset DOWNLOADED IMAGE IMAGES WGET
    if [ ! -e ${STEAMID}/page${PAGE}.html ]; then
      wget -qO ${STEAMID}/page${PAGE}.html \
        "http://steamcommunity.com/profiles/${STEAMID:0:17}/images/?p=${PAGE}&appid=0/&sort=oldestfirst/&browsefilter=myfiles&view=grid"
      WGET=yes
    fi
    for IMAGE in $(cat ${STEAMID}/page${PAGE}.html 2> /dev/null | grep -o {LINK REMOVED}[0-9]*\"); do
      IMAGES=${IMAGES},${IMAGE##*=}

      # check existance/negation
      if [ ! -e ${STEAMID}/${IMAGE##*=}_* ]; then
        CAPTION=$(grep -A12 ${IMAGE} ${STEAMID}/page${PAGE}.html | grep ellipsis \
          | sed -e "s/.*\">//" -e "s/<\/q>.TODO=ASTERISK//" -e "s/[^a-zA-Z0-9,\.-]/_/g")
        if [ -e ${STEAMID}/.${IMAGE##*=}_* ]; then
          echo skipping hidden
          echo > ${STEAMID}/.${IMAGE##*=}.*
        else

          # announce/download image then sleep
          if [ -z ${DOWNLOADED} ]; then
            DOWNLOADED=yes
            echo ${STEAMID}_page=${PAGE}
          fi
          echo " ${IMAGE##*=}_${CAPTION}"
          URL=$(grep -A2 ${IMAGE} ${STEAMID}/page${PAGE}.html | grep -o http://.*ugc/.*/|)
          wget -O ${STEAMID}/${IMAGE##*=}_.jpg -q "${URL%%\/\?*}"/
          sleep 0.5
        fi

        # rename and/or sleep
        if file ${STEAMID}/${IMAGE##*=}_.* | grep -q GIF; then
          mv -v ${STEAMID}/${IMAGE##*=}_.* ${STEAMID}/${IMAGE##*=}_${CAPTION}.gif
        elif file ${STEAMID}/${IMAGE##*=}_.* | grep -q PNG; then
          mv -v ${STEAMID}/${IMAGE##*=}_.* ${STEAMID}/${IMAGE##*=}_${CAPTION}.png
        else
          mv -v ${STEAMID}/${IMAGE##*=}_.* ${STEAMID}/${IMAGE##*=}_${CAPTION}.jpg
        fi
      fi
    done

    # remove pages that were downloaded and/or continue if page was empty
    if [ ! -z ${WGET} ]; then
      rm -v ${STEAMID}/page${PAGE}.html
    fi
    if [ -z ${IMAGE} ]; then
      break
    fi
  done

  # track deletions
  for DELETED in $(ls ${STEAMID}/[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_.* 2> /dev/null); do
    if [[ ${IMAGES} != *${DELETED:0:(-4)}* ]]; then
      mv -v ${DELETED} ${DELETED/\//\/--}
    fi
  done

  # check for identical files
  for IDENTICAL in $(md5sum ${STEAMID}/* | sort \
  | awk 'BEGIN{lasthash = ""} $1 == lasthash {print $2} {lasthash = $1}' \
  | xargs echo); do
    echo Duplicate: ${IDENTICAL}
  done
done