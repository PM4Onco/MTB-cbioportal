# This image includes both the web app and the data import related scripts in
# one image. Because of historic reasons some of these scripts run java
# artifacts under the hood. It therefore currently makes more sense to have a
# single image supporting both instead of moving the scripts out to a separate
# container.
#
# Use from root directory of repo like:
#
# docker build -f docker/web-and-data/Dockerfile -t cbioportal-container:tag-name .
#
# NOTE: the .git folder is included in the build stage, but excluded 
# from the final image. No confidential information is exposed.
# (see: stackoverflow.com/questions/56278325)
FROM docker.io/maven:3-eclipse-temurin-21 as build

ARG VERSION=6.0.16

RUN git clone --single-branch --branch release$VERSION https://github.com/buschlab/cbioportal-frontend.git /frontend
WORKDIR /frontend
RUN mvn clean install

RUN git clone --single-branch --branch v$VERSION https://github.com/cbioportal/cbioportal.git /cbioportal
WORKDIR /cbioportal
RUN cp /cbioportal/src/main/resources/application.properties.EXAMPLE /cbioportal/src/main/resources/application.properties

RUN git clone --single-branch --branch v1.0.7 https://github.com/cbioportal/cbioportal-core.git /cbioportal/core

# don't skip LoH mutations on import
RUN sed -i 's/|| loh ||/||/' core/src/main/java/org/mskcc/cbio/portal/util/ExtendedMutationUtil.java
RUN sed -i 's/safeStringTest( mutation.getMutationStatus(), "LOH" )/false/' core/src/main/java/org/mskcc/cbio/portal/scripts/MutationFilter.java

# Show all CNVs
RUN sed -i 's/(-2, 2)/(-2, -1, 1, 2)/' /cbioportal/src/main/java/org/cbioportal/web/parameter/DiscreteCopyNumberEventType.java
RUN sed -i 's/\!alterationTypes.contains(-1) && \!alterationTypes.contains(0) && \!alterationTypes.contains(1)/!alterationTypes.contains(0)/' /cbioportal/src/main/java/org/cbioportal/service/impl/DiscreteCopyNumberServiceImpl.java
RUN sed -i 's/\!alterationTypes.contains(CNA.HETLOSS) && \!alterationTypes.contains(CNA.DIPLOID) && \!alterationTypes.contains(CNA.GAIN)/!alterationTypes.contains(CNA.DIPLOID)/' /cbioportal/src/main/java/org/cbioportal/service/impl/DiscreteCopyNumberServiceImpl.java

RUN mvn -DskipTests -Dfrontend.version=0.3.0 -Dfrontend.groupId=com.github.cbioportal clean install package
RUN mkdir -p target/dependency && (cd target/dependency; jar -xf ../*-exec.jar)

WORKDIR /cbioportal/core
RUN mvn -DskipTests install package

FROM docker.io/alpine:3.20.3

# create user for not running image with root privileges
RUN addgroup -g 1001 -S cbioportal && adduser -u 1001 -S cbioportal -G cbioportal

# download system dependencies first to take advantage of docker caching
RUN apk add --update \
        bash \
        build-base \
        gcc \
        mariadb-client \
        mariadb-dev \
        openjdk21-jdk \
        perl \
        py3-pip \
        python3 \
        python3-dev \
        wget \
        ca-certificates \
    && rm -rf /var/cache/apk/* \
    && pip3 install --break-system-packages wheel

ENV PORTAL_WEB_HOME=/cbioportal-webapp
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk

RUN mkdir -p /cbioportal && chown -R cbioportal:cbioportal /cbioportal && mkdir /core

#Download core files
COPY --from=build /cbioportal/core/target/core-1.0.7.jar /core
RUN cd /core ; jar -xf core-1.0.7.jar scripts/ requirements.txt ; chmod -R a+x scripts/ ; cd ..;
#RUN sed -i "s/connection_kwargs\['ssl_mode'\] = 'DISABLED'//" /core/scripts/importer/cbioportal_common.py

# copy over core jar and scripts
COPY --from=build /cbioportal/src/main/resources/db-scripts /cbioportal/db-scripts

# install build and runtime dependencies
# ignore update failures
RUN pip3 install --break-system-packages -r /core/requirements.txt
RUN pip3 install --break-system-packages --upgrade urllib3 requests  

# add importer scripts to PATH for easy running in containers
RUN find /core/scripts/ -type f -executable \! -name '*.pl'  -print0 | xargs -i -- ln -s {} /usr/local/bin

# put config files in this folder if you want to override config
ENV PORTAL_HOME=/cbioportal

RUN mkdir -p $PORTAL_WEB_HOME

# add exploded Spring Boot jar contents to image
# See: https://spring.io/guides/topicals/spring-boot-docker/
ARG DEPENDENCY=/cbioportal/target/dependency
RUN mkdir -p $PORTAL_WEB_HOME
COPY --from=build ${DEPENDENCY}/BOOT-INF/lib                $PORTAL_WEB_HOME/lib/
COPY --from=build ${DEPENDENCY}/META-INF                    $PORTAL_WEB_HOME/META-INF/
COPY --from=build ${DEPENDENCY}/BOOT-INF/classes            $PORTAL_WEB_HOME/

# add entrypoint
COPY --from=build /cbioportal/docker/web-and-data/docker-entrypoint.sh /usr/local/bin/

# script for calling dumpPortalInfo.py from docker compose
RUN echo "cd /core/scripts && ./dumpPortalInfo.pl /cbioportal/portalinfo" >> /cbioportal/dumpPortalInfo.sh
RUN chmod +x /cbioportal/dumpPortalInfo.sh

# don't skip LoH mutations on import
RUN sed -i 's/\[\x27loh\x27, /[/' /core/scripts/importer/validateData.py

# don't make column smaller
RUN sed -i "s/ALTER TABLE \`clinical\_event\_data\` MODIFY COLUMN \`VALUE\` varchar(3000) NOT NULL;//g" /cbioportal/db-scripts/migration.sql

# switch to non-root user
USER cbioportal
RUN mkdir /cbioportal/portalinfo
ENTRYPOINT ["docker-entrypoint.sh"]
