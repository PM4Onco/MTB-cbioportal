FROM ghcr.io/pm4onco/cbioportal:${RELEASE:-latest} as static

FROM docker.io/openresty/openresty:1.25.3.1-alpine-fat
RUN apk update && apk add git ca-certificates openssl lua5.1 && rm -rf /var/cache/apk/*
COPY --from=static /cbioportal-webapp /usr/share/nginx/html
RUN rm /etc/nginx/conf.d/default.conf \
    && lua5.1 /usr/local/openresty/luajit/bin/luarocks install lua-resty-openidc

COPY ./start.sh /start.sh

ENTRYPOINT [ "/start.sh" ]