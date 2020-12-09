#!/usr/local/bin/bash
# This file contains the update script for calibre

# Run different update procedures depending on calibre vs calibre Beta
# shellcheck disable=SC2154
if [ "$calibre_calibrepass" == "true" ]; then
	echo "beta enabled in config.yml... using calibre beta for update..."
	iocage exec "$1" service calibremediaserver_calibrepass stop
	# calibre is updated using PKG already, this is mostly a placeholder
	iocage exec "$1" chown -R calibre:calibre /usr/local/share/calibremediaserver-calibrepass/
	iocage exec "$1" service calibremediaserver_calibrepass restart
else
	echo "beta disabled in config.yml... NOT using calibre beta for update..."
	iocage exec "$1" service calibre stop
	# calibre is updated using PKG already, this is mostly a placeholder
	iocage exec "$1" chown -R calibre:calibre /usr/local/share/calibre/
	iocage exec "$1" service calibre restart
fi





