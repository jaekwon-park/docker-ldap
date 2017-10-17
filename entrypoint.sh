#!/bin/bash

function file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}


function fail {
	echo "ERROR: $1" >&2
	exit 1
}

function odbc_configure {
  cat << EOF > /etc/odbc.ini 
[openldap]
Description         = LdapToMysql
Driver              = MySQL
Trace               = No
Database            = $LDAP_MYSQL_DB
Server              = $LDAP_MYSQL_SERVER
User                = $LDAP_MYSQL_USER
Password            = $LDAP_MYSQL_PASS
Port                = 3306
ReadOnly            = No
RowVersioning       = No
ShowSystemTables    = No
ShowOidColumn       = No
FakeOidIndex        = No
EOF

  cat << EOF > /etc/odbcinst.ini
[MySQL]
Description     = ODBC for MySQL
Driver          = /usr/lib/odbc/libmyodbc.so
FileUsage       = 1
EOF

  cat << EOF > /usr/local/etc/openldap/slapd.conf
# $OpenLDAP$
#
# See slapd.conf(5) for details on configuration options.
# This file should NOT be world readable.
#
include         /usr/local/etc/openldap/schema/core.schema
include         /usr/local/etc/openldap/schema/cosine.schema
include         /usr/local/etc/openldap/schema/inetorgperson.schema
 
# Define global ACLs to disable default read access.
 
# Do not enable referrals until AFTER you have a working directory
# service AND an understanding of referrals.
#referral       ldap://root.openldap.org
 
pidfile         /usr/local/var/slapd.pid
argsfile        /usr/local/var/slapd.args
#######################################################################
# sql database definitions
#######################################################################
database sql
suffix          "$CONF_BASEDN"
rootdn          "cn=admin,$CONF_BASEDN"
rootpw          $CONF_ROOTPW
dbname $LDAP_MYSQL_DB
dbuser $LDAP_MYSQL_USER
dbpasswd $LDAP_MYSQL_PASS
has_ldapinfo_dn_ru no
subtree_cond "ldap_entries.dn LIKE CONCAT('%',?)"
insentry_stmt   "INSERT INTO ldap_entries (dn,oc_map_id,parent,keyval) VALUES (?,?,?,?)"
EOF
	return $?
}


# set timeout
function timeout {
	kill -KILL $dpid
	fail "Timeout stopping temporary slapd instance."
}

function kill_slapd {
	trap timeout ALRM
	sleep 5 && kill -ALRM $$ &
	# kill slapd
	kill $1
	# wait for slapd exit (or timeout)
	wait $1
	# clear timeout
	kill %+
	trap - ALRM
}

function start_slapd {
	echo "Starting temporary slapd to modify dynamic config."
	/usr/local/libexec/slapd -u openldap -g openldap -h 'ldapi:/// ldap:///' -d 1 &
	dpid=$!
	echo "strated temporary slapd. $dpid" 
}

#chown -R openldap:openldap /config /data || fail "Cannot change owner of supplied volumes."
  file_env 'CONF_BASEDN'
  file_env 'CONF_ROOTPW'
  file_env 'LDAP_MYSQL_SERVER'
  file_env 'LDAP_MYSQL_USER'
  file_env 'LDAP_MYSQL_PASS'
  file_env 'LDAP_MYSQL_DB'
	# supplied empty config volume, use defaults
	[[ -z "$CONF_ROOTPW" ]] && fail "No existing config found and CONF_ROOTPW not given."
	[[ -z "$CONF_BASEDN" ]] && fail "No existing config found and CONF_BASEDN not given."
	[[ "${CONF_ROOTPW:0:1}" == '{' ]] || CONF_ROOTPW=`slappasswd -s "$CONF_ROOTPW"`

	CONFIGURED=0
	for i in {1..10} ; do
		sleep 1
		odbc_configure && CONFIGURED=1
		[[ $CONFIGURED -eq 1 ]] && break
	done

	[[ $CONFIGURED -ne 1 ]] && fail "Unable to configure slapd (timeout?)."

echo "Starting slapd."
#exec /usr/sbin/slapd -u openldap -g openldap -h 'ldapi:/// ldap:///' -d stats #-f /etc/ldap/slapd.conf -F /config
exec /usr/local/libexec/slapd -u openldap -g openldap -h 'ldapi:/// ldap:///' -d debug -f /usr/local/etc/openldap/slapd.conf
