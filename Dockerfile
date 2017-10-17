FROM debian:jessie

MAINTAINER Jaekwon Park <jaekwon.park@code-post.com>

EXPOSE 389

# runs as user openldap(104), group openldap(107)
RUN groupadd -r openldap && useradd -r -g openldap openldap

RUN apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ldap-utils libmyodbc libssl-dev libdb-dev unixodbc-dev time wget build-essential \
  openssl  && \
  wget ftp://ftp.openldap.org/pub/OpenLDAP/openldap-release/openldap-2.4.26.tgz -O /tmp/openldap-2.4.26.tgz && \
  tar xvfz /tmp/openldap-2.4.26.tgz -C /tmp/ && cd /tmp/openldap-2.4.26 && ./configure --enable-sql && make depend && make && make install && \
  rm -rf /tmp/openldap* && apt-get purge -y -q --auto-remove  wget build-essential && \
	apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \ 
COPY entrypoint.sh /
RUN chmod 0755 /entrypoint.sh && chown -R openldap:openldap /usr/local/etc/openldap && chown -R openldap:openldap /usr/local/var/
CMD ["/entrypoint.sh"]
