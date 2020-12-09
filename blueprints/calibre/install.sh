#!/usr/local/bin/bash
# This file contains the install script for calibre

iocage exec calibre mkdir -p /usr/local/etc/pkg/repos

# Change to to more frequent FreeBSD repo to stay up-to-date with calibre more.
# shellcheck disable=SC2154
cp "${SCRIPT_DIR}"/blueprints/calibre/includes/FreeBSD.conf /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/etc/pkg/repos/FreeBSD.conf


# Check if datasets for media librarys exist, create them if they do not.
# shellcheck disable=SC2154
createmount "$1" "${global_dataset_media}" /mnt/calibre
#createmount "$1" "${global_dataset_media}"/movies /mnt/media/movies
#createmount "$1" "${global_dataset_media}"/music /mnt/media/music
#createmount "$1" "${global_dataset_media}"/shows /mnt/media/shows

# Create calibre ramdisk if specified
# shellcheck disable=SC2154
if [ -z "${calibre_ramdisk}" ]; then
	echo "no ramdisk specified for calibre, continuing without ramdisk"
else
	iocage fstab -a "$1" tmpfs /tmp_transcode tmpfs rw,size="${calibre_ramdisk}",mode=1777 0 0
fi

iocage exec "$1" chown -R calibre:calibre /config

# Force update pkg to get latest calibre version
iocage exec "$1" pkg update
iocage exec "$1" pkg upgrade -y

# Add calibre user to video group for future hw-encoding support
#iocage exec "$1" pw groupmod -n video -m calibre

# Run different install procedures depending on calibre vs calibre Beta
# shellcheck disable=SC2154
if [ "$calibre_beta" == "true" ]; then
	echo "beta enabled in config.yml... using calibre beta for install"
	iocage exec "$1" sysrc "calibremediaserver_calibrepass_enable=YES"
	iocage exec "$1" sysrc calibremediaserver_calibrepass_support_path="/config"
	iocage exec "$1" chown -R calibre:calibre /usr/local/share/calibremediaserver-calibrepass/
	iocage exec "$1" service calibremediaserver_calibrepass restart
else
	echo "beta disabled in config.yml... NOT using calibre beta for install"
	iocage exec "$1" sysrc "calibre_enable=YES"
	iocage exec "$1" sysrc calibre_support_path="/config"
	iocage exec "$1" chown -R calibre:calibre /usr/local/share/calibre/
	iocage exec "$1" service calibre restart
fi

echo "Finished installing calibre"
