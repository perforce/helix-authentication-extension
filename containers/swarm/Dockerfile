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
# temporarily install swarm 2019.3 to get a working SSO login (does not do SSO
# authentication at all for any user in swarm 2020.1)
RUN apt-get update && \
    apt-get -q -y install helix-cli helix-swarm=2019.3-1914134~bionic

RUN /opt/perforce/swarm/sbin/configure-swarm.sh -n -p ${P4PORT} -u swarm -w Rebar123 -H swarm.doc -e localhost -f
RUN mkdir -p /opt/perforce/swarm/data/queue/tokens && \
    touch /opt/perforce/swarm/data/queue/tokens/00000000-0000-0000-0000-000000000000 && \
    chown -R www-data:www-data /opt/perforce/swarm/data

WORKDIR /swarm

#
# perform the initial setup of the swarm instance
#
COPY $BASE_PATH/config.php /opt/perforce/swarm/data/config.php.template

USER root
COPY $BASE_PATH/run.sh .
EXPOSE 80
EXPOSE 443
# allow for non-successful responses since Swarm typically responds with 401
HEALTHCHECK CMD curl -s -I http://localhost:80/swarm/ || exit 1
ENTRYPOINT [ "./run.sh" ]
