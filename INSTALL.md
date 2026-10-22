# Installation

## Prerequisites

1. A system with at least
    - 4 CPU cores
    - 10 GB of RAM
    - 100GB of free disk space
2. A container environment like Docker or Podman with support for Compose V3 (e.g. through `docker compose`, `podman-compose`, etc.)

The following steps will assume the usage of Docker  without an explicitly stated `sudo` command.

Using HTTPS also requires:

1. A reverse proxy that will terminate the HTTPS of the cBioPortal instance (preferrably nginx)
2. A DNS name for cBioPortal with a **full chain** webserver certificate

Authentication with Keycloak is provided by a container that the deployment starts alongside cBioPortal (see "Add authentication (Keycloak)"); it works without HTTPS for testing, for production a reverse proxy with certificates in front of both services is strongly recommended.

It is recommended to start with a setup without authentication and add that later on.

## Setup without authentication

### 1. Clone the git repository

```
git clone https://github.com/PM4Onco/MTB-cbioportal.git
cd MTB-cbioportal
git checkout 7.1.1-ukf
```

### 2. Derive environment from the default

```
cp .env.example .env
```

The cBioPortal image (`DOCKER_IMAGE_CBIOPORTAL`) is a **private GHCR package** (`ghcr.io/ukf-pauli/cbioportal-image`). Once per host and user, log in to the container registry before anything else:

```
docker login ghcr.io
```

(username plus a token with *Read packages* access, e.g. a fine-grained PAT; if you run docker via `sudo`, log in as `sudo docker login ghcr.io`). All other images are public.

Start editing the `.env` file with a text editor. By default the installation points to the fixed 7.1.1 release (`DOCKER_IMAGE_CBIOPORTAL`). The image is built reproducibly from pinned core and frontend commits (see the "Building images yourself" section in [README.md](./README.md)).

Using OncoKB will all annotations requires a token that can be obtained [here](https://www.oncokb.org/apiAccess). This must be entered into the `.env` file as well as the `#` before the parameter `ONCOKB_URL` removed.

By default MTB-cbioportal is exposed on port 8080, if that one is not available, please change it in the `.env` file.

If the network requires a proxy, please use the parameter `HTTPS_PROXY_PORT`. (Note: the 7.1.1 stack does not pass an outbound proxy to the containers itself; external services such as Genome Nexus and OncoKB are reached from the host network, and the variable is kept for the planned Keycloak integration.)

Please set the ClickHouse password **now** in the `.env` file (`CLICKHOUSE_PASSWORD`). It will be written to `config/application.properties` by the initialization step below and the database will initialize with the provided value. Changing this afterwards must be done manually!

### 3. Initialize config files

```
./init.sh
```

The script generates `config/application.properties` (with the ClickHouse credentials from `.env`) and extracts the ClickHouse schema, seed data and derived-table SQL from the pinned cBioPortal image. It requires Docker and internet access, as well as a `.env` file.

The application's Docker container are running as `root` user. If you are not the `root` user, you may want to change the permissions of the `data/` directory with e.g.:

```
sudo chmod 755 data/
```

### 4. Starting MTB-cbioportal

Now start MTB-cBioPortal. The first start can take several minutes: the ClickHouse container loads the schema, the seed database and the derived tables before cBioPortal starts.

```
docker compose up -d
```

If the system is limited in I/O capabilities, a timeout might occur. This timeout can be increased by using

```
COMPOSE_HTTP_TIMEOUT=200 docker compose up -d
```

After the command is complete it should be possible to access cBioPortal on your machine using the webbrowser on the previously specified port.
When using a remote machine and a rootless container environment like Podman, it might be neccessary to add the port to the firewall.

### 5. Importing data

To import one of the provided test data sets use the following command

```
docker compose exec cbioportal python3 /core/scripts/importer/metaImport.py -u http://cbioportal:8080 -s /study/testpatient -o
```

The address here doesn't require any change, as it's being called from inside the container. The `-o` flag overwrites an existing study with the same ID; a previously imported study can be removed via the REST API (`DELETE /api/studies/<stableId>`).

### Optional: overriding the frontend bundle

By default the frontend bundle is part of the cBioPortal image. To test a local frontend build instead, set `FRONTEND_DIST` in `.env` (path relative to this directory, e.g. `../cbioportal-frontend/dist/reactapp`) and start with the additional override file:

```
docker compose -f docker-compose.yml -f docker-compose.frontend.yml up -d cbioportal
```

## Add HTTPS

Adding HTTPS to MTB-cBioPortal requires a reverse proxy that terminates HTTPS. 

It must set the following header, so that URLs are being constructed correctly:

```
X-Forwarded-Proto
```

Using nginx is recommended but Apache or Traefik will also work. A very simple nginx config for this can look like this: 

```
server
{

	listen 443 ssl http2;
	server_name mycbioportal.de;
	ssl_certificate /certs/tls.pem;
	ssl_certificate_key /certs/tls.key;

	client_max_body_size 0;

	location /
	{

		proxy_headers_hash_max_size 512;
		proxy_headers_hash_bucket_size 64;
		proxy_buffer_size 128k;
		proxy_buffers 4 256k;
		proxy_busy_buffers_size 256k;
		proxy_set_header Host $http_host;
		proxy_set_header X-Forwarded-Proto $scheme;
		proxy_set_header X-Real-IP $remote_addr;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

		proxy_pass http://mycbioportal:8080;

	}

}

server
{

	listen 80;
	server_name mycbioportal.de;

	return 301 https://mycbioportal.de$request_uri;

}
```

Adding the reverse proxy doesn't require a restart of cBioPortal and should 

## Add authentication (Keycloak)

Authentication is provided by a Keycloak container that is started together with cBioPortal via an overlay file. The stack works in two modes:

- **No-Auth (default):** `docker compose up -d` — no login, `/reports/` is served without checks.
- **OAuth2:** `docker compose -f docker-compose.yml -f compose.keycloak.yml up -d` — Keycloak starts alongside cBioPortal, all portal access requires a login, and `/reports/` files are only reachable by users that have access to the corresponding study.

The OAuth2 mode is supported **without HTTPS** (Keycloak and cBioPortal talk over the internal docker network). In production a reverse proxy with a full-chain certificate in front of both services is still strongly recommended.

### 1. Prepare the Keycloak configuration

Two files that are *not* part of the repository have to be created in the checkout (both are gitignored on purpose):

**`config/security.properties`** — the OAuth2 client configuration. Adjust the two `localhost` URLs to your cBioPortal host name and set `client-secret` to the client secret of your Keycloak client (`local-test-secret` works out of the box when using the reference realm from step 2):

```
spring.security.oauth2.roles-path.client-id=cbioportal
spring.security.oauth2.client.registration.cbio-idp.client-id=cbioportal
spring.security.oauth2.client.registration.cbio-idp.client-secret=<client-secret>
spring.security.oauth2.client.registration.cbio-idp.authorization-grant-type=authorization_code
spring.security.oauth2.client.registration.cbio-idp.client-authentication-method=client_secret_basic
spring.security.oauth2.client.registration.cbio-idp.redirect-uri=http://<cbioportal-host>:8080/login/oauth2/code/cbio-idp
spring.security.oauth2.client.registration.cbio-idp.scope=openid,email,roles
spring.security.oauth2.client.provider.cbio-idp.user-name-attribute=email
spring.security.oauth2.client.provider.cbio-idp.authorization-uri=http://<keycloak-host>:18080/realms/mtb/protocol/openid-connect/auth
spring.security.oauth2.client.provider.cbio-idp.token-uri=http://keycloak:8080/realms/mtb/protocol/openid-connect/token
spring.security.oauth2.client.provider.cbio-idp.user-info-uri=http://keycloak:8080/realms/mtb/protocol/openid-connect/userinfo
spring.security.oauth2.client.provider.cbio-idp.jwk-set-uri=http://keycloak:8080/realms/mtb/protocol/openid-connect/certs
always_show_study_group=PUBLIC
filter_groups_by_appname=false
```

Note: `redirect-uri` and `authorization-uri` use the *browser-visible* host names, while `token-uri`, `user-info-uri` and `jwk-set-uri` stay on `keycloak:8080`, because they are resolved *inside* the cBioPortal container.

**Realm file** — the overlay `compose.keycloak.yml` imports a Keycloak realm from `config/keycloak/realm-mtb.json` (path relative to the checkout). The reference realm used for testing contains:

- realm `mtb`, client `cbioportal` (client ID `cbioportal`, standard flow, client secret mode), client role `MTB_TEST` exposed in the `userinfo` token
- test users `mtb-allowed` (password `test-allowed`, has role `MTB_TEST`) and `mtb-denied` (password `test-denied`, no role)
- Keycloak admin: `admin` / `admin` (change for production)

For an existing Keycloak server instead of the bundled one, adapt the realm import volume in `compose.keycloak.yml` and the realm URLs in `security.properties` accordingly.

### 2. Set study groups **before** switching to authentication

This is the most common pitfall: **`public=1` alone does not grant access once OAuth2 is active.** A study is visible to a user only if one of the client roles in the user's token matches one of the comma-separated values in the `groups` column of `meta_study.txt`. A study with `public=1` and an empty `groups` column is hidden from *everyone* after the switch.

So, before starting with authentication, make sure every `meta_study.txt` that shall be visible lists the intended groups, and import the studies now (while the API is still open):

```
docker compose exec cbioportal python3 /core/scripts/importer/metaImport.py -u http://cbioportal:8080 -s /study/<study> -o
```

After switching to OAuth2, no re-import is needed.

### 3. Switch to the OAuth2 stack

```
docker compose down
docker compose -f docker-compose.yml -f compose.keycloak.yml up -d
```

- cBioPortal: `http://<host>:8080` — every request redirects to the login
- Keycloak: `http://<host>:18080` (realm `mtb`)

Verify with one user that has a matching client role and one without: `/api/studies` must return the group-restricted list for the first and an empty list for the second.

To go back to No-Auth:

```
docker compose down
docker compose up -d
```

### 4. Importing data while authentication is active

The import process talks to the portal API, which is then protected by the login. For that the portal metadata must be dumped to disk first and passed to the importer:

```
docker compose exec cbioportal perl /core/scripts/dumpPortalInfo.pl -u http://cbioportal:8080 -o /cbioportal/portalinfo/portalinfo.json
```

```
docker compose exec cbioportal python3 /core/scripts/importer/metaImport.py -u http://cbioportal:8080 -p /cbioportal/portalinfo/portalinfo.json -s /study/<study> -o
```

(Alternative: temporarily start without the Keycloak overlay, import, then switch back.)

### 5. Reports access

The proxy enforces `/reports/` access through an `auth_request` against `GET /api/studies/<study>` — a report file is only served if the logged-in user may access the study whose ID matches the directory name. Users without access get HTTP 403. In No-Auth mode this check is not applied, so `/reports/` is open there.

## Troubleshooting

Will be constantly updated...
