# Quick_OpenWrt
Download, edit, and run this script on a modern Debian or Ubuntu OS to quickly and easily create custom OpenWrt builds.
The script will ask to add a password for the root user in the build. The password will be hashed and then set in "/etc/shadow" on the first boot.  If you want to leave the password blank then enter nothing for the password and the verification durring the build process.
To add or remove packages from the new build, create a file named "opkg" in the directory containing "build.sh" script and list those packages in that file.
To make changes in the configuration of the new build, create a file named "uci" in the directory containing the "build.sh" script and list the "uci" commands in that file.
Extra packages not found in the openwrt repository can be placed inside a directory named "packages" with the "build.sh" script or add a URL for an external repository in the "build.sh" script itself by editing the section labeled "## custom repository to pull packages from or comment out to disable".
Any extra files, scripts, configurations, etc. that you want included in the new build can be placed inside a directory named "files" with the "build.sh" script.  Those files need to be structured within directories exactly like where they are to be added to system.

Download
```shell
wget "https://github.com/ctonton/Quick_OpenWrt/raw/main/build.sh" && chmod +x build.sh
```

Edit
```shell
nano build.sh
```

Run
```shell
bash build.sh
```

For more information about using the Image Builder, visit https://openwrt.org/docs/guide-user/additional-software/imagebuilder
