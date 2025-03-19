FROM docker.io/ensemblorg/ensembl-vep:release_111.0
LABEL maintainer="Niklas Reimer <niklas.reimer@uksh.de>"

USER root
RUN apt-get update && apt-get install -y git libcatalyst-devel-perl libxml-simple-perl libtest-xml-simple-perl
WORKDIR /opt/vep/src

RUN git clone https://github.com/Ensembl/ensembl-compara.git && cd ensembl-compara && git checkout release/111 && cd ..
ENV PERL5LIB=/opt/vep/src/ensembl-vep:/opt/vep/src/ensembl-vep/modules:/opt/vep/src/ensembl-compara/modules

RUN git clone https://github.com/Ensembl/ensembl-rest.git /opt/vep/src/ensembl-rest && cd ensembl-rest && git checkout release/111 && cd ..
WORKDIR /opt/vep/src/ensembl-rest
RUN cpanm install --force Log::Any
RUN cpanm --installdeps . && rm -rf /root/.cpanm/work

RUN mv /opt/vep/src/ensembl-rest/ensembl_rest.conf.default /opt/vep/src/ensembl-rest/ensembl_rest.conf

EXPOSE 3000

WORKDIR /opt/vep/src/ensembl-vep/
RUN ./INSTALL.pl -n -a cf -s homo_sapiens -y GRCh37 && mv /root/.vep /opt/vep/

ENTRYPOINT ["perl", "/opt/vep/src/ensembl-rest/script/ensembl_rest_server.pl"]

