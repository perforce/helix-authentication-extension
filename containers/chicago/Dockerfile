#
# build the commit server image
#
FROM ubuntu:latest
ARG PUB_KEY
ARG APT_URL
ARG BASE_PATH
ENV P4PORT 0.0.0.0:2666
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && \
    apt-get -q -y install apt-utils lsb-release gnupg
ADD ${PUB_KEY} perforce.pubkey
RUN apt-key add perforce.pubkey && \
    rm -f perforce.pubkey
RUN echo "deb ${APT_URL} $(lsb_release -sc) release" > /etc/apt/sources.list.d/perforce.sources.list
RUN apt-get update && \
    apt-get -q -y install helix-cli helix-p4d

RUN /opt/perforce/sbin/configure-helix-p4d.sh -n -p ${P4PORT} -r /chicago -u super -P Rebar123 chicago_commit

WORKDIR /setup

# basic setup of users and such
COPY $BASE_PATH/build.sh .
COPY $BASE_PATH/login.sh .
COPY $BASE_PATH/group_notimeout.txt .
COPY $BASE_PATH/protections.txt .
COPY $BASE_PATH/user_commit_svc.txt .
COPY $BASE_PATH/user_edge_svc.txt .
COPY $BASE_PATH/user_jackson.txt .
COPY $BASE_PATH/user_johndoe.txt .
RUN ./build.sh

#
# Create a checkpoint of the commit server, which will be copied into the edge
# server during its build. Note that this relies on docker-compose tagging our
# image after a successful build.
#
# remove empty files that cause the checkpoint to fail
RUN rm -f /chicago/root/db.nameval
RUN p4d -r /chicago/root -K "db.have,db.working,db.locks,db.resolve,db.revsh,db.workingx,db.resolvex,db.stash,db.haveg,db.workingg,db.locksg,db.resolveg" -z -jd edge.ckp

# install the login extension
COPY $BASE_PATH/install_hook.sh .
COPY $BASE_PATH/ext_config.awk .
COPY loginhook loginhook
RUN ./install_hook.sh

RUN chown -R perforce:perforce /chicago
RUN chown -R perforce:perforce /setup
USER perforce
COPY $BASE_PATH/run.sh .
EXPOSE 2666
HEALTHCHECK CMD p4 -p 0.0.0.0:2666 -u super info || exit 1
ENTRYPOINT [ "./run.sh" ]
