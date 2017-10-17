FROM debian:jessie

MAINTAINER Jaekwon Park <jaekwon.park@code-post.com>

EXPOSE 389

# runs as user openldap(104), group openldap(107)
RUN groupadd -r openldap && useradd -r -g openldap openldap

RUN apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ldap-utils libmyodbc libssl-dev libdb-dev unixodbc-dev time wget\
  libsasl2-modules \
  libsasl2-modules-db \
  libsasl2-modules-gssapi-mit \
  libsasl2-modules-ldap \
  libsasl2-modules-otp \
  libsasl2-modules-sql \
  openssl \
	&& apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN wget ftp://ftp.openldap.org/pub/OpenLDAP/openldap-release/openldap-2.4.26.tgz -O /tmp/openldap-2.4.26.tgz && \
tar xvfz /tmp/openldap-2.4.26.tgz && cd /tmp/openldap-2.4.26 && ./configure --enable-sql && make depeend && make && make install && \
rm -rf /tmp/openldap*
COPY entrypoint.sh /
RUN chmod 0755 /entrypoint.sh 
CMD ["/entrypoint.sh"]
