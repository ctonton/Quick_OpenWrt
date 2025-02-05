#!/bin/bash

## place any additional packages in a directory named "packages"
## Place configuration files with their correct directory structure inside of a directory named "files"

## host files after build or comment out to disable
#hst='yes'

## address of imagebuilder package or comment out to chose later
url='https://downloads.openwrt.org/releases/23.05.5/targets/ramips/mt7621/openwrt-imagebuilder-23.05.5-ramips-mt7621.Linux-x86_64.tar.xz'

## model of router to build for or comment out to chose later
mod='zbtlink_zbt-we1326'

## set a default password or comment out to leave blank
pas='password'

## custom repository to pull packages from or comment out to disable
rep='src/gz IceG_repo https://github.com/4IceG/Modem-extras/raw/main/myrepo'

## packages to install
opk='\
block-mount \
kmod-fs-exfat \
kmod-fs-ext4 \
kmod-fs-vfat \
kmod-fs-xfs \
kmod-usb2 \
kmod-usb3 \
kmod-usb-net-qmi-wwan \
kmod-usb-serial-option \
kmod-usb-serial-qualcomm \
kmod-usb-storage \
luci \
luci-app-3ginfo-lite \
luci-app-ksmbd \
luci-app-modemband \
luci-app-opkg \
luci-app-sms-tool-js \
luci-app-watchcat \
luci-proto-qmi \
luci-proto-wireguard \
nano \
ntfs-3g \
socat \
usbutils'

## set TTL for celular data or comment out to disable
ttl='65'

## watchcat script to restart the cellular modem or comment out the next line to disable
wac='yes'
rstart() { cat <<EOT
#!/bin/sh
ping -c1 1.1.1.1 &>/dev/null && exit 0
ping -c1 8.8.8.8 &>/dev/null && exit 0
echo '1-2' >/sys/bus/usb/drivers/usb/unbind
sleep 2
echo '1-2' >/sys/bus/usb/drivers/usb/bind
sleep 90
ping -c1 1.1.1.1 &>/dev/null && exit 0
ping -c1 8.8.8.8 &>/dev/null && exit 0
[ ! -f /usr/share/watchcat/log ] && echo "0" >/usr/share/watchcat/log
if [ $(date +%s) -lt $(( $(cat /usr/share/watchcat/log) + 600 )) ]; then
  service watchcat stop
  exit 0
else
  date +%s >/usr/share/watchcat/log 
  reboot
fi
EOT
}

## schedule tasks or comment out the next line to disable
crn='yes'
tasks() { cat <<EOT
59 7 * * 1 /bin/sleep 70 && /bin/touch /etc/banner && /sbin/reboot
0 */6 * * * /sbin/service watchcat running || /sbin/service watchcat start
EOT
}

## set uci defaults
deflist() { cat <<EOT
uci set system.@system[0].hostname=''
uci set wireless.radio0.disabled='0'
uci set wireless.radio0.country='US'
uci set wireless.radio1.disabled='0'
uci set wireless.radio1.country='US'
EOT
}

# check for and install dependencies
dep="build-essential curl file gawk gettext git libncurses-dev libssl-dev pup python3 python3-distutils rsync unzip wget xsltproc zlib1g-dev zstd"
for p in $dep; do dpkg -l "$p" 2>/dev/null | grep -q '^ii' || i=1; done
[[ $i -eq 1 ]] && (sudo apt update; sudo apt install -y $dep || exit $?)

# download and extract imagebuilder package
if [[ -n $url ]]; then
  a="$(echo $url | cut -d '/' -f7)"
  c="$(echo $url | cut -d '/' -f8)"
  f="${url##*/}"
else
  echo
  PS3="Select openwrt version: "
  select v in $(curl -s https://downloads.openwrt.org/releases/ | pup 'tr td a text{}' | grep '^[0-9]') snapshots; do break; done
  [[ $v == "snapshots" ]] && r="$v" || r="releases/$v"
  echo
  PS3="Select arch target: "
  select a in $(curl -s https://downloads.openwrt.org/"$r"/targets/ | pup 'tr a text{}'); do break; done
  echo
  PS3="Select chip model: "
  select c in $(curl -s https://downloads.openwrt.org/"$r"/targets/"$a"/ | pup 'tr a text{}'); do break; done
  f=$(curl -s https://downloads.openwrt.org/"$r"/targets/"$a"/"$c"/ | pup 'tr a text{}' | grep 'imagebuilder')
  url=https://downloads.openwrt.org/"$r"/targets/"$a"/"$c"/"$f"
fi
[[ -f "$f" ]] || (wget "$url" || exit $?)
d="${f%.tar.*}"
[[ -d "$d" ]] || tar -axf "$f"
cd "$d"
if [[ -n $rep ]]; then
  sed -i 's/^option/#option/' repositories.conf
  [[ $(grep "$rep" repositories.conf) ]] || echo $rep >>repositories.conf
fi
rm -rf bin files

# write defaults
mkdir -p files/etc/uci-defaults
deflist >files/etc/uci-defaults/90-defaults
echo "uci commit" >>files/etc/uci-defaults/90-defaults
[[ -n $pas ]] && cat >files/etc/uci-defaults/99-password <<EOT
echo -e "$pas\n$pas" | passwd root
EOT
[[ -n $key ]] && cat >>files/etc/uci-defaults/99-password <<EOT
echo $key >/etc/dropbear/authorized_keys
chmod 600 /etc/dropbear/authorized_keys
EOT
if [[ -n $ttl ]]; then
  mkdir -p files/usr/share/nftables.d/chain-pre/mangle_postrouting
  echo "ip ttl set $ttl" >files/usr/share/nftables.d/chain-pre/mangle_postrouting/01-set-ttl.nft
  echo "ip6 hoplimit set $ttl" >>files/usr/share/nftables.d/chain-pre/mangle_postrouting/01-set-ttl.nft
fi
if [[ $wac == "yes" ]]; then
  mkdir -p files/usr/share/watchcat
  rstart >>files/usr/share/watchcat/restart.sh
  chmod +x files/usr/share/watchcat/restart.sh
fi
if [[ $crn == "yes" ]]; then
  mkdir -p files/etc/crontabs
  tasks >files/etc/crontabs/root
fi

# copy packages
mkdir -p packages
cp -uf ../*.ipk packages/ 2>/dev/null

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
make image PROFILE="$mod" PACKAGES="$opk" FILES="files" || exit $?

# host new files
cp -uf bin/targets/"$a"/"$c"/* ../
if [[ $hst == "yes" ]]; then
  [[ $(pgrep -x python3) ]] && kill $(pgrep -x python3)
  cd bin/targets/"$a"/"$c"
  nohup python3 -m http.server &>/dev/null &
  echo
  echo "Files can be downloaded from http://$(hostname -I | awk '{print $1}'):8000"
  echo
fi
exit 0
