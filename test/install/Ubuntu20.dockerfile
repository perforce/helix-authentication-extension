FROM ubuntu:20.04
#
# $ docker build -f test/install/Ubuntu20.dockerfile -t has-ubuntu20-install .
# $ docker image ls | grep has-ubuntu20-install
#
ARG APT_URL="http://package.perforce.com/apt/ubuntu"
ARG PUB_KEY="http://package.perforce.com/perforce.pubkey"
ARG P4PORT="0.0.0.0:1666"

# The docker base images are generally minimal, and our install and configure
# scripts have certain requirements, so install those now.
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get -q update --fix-missing && \
    apt-get -q -y install gawk patch

# install p4 and p4d using packages
RUN apt-get -q update --fix-missing && \
    apt-get -q -y install apt-utils lsb-release gnupg
ADD ${PUB_KEY} perforce.pubkey
RUN apt-key add perforce.pubkey && \
    rm -f perforce.pubkey
RUN echo "deb ${APT_URL} $(lsb_release -sc) release" > /etc/apt/sources.list.d/perforce.sources.list
RUN apt-get -q update --fix-missing && \
    apt-get -q -y install helix-cli helix-p4d

RUN /opt/perforce/sbin/configure-helix-p4d.sh -n -p ${P4PORT} -u super -P Rebar123 despot

# create a working directory for which the perforce user has write permissions
RUN mkdir /workdir
RUN chown perforce:perforce /workdir
WORKDIR /workdir

COPY bin helix-auth-ext/bin
COPY loginhook helix-auth-ext/loginhook
COPY test/install/runtest.sh .
RUN chown -R perforce .
USER perforce
RUN ./runtest.sh
