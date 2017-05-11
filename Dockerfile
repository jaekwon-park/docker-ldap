FROM phusion/baseimage:0.9.15
MAINTAINER Jaekwon Park <jaekwon.park@code-post.com>

EXPOSE 389

# runs as user openldap(104), group openldap(107)

RUN apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends slapd ldap-utils \
	&& apt-get clean && rm -rf /var/lib/apt/lists/*
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
