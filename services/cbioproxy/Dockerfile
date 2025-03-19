FROM ghcr.io/pm4onco/cbioportal:${RELEASE:-latest} as static

FROM docker.io/openresty/openresty:1.21.4.1-7-alpine-fat
RUN apk update && apk add git ca-certificates openssl && rm -rf /var/cache/apk/*
COPY --from=static /cbioportal-webapp /usr/share/nginx/html
RUN rm /etc/nginx/conf.d/default.conf \
    && /usr/local/openresty/luajit/bin/luarocks install lua-resty-openidc

COPY ./start.sh /start.sh

ENTRYPOINT [ "/start.sh" ]