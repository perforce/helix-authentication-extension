#
# Build a basic p4d container with the loginhook extension installed. Some
# adjustments will be needed to accommodate your usage.
#
# $ docker build -f containers/basic-p4d/Dockerfile -t helix-p4d-basic .
#
# Starting the container (be sure to use an appropriate mount path):
#
# $ docker run -d --mount type=bind,src=/mnt/p4data,dst=/p4 -p 1666:1666 --name basic-p4d helix-p4d-basic
#
# Pushing the image to a registry (e.g. to use with Kubernetes):
#
# $ docker image rm 192.168.1.2:32000/helix-p4d-basic
# $ docker image tag helix-p4d-basic 192.168.1.2:32000/helix-p4d-basic
# $ docker push 192.168.1.2:32000/helix-p4d-basic
#
FROM ubuntu:20.04

ARG BASE_PATH="containers/basic-p4d"
ARG PUB_KEY="http://package.perforce.com/perforce.pubkey"
ARG APT_URL="http://package.perforce.com/apt/ubuntu"
ARG P4PORT="0.0.0.0:1666"

# install p4 and p4d via packages
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && \
    apt-get -q -y install apt-utils lsb-release gnupg patch
ADD ${PUB_KEY} perforce.pubkey
RUN apt-key add perforce.pubkey && \
    rm -f perforce.pubkey
RUN echo "deb ${APT_URL} $(lsb_release -sc) release" > /etc/apt/sources.list.d/perforce.sources.list
RUN apt-get update && \
    apt-get -q -y install helix-cli helix-p4d

WORKDIR /setup

COPY bin bin
COPY loginhook loginhook
COPY $BASE_PATH/docker-entrypoint.sh .

VOLUME /p4
EXPOSE 1666
#
# Cannot have a healthcheck using p4 since a ticket for super user was not
# established at build time.
#
# HEALTHCHECK CMD p4 -p 0.0.0.0:1666 -u super info || exit 1
ENTRYPOINT [ "./docker-entrypoint.sh" ]
