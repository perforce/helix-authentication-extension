FROM ubuntu:18.04

ARG BASE_PATH
ARG PUB_KEY
ARG APT_URL
ARG P4PORT

#
# install p4 and swarm using packages
#
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && \
    apt-get -q -y install apt-utils lsb-release gnupg curl
ADD ${PUB_KEY} perforce.pubkey
RUN apt-key add perforce.pubkey && \
    rm -f perforce.pubkey
RUN echo "deb ${APT_URL} $(lsb_release -sc) release" > /etc/apt/sources.list.d/perforce.sources.list
RUN apt-get update && \
    apt-get -q -y install helix-cli helix-swarm

RUN /opt/perforce/swarm/sbin/configure-swarm.sh -n -p ${P4PORT} -u swarm -w Rebar123 -H swarm.doc -e localhost -f
RUN mkdir -p /opt/perforce/swarm/data/queue/tokens && \
    touch /opt/perforce/swarm/data/queue/tokens/00000000-0000-0000-0000-000000000000 && \
    chown -R www-data:www-data /opt/perforce/swarm/data

RUN a2enmod ssl
RUN mkdir -p /etc/apache2/ssl && \
    chmod 600 /etc/apache2/ssl && \
    cd /etc/apache2/ssl && \
    openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096 -keyout apache.key -out apache.crt -subj "/CN=swarm.doc"

WORKDIR /swarm

#
# perform the initial setup of the swarm instance
#
COPY $BASE_PATH/config.php /opt/perforce/swarm/data/config.php.template
COPY $BASE_PATH/swarm-site.conf /etc/apache2/sites-available/perforce-swarm-site.conf

USER root
COPY $BASE_PATH/run.sh .
EXPOSE 80
EXPOSE 8043
# allow for non-successful responses since Swarm typically responds with 401
HEALTHCHECK CMD curl -s -I http://localhost:80/swarm/ || exit 1
ENTRYPOINT [ "./run.sh" ]
