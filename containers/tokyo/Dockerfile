#
# build the edge server image
#
FROM ubuntu:22.04
ARG PUB_KEY
ARG APT_URL
ARG BASE_PATH
ENV P4PORT 0.0.0.0:3666
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && \
    apt-get -q -y install apt-utils lsb-release gnupg patch
ADD ${PUB_KEY} perforce.pubkey
RUN apt-key add perforce.pubkey && \
    rm -f perforce.pubkey
RUN echo "deb ${APT_URL} $(lsb_release -sc) release" > /etc/apt/sources.list.d/perforce.sources.list
RUN apt-get update && \
    apt-get -q -y install helix-cli helix-p4d

RUN /opt/perforce/sbin/configure-helix-p4d.sh -n -p ${P4PORT} -r /tokyo -u super -P Rebar123 tokyo_edge

WORKDIR /setup

# Add the missing P4PORT to the service configuration, which despite other
# services working just fine without it, the edge server refuses to start.
COPY $BASE_PATH/p4d_config.awk .
RUN ./p4d_config.awk /etc/perforce/p4dctl.conf.d/tokyo_edge.conf > tmp.conf && \
    mv tmp.conf /etc/perforce/p4dctl.conf.d/tokyo_edge.conf

#
# Rely on the build/image trick (having both a 'build' and an 'image' will cause
# compose to tag the resulting image with that name) in compose to copy the
# checkpoint and versioned file from the commit server build to this image. This
# saves us the trouble of trying to use rsync from the run.sh the first time the
# container is started.
#
COPY --from=chicago:latest /chicago/root/edge.ckp.gz /tokyo/root/
RUN p4d -r /tokyo/root -z -jr edge.ckp.gz
# there are no versioned files as yet, so nothing to copy
# COPY --from=chicago:latest /chicago/root/depot /tokyo/root/depot

RUN chown -R perforce:perforce /setup
RUN chown -R perforce:perforce /tokyo
USER perforce
COPY $BASE_PATH/run.sh .
EXPOSE 3666
HEALTHCHECK CMD p4 -p 0.0.0.0:3666 -u super info || exit 1
ENTRYPOINT [ "./run.sh" ]
