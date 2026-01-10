# Quick_OpenWrt
Download, edit, and run this script on a modern Debian or Ubuntu OS to quickly and easily create custom OpenWrt builds.  Upon completion, resulting files and images will be copied to a directory named "bin" within the directory containing the "build.sh" script.

The desired system to build for can be set inside the "build.sh" by editing the respective sections labeled in the script itself.  If those sections are not set, or set incorrectly, the script will list options and ask for you to decide when it is run.  It will then populate the respective sections with the answers that you chose as defaults for subsequent building. 

The script will ask to add a password for the root user in the build. The password will be hashed and then set in "/etc/shadow" on the first boot.  If you want to leave the password blank then enter nothing for the password and the verification during the build process.

To add or remove packages from the new build, create a file named "opkg" in the directory containing "build.sh" script and list those packages in that file.

To make changes in the configuration of the new build, create a file named "uci" in the directory containing the "build.sh" script and list the "uci" commands in that file.

Extra packages not found in the OpenWrt repository can be placed inside a directory named "packages" within the directory containing the "build.sh" script or add a URL for an external repository to the "build.sh" script itself by editing the section labeled "## custom repository to pull packages from or comment out to disable".

Any extra files, scripts, configurations, etc. that you want included in the new build can be placed inside a directory named "files" within the directory containing the "build.sh" script.  Those files need to be structured within directories exactly like where they are to be added to the new system.


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
