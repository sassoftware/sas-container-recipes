#!/bin/bash

###############################################################################
# Variables
###############################################################################

line='-------------------------------------------------------------------------------'

_CURRENT_USER=$(whoami)
_CURRENT_USER_GROUP=$(id -Gn $_CURRENT_USER)
_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_WORKING_DIR=$PWD

_TENANT="viya"
_SASROOT=/opt/sas
_INSTANCE="default"

###############################################################################
# Functions
###############################################################################

function echo_line {
    line_out="$(date) - $1"
    printf "%s\n" "$line_out"
}

###############################################################################
# Defaults
###############################################################################

###############################################################################
# Process inputs
###############################################################################


echo_line $line
while [ "$#" -gt 0 ]
do
    if [ "$1" = "--file" ]; then
        shift
        _CONFIG_FILE="$1"
    elif [ "$1" = "--tenant" ]; then
        shift
        _TENANT="$1"
    elif [ "$1" = "--tenant-admin" ]; then
        shift
        _TENANT_ADMIN="$1"
    elif [ "$1" = "--tenant-admin-group" ]; then
        shift
        _TENANT_ADMIN_GROUP="$1"
    elif [ "$1" = "-r" ]; then
        shift
        _SASROOT="$1"
    elif [ "$1" = "-h" ]; then
        shift
        usage
        echo_line $line
        exit 0
    else
        shift
    fi
done


if [ ! -z "$_CONFIG_FILE" ] && [ -e $_CONFIG_FILE ] ; then
    source ${_CONFIG_FILE}
fi

[[ ! -z ${SASROOT+x} ]]             && _SASROOT=$SASROOT
[[ ! -z ${SASTENANT+x} ]]           && _TENANT=$SASTENANT
[[ ! -z ${SASTENANTADMIN+x} ]]      && _TENANT_ADMIN=$SASTENANTADMIN
[[ ! -z ${SASTENANTADMINGROUP+x} ]] && _TENANT_ADMIN_GROUP=$SASTENANTADMINGROUP
[[ ! -z ${SASINSTANCE+x} ]]         && _INSTANCE=$SASINSTANCE

if [ -z $_TENANT_ADMIN ]; then
    _TENANT_ADMIN=${_TENANT}_admin
fi

if [ -z $_TENANT_ADMIN_GROUP ]; then
    _TENANT_ADMIN_GROUP=${_TENANT}_admin
fi

# See if lsb is installed on the host
which lsb_release
rc=$?

# if [ -f /etc/os-release ]; then
if [ "$rc" == "0" ]; then
    OS=$(lsb_release -si)
    OS_MAJOR_VER=$(lsb_release -sr | cut -d'.' -f1)
# elif [ -f /etc/debian_version ]; then
    # OS=Debian  # XXX or Ubuntu??
    # OS_MAJOR_VER=$(cat /etc/debian_version)
elif [ -f /etc/redhat-release ]; then
    OS=$(cat /etc/redhat-release | awk -F' release ' '{ print $1 }' | tr -d '[:space:]')
    OS_MAJOR_VER=$(rpm -q --queryformat '%{RELEASE}' rpm | grep -o [[:digit:]]*\$)
else
    OS=$(uname -s)
    OS_MAJOR_VER=$(uname -r | grep -Po 'el\K[^.]+')
fi


echo_line "Variable check "
echo_line ""
echo_line "OS                                        = '${OS}'"
echo_line "OS Version                                = '${OS_MAJOR_VER}'"
echo_line "User                                      = ${_CURRENT_USER}"
echo_line "Location of script                        = ${_SCRIPT_DIR}"
echo_line "Current dir                               = ${_WORKING_DIR}"
echo_line "SAS root                                  = ${_SASROOT}"
echo_line "SAS instance id                           = ${_INSTANCE}"
echo_line "tenant (--tenant)                         = ${_TENANT}"
echo_line "tenant admin (--tenant-admin)             = ${_TENANT_ADMIN}"
echo_line "tenant admin group (--tenant-admin-group) = ${_TENANT_ADMIN_GROUP}"
echo_line ""

# tenant must be defined. There is no reasonable default
echo_line $line

###############################################################################
# Install needed packages
###############################################################################

###############################################################################
# Do the tenant specific configuration
###############################################################################

echo_line $line
echo_line "Validate that the tenant admin and group is valid"
id -u ${_TENANT_ADMIN}
_user_rc=$?
if [ $_user_rc -ne 0 ]; then
    echo_line "User \"${_TENANT_ADMIN}\" does not exist"
    exit $_user_rc
fi

getent group ${_TENANT_ADMIN_GROUP}
_group_rc=$?
if [ $_group_rc -ne 0 ]; then
    echo_line "Group \"${_TENANT_ADMIN_GROUP}\" does not exist"
    exit $_group_rc
fi
echo_line $line

echo_line $line
echo_line "Create the directories"
mkdir -p /var/run/${_TENANT}
mkdir -p ${_SASROOT}/${_TENANT}/config/etc/sysconfig
mkdir -p ${_SASROOT}/${_TENANT}/config/var/cache
mkdir -p ${_SASROOT}/${_TENANT}/config/var/lib
mkdir -p ${_SASROOT}/${_TENANT}/config/var/lock
mkdir -p ${_SASROOT}/${_TENANT}/config/var/log
mkdir -p ${_SASROOT}/${_TENANT}/config/var/tmp
mkdir -p ${_SASROOT}/${_TENANT}/config/var/spool
mkdir -p ${_SASROOT}/${_TENANT}/config/var/run
mkdir -p ${_SASROOT}/${_TENANT}/config/data/users/${_TENANT_ADMIN}
echo_line $line

echo_line $line
echo_line "Set ownership"
chown -v ${_TENANT_ADMIN}:${_TENANT_ADMIN_GROUP} /var/run/${_TENANT}
chown -v ${_TENANT_ADMIN}:${_TENANT_ADMIN_GROUP} ${_SASROOT}/${_TENANT}
chown -v ${_TENANT_ADMIN}:${_TENANT_ADMIN_GROUP} ${_SASROOT}/${_TENANT}/config
chown -v ${_TENANT_ADMIN}:${_TENANT_ADMIN_GROUP} ${_SASROOT}/${_TENANT}/config/etc
chown -v ${_TENANT_ADMIN}:${_TENANT_ADMIN_GROUP} ${_SASROOT}/${_TENANT}/config/etc/sysconfig
chown -v ${_TENANT_ADMIN}:${_TENANT_ADMIN_GROUP} ${_SASROOT}/${_TENANT}/config/var
chown -v ${_TENANT_ADMIN}:${_TENANT_ADMIN_GROUP} ${_SASROOT}/${_TENANT}/config/var/cache
chown -v ${_TENANT_ADMIN}:${_TENANT_ADMIN_GROUP} ${_SASROOT}/${_TENANT}/config/var/lib
chown -v ${_TENANT_ADMIN}:${_TENANT_ADMIN_GROUP} ${_SASROOT}/${_TENANT}/config/var/lock
chown -v ${_TENANT_ADMIN}:${_TENANT_ADMIN_GROUP} ${_SASROOT}/${_TENANT}/config/var/log
chown -v ${_TENANT_ADMIN}:${_TENANT_ADMIN_GROUP} ${_SASROOT}/${_TENANT}/config/var/tmp
chown -v ${_TENANT_ADMIN}:${_TENANT_ADMIN_GROUP} ${_SASROOT}/${_TENANT}/config/var/spool
chown -v ${_TENANT_ADMIN}:${_TENANT_ADMIN_GROUP} ${_SASROOT}/${_TENANT}/config/var/run
chown -v ${_TENANT_ADMIN}:${_TENANT_ADMIN_GROUP} ${_SASROOT}/${_TENANT}/config/data
chown -v ${_TENANT_ADMIN}:${_TENANT_ADMIN_GROUP} ${_SASROOT}/${_TENANT}/config/data/users
chown -v ${_TENANT_ADMIN}:${_TENANT_ADMIN_GROUP} ${_SASROOT}/${_TENANT}/config/data/users/${_TENANT_ADMIN}

echo_line $line

echo_line $line
echo_line "Set symlinks"
if [ ! -d ${_SASROOT}/${_TENANT}/home ]; then
    ln -s ${_SASROOT}/viya/home ${_SASROOT}/${_TENANT}/home
fi

chown -h ${_TENANT_ADMIN}:${_TENANT_ADMIN_GROUP} ${_SASROOT}/${_TENANT}/home

if [ ! -d ${_SASROOT}/${_TENANT}/config/etc/SASSecurityCertificateFramework ]; then
    ln -s ${_SASROOT}/viya/config/etc/SASSecurityCertificateFramework ${_SASROOT}/${_TENANT}/config/etc/SASSecurityCertificateFramework
fi

chown -h ${_TENANT_ADMIN}:${_TENANT_ADMIN_GROUP} ${_SASROOT}/${_TENANT}/config/etc/SASSecurityCertificateFramework
echo_line $line

echo_line $line
echo_line "Copy consul client token"
mkdir -p ${_SASROOT}/${_TENANT}/config/etc/SASSecurityCertificateFramework/tokens/consul/${_TENANT}/${_INSTANCE}
chown -v ${_TENANT_ADMIN}:${_TENANT_ADMIN_GROUP} ${_SASROOT}/${_TENANT}/config/etc/SASSecurityCertificateFramework/tokens/consul/${_TENANT}
chown -v ${_TENANT_ADMIN}:${_TENANT_ADMIN_GROUP} ${_SASROOT}/${_TENANT}/config/etc/SASSecurityCertificateFramework/tokens/consul/${_TENANT}/${_INSTANCE}
if [ -e ${_SASROOT}/viya/config/etc/SASSecurityCertificateFramework/tokens/consul/default/client.token ]; then
    cp -auv ${_SASROOT}/viya/config/etc/SASSecurityCertificateFramework/tokens/consul/default/client.token ${_SASROOT}/${_TENANT}/config/etc/SASSecurityCertificateFramework/tokens/consul/${_TENANT}/${_INSTANCE}/client.token
    chown ${_TENANT_ADMIN}:${_TENANT_ADMIN_GROUP} ${_SASROOT}/${_TENANT}/config/etc/SASSecurityCertificateFramework/tokens/consul/${_TENANT}/${_INSTANCE}/client.token
    chmod 0600 ${_SASROOT}/${_TENANT}/config/etc/SASSecurityCertificateFramework/tokens/consul/${_TENANT}/${_INSTANCE}/client.token
fi
echo_line $line

echo_line $line
echo_line "Copy the consul.conf file"
cp -uva ${_SASROOT}/viya/config/consul.conf ${_SASROOT}/${_TENANT}/config/consul.conf
chown ${_TENANT_ADMIN}:${_TENANT_ADMIN_GROUP} ${_SASROOT}/${_TENANT}/config/consul.conf
echo_line $line

###############################################################################
# Exit with success
###############################################################################

exit 0
