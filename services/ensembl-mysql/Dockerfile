FROM mariadb:10.11.11 as builder

# That file does the DB initialization but also runs mysql daemon, by removing the last line it will only init
# RUN ["sed", "-i", "s/exec \"$@\"/echo \"not running $@\"/", "/usr/local/bin/docker-entrypoint.sh"]

COPY $PWD/docker-entrypoint.sh /home/docker-entrypoint.sh

# needed for intialization
ENV MYSQL_ROOT_PASSWORD=root
ENV MYSQL_DATABASE=homo_sapiens_core_75_37

RUN apt-get update && apt-get install -y wget

WORKDIR /docker-entrypoint-initdb.d/
RUN wget -q ftp://ftp.ensembl.org/pub/release-75/mysql/homo_sapiens_core_75_37/homo_sapiens_core_75_37.sql.gz

WORKDIR /home
RUN wget -q -r -nH --cut-dirs=4 --no-parent ftp://ftp.ensembl.org/pub/release-75/mysql/homo_sapiens_core_75_37
RUN gunzip *.gz

# Need to change the datadir to something else that /var/lib/mysql because the parent docker file defines it as a volume.
# https://docs.docker.com/engine/reference/builder/#volume :
#       Changing the volume from within the Dockerfile: If any build steps change the data within the volume after
#       it has been declared, those changes will be discarded.
RUN ["/home/docker-entrypoint.sh", "mysqld", "--datadir", "/initialized-db", "--aria-log-dir-path", "/initialized-db"]

FROM mariadb:11.3.2
LABEL maintainer="Niklas Reimer <niklas.reimer@uksh.de>"

COPY --from=builder /initialized-db /var/lib/mysql
