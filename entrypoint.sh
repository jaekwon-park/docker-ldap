#!/bin/bash

function fail {
	echo "ERROR: $1" >&2
	exit 1
}

function configure {
	ldapmodify -Y EXTERNAL -H ldapi:/// <<-_EOF
		dn: olcDatabase={1}mdb,cn=config
		replace: olcRootPW
		olcRootPW: $CONF_ROOTPW
		-
		replace: olcSuffix
		olcSuffix: $CONF_BASEDN
		-
		replace: olcRootDN
		olcRootDN: cn=admin,$CONF_BASEDN

		dn: olcDatabase={0}config,cn=config
		replace: olcRootPW
		olcRootPW: $CONF_ROOTPW
		_EOF
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
	/usr/sbin/slapd -F /config -u openldap -g openldap -h 'ldapi:/// ldap:///' -u openldap -g openldap  -d 255 &
	dpid=$!
	echo "strated temporary slapd. $dpid" 
}


chown -R 104:107 /config /data || fail "Cannot change owner of supplied volumes."

if [[ ! -d '/config/cn=config' ]] ; then
	# supplied empty config volume, use defaults
	[[ -z "$CONF_ROOTPW" ]] && fail "No existing config found and CONF_ROOTPW not given."
	[[ -z "$CONF_BASEDN" ]] && fail "No existing config found and CONF_BASEDN not given."
	[[ "${CONF_ROOTPW:0:1}" == '{' ]] || CONF_ROOTPW=`slappasswd -s "$CONF_ROOTPW"`
	cp -a /etc/ldap/slapd.d/. /config/
	start_slapd

	CONFIGURED=0
	for i in {1..10} ; do
		sleep 1
		configure && CONFIGURED=1
		[[ $CONFIGURED -eq 1 ]] && break
	done
	[[ $CONFIGURED -ne 1 ]] && fail "Unable to configure slapd (timeout?)."
	echo "Stopping temporary slapd."
	kill_slpad $dpid
fi

echo "Starting slapd."
exec /usr/sbin/slapd -F /config -u openldap -g openldap -h 'ldapi:/// ldap:///' -d stats
