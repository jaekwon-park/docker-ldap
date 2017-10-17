/bin/bash

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

function odbc_configure {
  cat << EOF > /etc/odbc.ini 
[ldap]
Description = LdapToMysql
Driver = MySQL
Database = ldap
Server = $LDAP_MYSQL_SERVER
User = $LDAP_MYSQL_USER
Password = $LDAP_MYSQL_PASS
Port = 3306
EOF 

  cat << EOF > /etc/ldap/slapd.conf
#######################################################################
# sql database definitions
#######################################################################
database sql
# Only need if not using the ldbm/bdb stuff below
dbname $LDAP_MYSQL_DB
dbuser $LDAP_MYSQL_USER
dbpasswd $LDAP_MYSQL_PASS
has_ldapinfo_dn_ru no
subtree_cond "ldap_entries.dn LIKE CONCAT('%',?)"
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
	/usr/sbin/slapd -F /config -u openldap -g openldap -h 'ldapi:/// ldap:///' -d 1 &
	dpid=$!
	echo "strated temporary slapd. $dpid" 
}

chown -R openldap:openldap /config /data || fail "Cannot change owner of supplied volumes."

if [[ ! -d '/config/cn=config' ]] ; then
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
	cp -a /etc/ldap/slapd.d/. /config/
	start_slapd

	CONFIGURED=0
	for i in {1..10} ; do
		sleep 1
		configure && odbc_configure && CONFIGURED=1
		[[ $CONFIGURED -eq 1 ]] && break
	done

	[[ $CONFIGURED -ne 1 ]] && fail "Unable to configure slapd (timeout?)."
	echo "Stopping temporary slapd."
	kill_slpad $dpid
fi

echo "Starting slapd."
exec /usr/sbin/slapd -u openldap -g openldap -h 'ldapi:/// ldap:///' -d stats #-f /etc/ldap/slapd.conf -F /config
