#!/bin/bash
rm -f /tmp/deflist /tmp/ipklist

## address of imagebuilder package or comment out to chose later
#url="https://downloads.openwrt.org/releases/23.05.4/targets/ramips/mt7621/openwrt-imagebuilder-23.05.4-ramips-mt7621.Linux-x86_64.tar.xz"

## model of router to build for or comment out to chose later
#mod="xiaomi_mi-router-4a-gigabit"

## set default password or comment out to leave blank
pas="password"

## packages to install
opk="(luci)"

## set uci defaults
cat >/tmp/deflist <<EOF
uci set wireless.radio0.disabled='0'
EOF

# check for and install dependencies
dep="build-essential libncurses-dev zlib1g-dev gawk git gettext libssl-dev xsltproc rsync wget unzip python3 python3-distutils curl pup"
for p in $dep; do dpkg -l "$p" 2>/dev/null | grep -q '^ii' || i=1; done
if [[ $i -eq 1 ]]; then
  sudo apt update
  sudo apt install -y $dep || exit $?
fi

# download and extract imagebuilder package
if [[ -n $url ]]; then
  a="$(echo $url | cut -d '/' -f7)"
  c="$(echo $url | cut -d '/' -f8)"
  f="${url##*/}"
else
  echo
  PS3="Select openwrt version: "
  select v in $(curl -s https://downloads.openwrt.org/releases/ | pup 'tr td a text{}' | grep '^[0-9]'); do break; done
  echo
  PS3="Select arch target: "
  select a in $(curl -s https://downloads.openwrt.org/releases/"$v"/targets/ | pup 'tr a text{}'); do break; done
  echo
  PS3="Select chip model: "
  select c in $(curl -s https://downloads.openwrt.org/releases/"$v"/targets/"$a"/ | pup 'tr a text{}'); do break; done
  f=$(curl -s https://downloads.openwrt.org/releases/"$v"/targets/"$a"/"$c"/ | pup 'tr a text{}' | grep 'imagebuilder')
  url=https://downloads.openwrt.org/releases/"$v"/targets/"$a"/"$c"/"$f"
fi
if [[ ! -f "$f" ]]; then
  wget "$url" || exit $?
fi
d="${f%.tar.xz}"
[[ -d "$d" ]] || tar -J -x -f "$f"
cd "$d"

# write defaults
rm -rf files/etc/uci-defaults
mkdir -p files/etc/uci-defaults
cat /tmp/deflist 2>/dev/null >files/etc/uci-defaults/98-defaults
echo "uci commit" >>files/etc/uci-defaults/98-defaults
[[ -n $pas ]] && cat >files/etc/uci-defaults/99-password <<EOF
echo -e "$pas\n$pas" | passwd root
EOF
rm /tmp/deflist

# build images
if [[ -z $mod ]]; then
  [[ -f .profiles.mk ]] || make info &>/dev/null
  echo
  PS3="Select router make: "
  select b in $(cat .profiles.mk | grep 'DEVICE_.*NAME' | cut -d '_' -f2 | sort -u); do break; done
  echo
  PS3="Select router model: "
  select r in $(cat .profiles.mk | grep "DEVICE_$b.*NAME" | cut -d '_' -f3); do break; done
  mod="$b"_"$r"
fi
rm -rf bin/targets/"$a"/"$c"/*
make image PROFILE="$mod" PACKAGES="${opk[*]}" FILES="files" || exit $?

# host new files
pgrep -x python3 >/dev/null && kill $(pgrep -x python3)
cd bin/targets/"$a"/"$c"
nohup python3 -m http.server &>/dev/null &
echo
echo "Files can be downloaded from http://$(hostname -I | awk '{print $1}'):8000"
echo
exit 0
