FROM amazonlinux:2
#
# $ docker build -f test/install/Amazon2.dockerfile -t has-amazon2-install .
# $ docker image ls | grep has-amazon2-install
#
ARG P4PORT="0.0.0.0:1666"

# The docker base images are generally minimal, and our install and configure
# scripts have certain requirements, so install those now.
RUN yum -q -y install sudo which

# install p4 and p4d using packages
RUN rpm --import http://package.perforce.com/perforce.pubkey
RUN echo -e '[perforce]\n\
name=Perforce\n\
baseurl=http://package.perforce.com/yum/rhel/7/x86_64\n\
enabled=1\n\
gpgcheck=1\n'\
>> /etc/yum.repos.d/perforce.repo
RUN yum -q -y install helix-cli helix-p4d

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
