#!/bin/sh

#############################
# Linux Installation #
#############################

# Define the root directory to /home/container.
# We can only write in /home/container and /tmp in the container.
ROOTFS_DIR=/home/container

export PATH=$PATH:~/.local/usr/bin


max_retries=50
timeout=1


# Detect the machine architecture.
ARCH=$(uname -m)

# Check machine architecture to make sure it is supported.
# If not, we exit with a non-zero status code.
if [ "$ARCH" = "x86_64" ]; then
  ARCH_ALT=amd64
elif [ "$ARCH" = "aarch64" ]; then
  ARCH_ALT=arm64
else
  printf "Unsupported CPU architecture: ${ARCH}"
  exit 1
fi

# Download & decompress the Linux root file system if not already installed.

if [ ! -e $ROOTFS_DIR/.installed ]; then
echo "* [0] Debian"
echo "* [1] Ubuntu"
echo ""
echo "Enter OS (0-1)"

read -p "Enter OS (0-1): " input

case $input in

    0)
    wget --tries=$max_retries --timeout=$timeout --no-hsts -O /tmp/rootfs.tar.xz \
    "https://github.com/termux/proot-distro/releases/download/v3.10.0/debian-${ARCH}-pd-v3.10.0.tar.xz"
    apt download xz-utils
    deb_file=$(find $ROOTFS_DIR -name "*.deb" -type f)
    dpkg -x $deb_file ~/.local/
    rm "$deb_file"
    
    tar -xJf /tmp/rootfs.tar.xz -C $ROOTFS_DIR;;

    1)
    wget --tries=$max_retries --timeout=$timeout --no-hsts -O /tmp/rootfs.tar.gz \
    "http://cdimage.ubuntu.com/ubuntu-base/releases/20.04/release/ubuntu-base-20.04.4-base-${ARCH_ALT}.tar.gz"

    tar -xf /tmp/rootfs.tar.gz -C $ROOTFS_DIR;;


esac

fi

echo "Please Input a password for the code server > "
read -p "Please Input a password for the code server > " password



################################
# Package Installation & Setup #
################################

# Download static APK-Tools temporarily because minirootfs does not come with APK pre-installed.
if [ ! -e $ROOTFS_DIR/.installed ]; then
    # Download the packages from their sources
    mkdir $ROOTFS_DIR/usr/local/bin -p

    wget --tries=$max_retries --timeout=$timeout --no-hsts -O $ROOTFS_DIR/usr/local/bin/proot "https://raw.githubusercontent.com/dxomg/vpsfreepterovm/main/proot-${ARCH}"

  while [ ! -s "$ROOTFS_DIR/usr/local/bin/proot" ]; do
      rm $ROOTFS_DIR/usr/local/bin/proot -rf
      wget --tries=$max_retries --timeout=$timeout --no-hsts -O $ROOTFS_DIR/usr/local/bin/proot "https://raw.githubusercontent.com/dxomg/vpsfreepterovm/main/proot-${ARCH}"
  
      if [ -s "$ROOTFS_DIR/usr/local/bin/proot" ]; then
          # Make PRoot executable.
          chmod 755 $ROOTFS_DIR/usr/local/bin/proot
          break  # Exit the loop since the file is not empty
      fi
      
      chmod 755 $ROOTFS_DIR/usr/local/bin/proot
      sleep 1  # Add a delay before retrying to avoid hammering the server
  done
  
  chmod 755 $ROOTFS_DIR/usr/local/bin/proot

fi

# Clean-up after installation complete & finish up.
if [ ! -e $ROOTFS_DIR/.installed ]; then
    # Add DNS Resolver nameservers to resolv.conf.
    printf "nameserver 1.1.1.1\nnameserver 1.0.0.1" > ${ROOTFS_DIR}/etc/resolv.conf
    # Wipe the files we downloaded into /tmp previously.
    rm -rf /tmp/rootfs.tar.xz /tmp/sbin
	
	
	mkdir -p $ROOTFS_DIR/.config/code-server/
	
	echo "bind-addr: 0.0.0.0:${SERVER_PORT}" > "$ROOTFS_DIR/.config/code-server/config.yaml"
	echo "auth: password" >> "$ROOTFS_DIR/.config/code-server/config.yaml"
	echo "password: ${password}" >> "$ROOTFS_DIR/.config/code-server/config.yaml"
	echo "cert: false" >> "$ROOTFS_DIR/.config/code-server/config.yaml"
	
	$ROOTFS_DIR/usr/local/bin/proot -S . /bin/sh -c "apt update && apt install curl -y && curl -fsSL https://code-server.dev/install.sh | sh"
	
    # Create .installed to later check whether Alpine is installed.
    touch $ROOTFS_DIR/.installed
fi


###########################
# Start PRoot environment #
###########################

# This command starts PRoot and binds several important directories
# from the host file system to our special root file system.

$ROOTFS_DIR/usr/local/bin/proot -S . /bin/sh -c "code-server"

#$ROOTFS_DIR/usr/local/bin/proot \
#--rootfs="${ROOTFS_DIR}" \
#-0 -w "/root" -b /dev -b /sys -b /proc -b /etc/resolv.conf --kill-on-exit
