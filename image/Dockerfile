# MTB-cbioportal-Image: offizielles v7.1.1 + PM4Onco-Core-Fork + eigenes Frontend.
# Kontext wird von tools/build-image.sh erzeugt (core/, frontend/reactapp/).
FROM cbioportal/cbioportal@sha256:47a3569824f5ffdf73f7102eda2404d0dc0e8fa71f8d9eb33972ef8ccc6319d4

ARG CORE_COMMIT
ARG CORE_BASE
ARG FRONTEND_COMMIT
LABEL org.pm4onco.core.commit="${CORE_COMMIT}" \
      org.pm4onco.core.base="${CORE_BASE}" \
      org.pm4onco.frontend.commit="${FRONTEND_COMMIT}"

RUN rm -rf /core/scripts /core/core-IMPORTER.jar /core/requirements.txt
COPY core/scripts /core/scripts
COPY core/core-IMPORTER.jar /core/core-IMPORTER.jar
COPY core/requirements.txt /core/requirements.txt
RUN chmod -R a+x /core/scripts/

RUN rm -rf /cbioportal-webapp/reactapp
COPY frontend/reactapp /cbioportal-webapp/reactapp
