FROM solr:8.8.1
LABEL maintainer="jason.dudash@gmail.com"
LABEL maintainer="emiliano.sune@gmail.com"

USER root
ENV STI_SCRIPTS_PATH=/usr/libexec/s2i

RUN apt-get update && \
    apt-get install zip

# ===============================================================================================
# Mitigation for CVE-2021-44228 and CVE-2021-45046
#   - Set LOG4J_FORMAT_MSG_NO_LOOKUPS=true
#   - Remove JndiLookup.class from the classpath.
#
# Upgrade to solr 8.11.1 or greater when availble.
#
# References:
#   - https://logging.apache.org/log4j/2.x/security.html
#   - https://solr.apache.org/security.html#apache-solr-affected-by-apache-log4j-cve-2021-44228
#
# Search for jars containing JndiLookup.class:
#   - find / -name log4j-core*.jar -exec unzip -vl {} \; 2>/dev/null | grep JndiLookup.class
# -----------------------------------------------------------------------------------------------
ENV LOG4J_FORMAT_MSG_NO_LOOKUPS=true
RUN find / -name log4j-core*.jar -exec zip -q -d {} org/apache/logging/log4j/core/lookup/JndiLookup.class \; 2>/dev/null
# ===============================================================================================

LABEL io.k8s.description="Run SOLR search in OpenShift" \
      io.k8s.display-name="SOLR 8.8.1" \
      io.openshift.expose-services="8983:http" \
      io.openshift.tags="builder,solr,solr8.8.1" \
      io.openshift.s2i.scripts-url="image:///${STI_SCRIPTS_PATH}"

COPY ./s2i/bin/. ${STI_SCRIPTS_PATH}
RUN chmod -R a+rx ${STI_SCRIPTS_PATH}

# If we need to add files as part of every SOLR conf, they'd go here
# COPY ./solr-config/ /tmp/solr-config

# Give the SOLR directory to root group (not root user)
# https://docs.openshift.org/latest/creating_images/guidelines.html#openshift-origin-specific-guidelines
RUN chgrp -R 0 /opt/solr \
  && chmod -R g+rwX /opt/solr \
  && chown -LR solr:root /opt/solr

RUN chgrp -R 0 /opt/docker-solr \
  && chmod -R g+rwX /opt/docker-solr \
  && chown -LR solr:root /opt/docker-solr

# - In order to drop the root user, we have to make some directories writable
#   to the root group as OpenShift default security model is to run the container
#   under random UID.
RUN usermod -a -G 0 solr

USER 8983
