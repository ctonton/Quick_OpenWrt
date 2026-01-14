#!/bin/bash

# check for and install dependencies
[ "$(id -u)" = 0 ] && echo "This script can not be executed as \"root\" user." && exit 1
depA=(curl jq zstd openssl build-essential file libncurses-dev zlib1g-dev gawk git gettext libssl-dev xsltproc rsync wget unzip python3 python3-setuptools)
for dep in ${depA[@]} ; do dpkg -l "$dep" 2>/dev/null | grep -q '^ii' || i=1; done
if [ "$i" = 1 ] ; then
  sudo apt update && sudo apt -y install ${depA[@]} || exit $?
fi

# set functions
getVARS() {
  versA=($(curl -s "https://downloads.openwrt.org/releases/" | pup 'tr td a text{}' | grep '^[0-9]'))
  [ -z "${versA[*]}" ] && echo -e "Host \"https://downloads.openwrt.org/releases/\" is unreachable." && exit 127
  versA+=("snapshots")
  if [[ " ${versA[*]} " =~ " ${VERS} " ]] ; then
    v="$VERS"
  else
    echo
    PS3="Select openwrt version: "
    select v in ${versA[@]} ; do break ; done
  fi
  [ "$v" = "snapshots" ] && r="$v" || r="releases/$v"
  archA=($(curl -s "https://downloads.openwrt.org/$r/targets/" | pup 'tr a text{}'))
  [ -z "${archA[*]}" ] && echo -e "Host \"https://downloads.openwrt.org/$r/targets/\" is unreachable." && exit 127
  if [[ " ${archA[*]} " =~ " ${ARCH} " ]] ; then
    a="$ARCH"
  else
    echo
    PS3="Select device architecture: "
    select a in ${archA[@]} ; do break; done
  fi
  chipA=($(curl -s "https://downloads.openwrt.org/$r/targets/$a/" | pup 'tr a text{}'))
  [ -z "${chipA[*]}" ] && echo -e "Host \"https://downloads.openwrt.org/$r/targets/$a/\" is unreachable." && exit 127
  if [[ " ${chipA[*]} " =~ " ${CHIP} " ]] ; then
    c="$CHIP"
  else
    echo
    PS3="Select processor family: "
    select c in ${chipA[@]} ; do break; done
  fi
  modlA=($(curl -s "https://downloads.openwrt.org/$r/targets/$a/$c/profiles.json" | jq -r '.profiles | keys[]'))
  [ -z "${modlA[*]}" ] && echo -e "Host \"https://downloads.openwrt.org/$r/targets/$a/$c/\" is unreachable." && exit 127
  if [[ " ${modlA[*]} " =~ " ${MODL} " ]] ; then
    m="$MODL"
  else
    echo
    PS3="Select router make: "
    select brand in $(printf "%s\\n" ${modlA[@]} | cut -d '_' -f 1 | uniq) ; do break; done
    echo
    PS3="Select router model: "
    select model in $(printf "%s\\n" ${modlA[@]} | grep "$brand" | cut -d '_' -f 2 | sort) ; do break; done
    m="$brand"_"$model"
  fi
  f=$(curl -s "https://downloads.openwrt.org/$r/targets/$a/$c/" | pup 'tr a text{}' | grep 'imagebuilder')
  [ -z "$f" ] && echo -e "Host \"https://downloads.openwrt.org/$r/targets/$a/$c/\" is unreachable." && exit 127
  d="${f%.tar.*}"
  cat >vars <<EOF
VERS='$v'
ARCH='$a'
CHIP='$c'
MODL='$m'
EOF
}

# select imagebuilder package and profile
if [ -f "vars" ] ; then 
  source ./vars
  v="$VERS"
  a="$ARCH"
  c="$CHIP"
  m="$MODL"
  [ "$v" = "snapshots" ] && d="openwrt-imagebuilder-$a-$c.Linux-x86_64" || d="openwrt-imagebuilder-$v-$a-$c.Linux-x86_64"
  [ -d "$d" ] || getVARS
else
  getVARS
fi

# set root password
echo
echo "Set the root password for openwrt."
until h=$(openssl passwd -5) ; do echo ; done
p="root:$h:$(($(date +%s) / 86400)):0:99999:7:::"

# download and extract imagebuilder package
if [ ! -d "$d" ] ; then
  [ -f "$f" ] || wget "https://downloads.openwrt.org/$r/targets/$a/$c/$f" || exit $?
  tar -axf "$f"
fi

# copy packages and files
[ -f "uci" ] || echo "uci -q del wireless.radio0.disabled" >uci
[ -f "opkg" ] || echo "luci" >opkg
rm -rf "$d/bin" "$d/files" "$d/packages"
[ -d "files" ] && cp -r files "$d"/ || mkdir -p "$d/files"
[ -d "packages" ] && cp -r packages "$d"/ || mkdir -p "$d/packages"

# setup repositories
[ -f "$d/repositories.bak" ] || cp "$d/repositories.conf" "$d/repositories.bak"
if [ -s "repos" ] ; then
  sed -i 's/^option/#option/' "$d/repositories.conf"
  while IFS= read -r line; do
    grep -q "$line" "$d/repositories.conf" || echo "$line" >>"$d/repositories.conf"
  done <repos
fi

# write default settings 
mkdir -p "$d/files/etc/uci-defaults"
if ! echo $p | grep -q ':<NULL>:' ; then
  echo -e "#!/bin/sh\np='$p'" >"$d/files/etc/uci-defaults/10-pas"
  echo 'sed -i "s~^root.*~$p~" /etc/shadow' >>"$d/files/etc/uci-defaults/10-pas"
  echo 'exit 0' >>"$d/files/etc/uci-defaults/10-pas"
  chmod +x "$d/files/etc/uci-defaults/10-pas"
fi
if [ -s "uci" ] ; then
  echo '#!/bin/sh' >"$d/files/etc/uci-defaults/20-uci"
  cat ./uci >>"$d/files/etc/uci-defaults/20-uci"
  echo -e "uci commit\nexit 0" >>"$d/files/etc/uci-defaults/20-uci"
  chmod +x "$d/files/etc/uci-defaults/20-uci"
fi
opkgA=($(cat opkg | xargs))

# build images
cd "$d"
make image PROFILE="$m" PACKAGES="${opkgA[*]}" FILES="files" || exit $?

# copy build
mkdir -p ../bin
cp -f "bin/targets/$a/$c"/* ../bin/

exit 0
