FROM ubuntu:18.04

ARG BASE_PATH
ARG PUB_KEY
ARG APT_URL
ARG P4PORT

#
# install p4 and p4d using packages
#
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && \
    apt-get -q -y install apt-utils lsb-release gnupg
ADD ${PUB_KEY} perforce.pubkey
RUN apt-key add perforce.pubkey && \
    rm -f perforce.pubkey
RUN echo "deb ${APT_URL} $(lsb_release -sc) release" > /etc/apt/sources.list.d/perforce.sources.list
RUN apt-get update && \
    apt-get -q -y install helix-cli helix-p4d

RUN /opt/perforce/sbin/configure-helix-p4d.sh -n -p ${P4PORT} -u super -P Rebar123 despot

WORKDIR /perforce

#
# perform the initial setup of the p4d instance
#
COPY $BASE_PATH/build.sh .
COPY $BASE_PATH/user_george.txt .
COPY $BASE_PATH/user_jackson.txt .
COPY $BASE_PATH/user_janedoe.txt .
COPY $BASE_PATH/user_johndoe.txt .
COPY $BASE_PATH/user_swarm.txt .
COPY $BASE_PATH/group_notimeout.txt .
COPY $BASE_PATH/ldap_simple.txt .
COPY loginhook loginhook
COPY $BASE_PATH/ext_config.awk .
COPY $BASE_PATH/mfa-trigger.sh .
COPY $BASE_PATH/triggers.txt .
RUN ./build.sh

USER perforce
COPY $BASE_PATH/run.sh .
EXPOSE 1666
HEALTHCHECK CMD p4 -p 0.0.0.0:1666 -u super info || exit 1
ENTRYPOINT [ "./run.sh" ]
