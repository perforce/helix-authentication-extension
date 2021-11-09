FROM centos:7
#
# $ docker build -f test/install/CentOS7.dockerfile -t has-centos7-install .
# $ docker image ls | grep has-centos7-install
#
ARG P4PORT="0.0.0.0:1666"

# The docker base images are generally minimal, and our install and configure
# scripts have certain requirements, so install those now.
RUN yum -q -y install patch sudo which

# install p4 and p4d using packages
RUN rpm --import http://package.perforce.com/perforce.pubkey
RUN echo -e '[perforce]\n\
name=Perforce\n\
baseurl=http://package.perforce.com/yum/rhel/7/x86_64\n\
enabled=1\n\
gpgcheck=1\n'\
>> /etc/yum.repos.d/perforce.repo
RUN yum -q -y install helix-cli helix-p4d

# patch configure script to wait for p4d to start fully (P4-20611)
COPY containers/configure.diff /tmp
RUN cd /opt/perforce/sbin && \
    patch -p0 </tmp/configure.diff
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
