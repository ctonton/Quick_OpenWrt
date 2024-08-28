#!/bin/bash

## address of imagebuilder package or comment out to chose later
#url="https://downloads.openwrt.org/releases/23.05.4/targets/ramips/mt7621/openwrt-imagebuilder-23.05.4-ramips-mt7621.Linux-x86_64.tar.xz"

## model of router to build for or comment out to chose later
#mod="xiaomi_mi-router-4a-gigabit"

## extra packages to install
opk="luci-ssl luci-app-opkg nano"

## check for and install dependencies
dep="build-essential libncurses-dev zlib1g-dev gawk git gettext libssl-dev xsltproc rsync wget unzip python3 python3-distutils curl"
for p in $dep; do dpkg -l "$p" 2>/dev/null | grep -q '^ii' || i=1; done
if [[ $i -eq 1 ]]; then
  sudo apt update
  sudo apt install -y $dep || exit $?
fi

## download and extract imagebuilder package
if [[ -z $url ]]; then
  echo
  PS3="Select openwrt version: "
  select v in $(curl -s https://downloads.openwrt.org/releases/ | grep 'td class' | cut -d '"' -f4 | grep "^[0-9]"); do break; done
  echo
  PS3="Select arch target: "
  select a in $(curl -s https://downloads.openwrt.org/releases/"$v"targets/ | grep 'td class' | cut -d '"' -f4); do break; done
  echo
  PS3="Select chip model: "
  select c in $(curl -s https://downloads.openwrt.org/releases/"$v"targets/"$a" | grep 'td class' | cut -d '"' -f4); do break; done
  f=$(curl -s https://downloads.openwrt.org/releases/"$v"targets/"$a""$c" | grep 'openwrt-imagebuilder' | cut -d '"' -f4)
  url=https://downloads.openwrt.org/releases/"$v"targets/"$a""$c""$f"
else
  f="${url##*/}"
fi
if [[ ! -f "$f" ]]; then
  wget "$url" || exit $?
fi
d="${f%.tar.xz}"
if [[ ! -d "$d" ]]; then
  tar -J -x -f "$f"
fi
cd "$d"

## set uci defaults
mkdir -p files/etc/uci-defaults
rm -f files/etc/uci-defaults/*
echo "echo -e 'password\npassword' | passwd root" >files/etc/uci-defaults/01-passwd
#echo "uci set network.lan.ipaddr='10.10.10.1'" >files/etc/uci-defaults/02-network
#echo "uci commit network" >>files/etc/uci-defaults/02-network
echo "uci set dropbear.@dropbear[0].Interface='lan'" >files/etc/uci-defaults/03-dropbear
echo "uci commit dropbear" >>files/etc/uci-defaults/03-dropbear
echo "uci set uhttpd.main.redirect_https='1'" >files/etc/uci-defaults/04-uhttpd
echo "uci commit uhttpd" >>files/etc/uci-defaults/04-uhttpd
echo "uci set wireless.radio0.disabled='0'" >files/etc/uci-defaults/05-wireless
echo "uci commit wireless" >>files/etc/uci-defaults/05-wireless

## build images
if [[ -z $mod ]]; then
  if [[ ! -f .profiles.mk ]]; then make info &>/dev/null; fi
  echo
  PS3="Select router make: "
  select b in $(cat .profiles.mk | grep "DEVICE_.*NAME" | cut -d '_' -f2 | sort -u); do break; done
  echo
  PS3="Select router model: "
  select r in $(cat .profiles.mk | grep "DEVICE_$b.*NAME" | cut -d '_' -f3); do break; done
  mod=$b"_"$r
fi
make image PROFILE="$mod" PACKAGES="$opk" FILES="files" || exit $?

## copy sysupgrade.bin
cp -u $(find bin/ -name *sysupgrade.bin) ../
cd ..
exit 0
