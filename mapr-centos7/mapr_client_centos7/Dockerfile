FROM mapr_base_centos7:6.1.0

# This file contains an alternative Yum repository for the build
COPY REPOSITORY /home/mapr/REPOSITORY 
COPY mapr_core.repo /etc/yum.repos.d/

# At cluster startup, the template file will be converted to repo file
# with current MEP version if no mapr_mep.repo file has been otherwise
# created by a child image.
# Cluster startup will grap this newly created mapr_mep.repo from a 
# client (launcher node if no other clients), and copy it to the rest of
# the cluster.
# (See start-cluster.functions::configure_cluster())
COPY mapr_mep.repo.template /etc/yum.repos.d/

# Set up mapr repositories for install (only core is really needed here but keeping consistent w/ other images)
# This will use the local repository container to build the image
RUN \
  mkdir -p /home/mapr/tmp && \
  CORE_REPO=$(grep -i core /home/mapr/REPOSITORY | tr -s ' ' | cut -f 2 -d ' ') && \
  cp /etc/yum.repos.d/mapr_core.repo /home/mapr/tmp/mapr_core.repo && \
  sed -i -e "s^http://package.mapr.com^$CORE_REPO^g" /etc/yum.repos.d/mapr_core.repo && \
  rpm --import $CORE_REPO/releases/pub/maprgpg.key && \
  rpm --import $CORE_REPO/releases/pub/gnugpg.key && \
  :
#  cp /etc/yum.repos.d/mapr_mep.repo /home/mapr/tmp/mapr_mep.repo && \

# nfs-utils required for mount.nfs to mount an NFS filesystem
RUN \
  yum install -y \
      mapr-client \
      initscripts \
      nfs-utils \
      && :

COPY core-site.xml /opt/mapr/hadoop/hadoop-2.7.0/etc/hadoop/core-site.xml

# Copy package.mapr.com repo files back for later use if necessary
RUN \
  /bin/cp -f /home/mapr/tmp/mapr_core.repo /etc/yum.repos.d/mapr_core.repo && \
  :
#  /bin/cp -f /home/mapr/tmp/mapr_mep.repo /etc/yum.repos.d/mapr_mep.repo && \

ENV NODETYPE=MapRClient
EXPOSE 22
CMD ["/usr/sbin/init"]

