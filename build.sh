#!/bin/bash

## place any additional packages in the same directory as this build script

## address of imagebuilder package or comment out to chose later
url='https://downloads.openwrt.org/releases/23.05.5/targets/ramips/mt7621/openwrt-imagebuilder-23.05.5-ramips-mt7621.Linux-x86_64.tar.xz'

## model of router to build for or comment out to chose later
mod='zbtlink_zbt-we1326'

## set a default password and dropbear key or comment out to leave blank
pas='password'
key='ssh-rsa'

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
socat'

## set TTL for celular data or comment out to diable
ttl='65'

## command to reboot the cellular modem or comment out to diable
wac='echo -e "AT+CFUN=1,1" >/dev/ttyUSB2'

## schedule tasks or comment out the next line to disable
crn='yes'
tasks() { cat <<EOT
"59 7 * * 1 sleep 70 && touch /etc/banner && reboot"
EOT
}

## set uci defaults
deflist() { cat <<EOT
uci set system.@system[0].hostname=''

uci set network.lan.ipaddr=''
uci add_list network.lan.dns='208.67.222.123'
uci add_list network.lan.dns='208.67.220.123'
uci set network.lan.delegate='0'
uci delete network.lan.ip6assign
uci set network.mobile='interface'
uci set network.mobile.proto='qmi'
uci set network.mobile.device='/dev/cdc-wdm0'
uci set network.mobile.apn=''
uci set network.mobile.auth='none'
uci set network.mobile.pdptype='ipv4'
uci set network.mobile.peerdns='0'
uci add_list network.mobile.dns='208.67.222.123'
uci add_list network.mobile.dns='208.67.220.123'
uci set network.wg0=interface
uci set network.wg0.proto='wireguard'
uci set network.wg0.private_key=''
uci set network.wg0.mtu='1340'
uci add_list network.wg0.addresses=''
uci add_list network.wg0.addresses=''
uci add network wireguard_wg0
uci set network.@wireguard_wg0[0].description=''
uci set network.@wireguard_wg0[0].public_key=''
uci set network.@wireguard_wg0[0].private_key=''
uci set network.@wireguard_wg0[0].preshared_key=''
uci set network.@wireguard_wg0[0].endpoint_host=''
uci set network.@wireguard_wg0[0].endpoint_port='51820'
uci set network.@wireguard_wg0[0].persistent_keepalive='25'
uci add_list network.@wireguard_wg0[0].allowed_ips=''

uci add_list firewall.@zone[0].network='wg0'
uci add_list firewall.@zone[1].network='mobile'

uci add dhcp host
uci set dhcp.@host[0].name=''
uci set dhcp.@host[0].ip=''
uci set dhcp.@host[0].mac=''
uci add dhcp host
uci set dhcp.@host[1].name=''
uci set dhcp.@host[1].ip=''
uci set dhcp.@host[1].mac=''

uci set wireless.radio0.disabled='0'
uci set wireless.radio0.country='US'
uci set wireless.default_radio0.ssid=''
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio0.key=''
uci set wireless.radio1.disabled='0'
uci set wireless.radio1.country='US'
uci set wireless.default_radio1.ssid=''
uci set wireless.default_radio1.encryption='psk2'
uci set wireless.default_radio1.key=''

uci set watchcat.@watchcat[0].period='5m'
uci set watchcat.@watchcat[0].mode='run_script'
uci set watchcat.@watchcat[0].pinghosts='1.1.1.1'
uci set watchcat.@watchcat[0].script='/usr/share/watchcat/restart.sh'
uci set watchcat.@watchcat[0].addressfamily='ipv4'
uci set watchcat.@watchcat[0].pingperiod='1m'
uci set watchcat.@watchcat[0].pingsize='standard'
uci set watchcat.@watchcat[0].interface='wwan0'
EOT
}

# check for and install dependencies
dep="build-essential curl file gawk gettext git libncurses-dev libssl-dev pup python3 python3-distutils rsync unzip wget xsltproc zlib1g-dev"
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
[[ ! -f "$f" ]] && (wget "$url" || exit $?)
d="${f%.tar.xz}"
[[ -d "$d" ]] || tar -J -x -f "$f"
cd "$d"
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
if [[ -n $wac ]]; then
  mkdir -p files/usr/share/watchcat
  cat >files/usr/share/watchcat/restart.sh <<EOT
#!/bin/sh
$wac
exit 0
EOT
  chmod +x files/usr/share/watchcat/restart.sh
fi
if [[ $crn == "yes" ]]; then
  mkdir -p files/etc/crontabs
  tasks >files/etc/crontabs/root
fi

# copy packages
mkdir -p packages
cp -u ../*.ipk packages/ 

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
pgrep -x python3 >/dev/null && kill $(pgrep -x python3)
cd bin/targets/"$a"/"$c"
nohup python3 -m http.server &>/dev/null &
echo
echo "Files can be downloaded from http://$(hostname -I | awk '{print $1}'):8000"
echo
exit 0
