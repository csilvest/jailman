#!/usr/local/bin/bash
# shellcheck disable=SC1003

jailcreate() {
	local jail  plugin

	jail=${1:?}
	plugin=${2:?}

	if [ -z "$jail" ] || [ -z "$plugin" ]; then
		echo "jail and plugin are required"
		exit 1
	fi

	# shellcheck disable=SC2143
	if [ -z "$(iocage list -q | grep "${jail}")" ]; then
		echo ""
	else
		echo "Jail ${jail} already exists..."
		exit 1
	fi

	echo "Checking config..."
	local pluginrepo pluginports jailinterfaces jailip4 jailgateway jaildhcp setdhcp pluginextraconf jailextraconf setextra reqvars reqvars version
	
	pluginrepo="https://github.com/jailmanager/iocage-plugins.git"
	pluginports="plugin_${plugin}_ports"
	jailinterfaces="jail_${jail}_interfaces"
	jailip4="jail_${jail}_ip4_addr"
	jailgateway="jail_${jail}_gateway"
	jaildhcp="jail_${jail}_dhcp"
	setdhcp=${!jaildhcp:-}
	pluginextraconf="plugin_${plugin}_custom_iocage"
	jailextraconf="jail_${jail}_custom_iocage"
	setextra="${!pluginextraconf:-}${!jailextraconf:+ ${!jailextraconf}}"
	
	version="$(freebsd-version | sed "s/STABLE/RELEASE/g" | sed "s/-p[0-9]*//")"




	if [ -z "${!jailinterfaces:-}" ]; then
		jailinterfaces="vnet0:bridge0"
	else
		jailinterfaces=${!jailinterfaces}
	fi
if [ -z "${setdhcp}" ] && [ -z "${!jailip4}" ] && [ -z "${!jailgateway}" ]; then
		echo 'no network settings specified in config.yml, defaulting to dhcp="on"'
		setdhcp="on"
	fi

	echo "Creating jail for $jail"
	if [ "${setdhcp}" == "on" ] || [ "${setdhcp}" == "override" ]
	then
		if !  iocage fetch -g "${pluginrepo}" -P "${plugin}" -n "${jail}" -r "${version}" interfaces="${jailinterfaces}" dhcp="on" vnet="on" allow_raw_sockets="1" boot="on" ${setextra:+"$setextra"}
		then
			echo "Failed to create jail"
			exit 1
		fi
	else
		if !  iocage fetch -g "${pluginrepo}" -P "${plugin}" -n "${jail}" -r "${version}" interfaces="${jailinterfaces}" ip4_addr="vnet0|${!jailip4}" defaultrouter="${!jailgateway}" vnet="on" allow_raw_sockets="1" boot="on" ${setextra:+"$setextra"}
		then
			echo "Failed to create jail"
			exit 1
		fi
	fi
	
	for reqvar in $(jq -r '.jailman | .variables | .required | .[]' "${global_dataset_iocage}/jails/${jail}/${plugin}.json")
	do
		varname=jail_${jail}_${reqvar}
		if [ -z "${!varname:-}" ]; then
			echo "$varname can't be empty"
			exit 1
		fi
	done
	
	echo "creating jail config directory"
	createmount "${jail}" "${global_dataset_config}" || exit 1
	createmount "${jail}" "${global_dataset_config}"/"${jail}" /config || exit 1

	# Create and Mount portsnap
	createmount "${jail}" "${global_dataset_config}"/portsnap || exit 1
	createmount "${jail}" "${global_dataset_config}"/portsnap/db /var/db/portsnap || exit 1
	createmount "${jail}" "${global_dataset_config}"/portsnap/ports /usr/ports || exit 1
	if [ "${!pluginports:-}" == "true" ]
	then
		echo "Mounting and fetching ports"
		iocage exec "${jail}" "if [ -z /usr/ports ]; then portsnap fetch extract; else portsnap auto; fi"
	else
		echo "Ports not enabled for plugin, skipping"
	fi

	echo "Jail creation completed for ${jail}"
}

createmount() {
	local jail dataset mountpoint fstab

	jail=${1:-}
	dataset=${2:-}
	mountpoint=${3:-}
	fstab=${4:-}

	if [ -z "${dataset}" ] ; then
		echo "ERROR: No Dataset specified to create and/or mount"
		exit 1
	else
		if [ ! -d "/mnt/${dataset}" ]; then
			echo "Dataset does not exist... Creating... ${dataset}"
			zfs create "${dataset}" || exit 1
		else
			echo "Dataset already exists, skipping creation of ${dataset}"
		fi

		if [ -n "${jail}" ] && [ -n "${mountpoint}" ]; then
			iocage exec "${jail}" mkdir -p "${mountpoint}"
			if [ -n "${fstab}" ]; then
				if ! iocage fstab -a "${jail}" /mnt/"${dataset}" "${mountpoint}" "${fstab}"; then
					echo "ERR creating mount. jail=${jail} dataset=${dataset} mountpoint=${mountpoint} fstab=${fstab}"
					exit 1
				fi
			else
				if ! iocage fstab -a "${jail}" /mnt/"${dataset}" "${mountpoint}" nullfs rw 0 0; then
					echo "ERR creating mount. jail=${jail} dataset=${dataset} mountpoint=${mountpoint}"
					exit 1
				fi
			fi
		else
			echo "No Jail Name or Mount target specified, not mounting dataset"
		fi

	fi
}
export -f createmount