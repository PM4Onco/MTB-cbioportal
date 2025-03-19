#!/bin/sh

sleep 2

if [ -s /keycloak.pem ]; then
    echo "Keycloak certificate chain present. Copying to ca store."
    openssl x509 -inform PEM -in /keycloak.pem -out /usr/local/share/ca-certificates/keycloak.pem
    sed 's/#lua_ssl_trusted_certificate/lua_ssl_trusted_certificate/g' /cbioportal.conf > /etc/nginx/conf.d/cbioportal.conf
    update-ca-certificates
else
    echo "Keycloak certificate not present."
    cp /cbioportal.conf /etc/nginx/conf.d/cbioportal.conf
fi

/usr/local/openresty/bin/openresty -g "daemon off;"