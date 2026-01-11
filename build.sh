#!/bin/bash

# check for and install dependencies
[ "$(id -u)" = 0 ] && echo "This script can not be executed as \"root\" user." && exit 1
depA=(curl zstd openssl build-essential file libncurses-dev zlib1g-dev gawk git gettext libssl-dev xsltproc rsync wget unzip python3 python3-setuptools)
for dep in ${depA[@]} ; do dpkg -l "$dep" 2>/dev/null | grep -q '^ii' || i=1; done
if [ "$i" = 1 ] ; then
  sudo apt update && sudo apt -y install ${depA[@]} || exit $?
fi

# select imagebuilder package
[ -f "vars" ] && source ./vars
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
f=$(curl -s "https://downloads.openwrt.org/$r/targets/$a/$c/" | pup 'tr a text{}' | grep 'imagebuilder')
[ -z "$f" ] && echo -e "Host \"https://downloads.openwrt.org/$r/targets/$a/$c/\" is unreachable." && exit 127

# download and extract imagebuilder package
d="${f%.tar.*}"
if [ ! -d "$d" ] ; then
  [ -f "$f" ] || wget "https://downloads.openwrt.org/$r/targets/$a/$c/$f" || exit $?
  tar -axf "$f"
fi

# set root password
echo
echo "Set the root password for openwrt."
until h=$(openssl passwd -5) ; do echo ; done
p="root:$h:$(($(date +%s) / 86400)):0:99999:7:::"

# copy packages and files
mkdir -p bin files packages
[ -f "uci" ] || echo "uci del wireless.radio0.disabled" >uci
[ -f "opkg" ] || echo "luci" >opkg
[ -f "repos" ] || touch repos
rm -rf "$d/bin" "$d/files" "$d/packages"
cp -r packages "$d"/
cp -r files "$d"/
opkgA=($(cat opkg | xargs))

# setup extra repositories
if [ -s "repos" ] ; then
  sed -i 's/^option/#option/' "$d/repositories.conf"
  while IFS= read -r line; do
    grep -q "$line" "$d/repositories.conf" || echo "line" >>"$d/repositories.conf"
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

# build images
cd "$d"
[ -f ".profiles.mk" ] || make info &>/dev/null
modlA=($(grep 'PROFILE_NAMES = ' .profiles.mk | sed 's/PROFILE_NAMES = //;s/DEVICE_//g'))
if [[ " ${modlA[*]} " =~ " ${MODL} " ]] ; then
  m="$MODL"
else
  echo
  PS3="Select router make: "
  select b in $(printf "%s\\n" ${modlA[@]} | cut -d '_' -f 1 | uniq) ; do break; done
  echo
  PS3="Select router model: "
  select r in $(printf "%s\\n" ${modlA[@]} | grep "$b" | cut -d '_' -f 2 | sort) ; do break; done
  m="$b"_"$r"
fi
make image PROFILE="$m" PACKAGES="${opkgA[*]}" FILES="files" || exit $?

# copy build
cp -f "bin/targets/$a/$c"/* ../bin/
cat >../vars <<EOF
VERS='$v'
ARCH='$a'
CHIP='$c'
MODL='$m'
EOF

exit 0
