FROM ubuntu:16.04

MAINTAINER Jaekwon Park <jaekwon.park@code-post.com>

EXPOSE 389

# runs as user openldap(104), group openldap(107)
RUN groupadd -r openldap && useradd -r -g openldap openldap

RUN apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends slapd ldap-utils libmyodbc \
  libsasl2-modules \
  libsasl2-modules-db \
  libsasl2-modules-gssapi-mit \
  libsasl2-modules-ldap \
  libsasl2-modules-otp \
  libsasl2-modules-sql \
  openssl \
	&& apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
COPY entrypoint.sh /
RUN chmod 0755 /entrypoint.sh \
	&& rm -r /var/lib/ldap \
	&& mkdir /config \
	&& mkdir /data \
	&& chown openldap:openldap /config /data \
	&& ln -s /data /var/lib/ldap
VOLUME /data
VOLUME /config
CMD ["/entrypoint.sh"]
