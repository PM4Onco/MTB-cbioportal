# MTB-cbioportal

This repository is the home of a cBioPortal version that was modified and extended for usage in a molecular tumor board.

## Installation

Installation is described [here](./INSTALL.md)

## Building images yourself

The cBioPortal image (backend + importer + frontend bundle) is built **manually and locally** — there is no CI build, because the core source `PM4Onco/cbioportal-core` is private and the runner has no access to it. The build is reproducible from pinned core ref and frontend commit:
```
tools/build-image.sh [tag]
```
(default tag `7.1.1-ukf`; the core source is cloned from `https://github.com/PM4Onco/cbioportal-core`, branch `v7.1.1-ukf`, the frontend from `https://github.com/PM4Onco/cbioportal-frontend` on the matching branch; overridable via `CORE_REPO`, `CORE_REF`, `FRONTEND_REPO`, `FRONTEND_COMMIT`, `BRANCH_ENV`, see the script header). By default the image is only loaded into the local Docker daemon; to build multi-arch (amd64+arm64) and push, use `PUSH=1 PLATFORMS=linux/amd64,linux/arm64 IMAGE=<registry path> REG_AUTH=<docker config.json> tools/build-image.sh <tag>`. The image is always tagged `<tag>` plus a `-core<sha>-fe<sha>` combo tag for traceability; `latest` is never touched. The other images (ClickHouse, session service, MongoDB, OpenResty) are pulled from their public registries and versioned in `.env`.

Two GHCR packages are used and must not be conflated:

- **Official deployment image:** `ghcr.io/pm4onco/cbioportal-image` — the package `INSTALL.md` and the deployment expect.
- **Local/test image:** `ghcr.io/ukf-pauli/cbioportal-image` — a personal package used for building and deployment tests (e.g. the `7.1.1-ukf` tag published from a laptop). The local `.env` points at the test package; switch it to the official one once a corresponding image is published there.

## Upgrading from previous releases

When upgrading MTB-cBioPortal we *highly* suggest that you purge all volumes as it is likely that the database server is upgraded to a new major version and the cBioPortal seed database has been updated. 
**This will result in a complete loss of all data that hasn't been backed up before!** As cBioPortal loads its data from disk, you should still have this saved on disk. You can import the data again in the new version.

The 7.1.x release uses ClickHouse instead of MariaDB. If you are upgrading from a 6.x release, the existing studies must be re-imported into the new ClickHouse database after the switch (cBioPortal data is stored in the ClickHouse volume, which cannot be migrated from MariaDB). For that please follow these steps:

1. Move the directories `reports` and `study` to a different location.
2. Stop all services using `docker compose down -v` **This will permanently delete all volume data!**
3. Delete the MTB-cbioportal directory and make a fresh clone of the git repository using `git clone https://github.com/pm4onco/MTB-cbioportal.git`
4. Copy `reports` and `study` back into the MTB-cbioportal directory
5. Proceed with the installation as shown in [INSTALL.md](./INSTALL.md)

## Components

- OpenResty Reverse Proxy
  - cBioPortal (ClickHouse)
    - ClickHouse Server
    - cBioPortal Session Service
      - Mongo DB
  - Reports (local PDF files, study-level access check via cBioPortal)

The 6.x components FhirSpark, HAPI FHIR Server, PostgreSQL, Genome Nexus and Ensembl REST API are no longer part of the deployment; mutation annotation is provided by the public [Genome Nexus](https://www.genomenexus.org) instance (configurable via `GENOMENEXUS_URL` in `.env`).

## Ports

| Service | Path (behind OpenResty) | Port (dev overlay) | Image |
| - | - | - | - |
| OpenResty  | / | 8080 | openresty |
| cBioPortal | / | 8081 | `DOCKER_IMAGE_CBIOPORTAL` (GHCR, see above) |
| cBioPortal Debugger | - | 5005 | - |
| ClickHouse | - | 8123, 9000 | clickhouse |
| Session Service | - | - | cbioportal/session-service |
| Session Service DB | - | 27017 | mongo |

By default only the OpenResty port (8080) is published. The ports in the *dev overlay* column are additionally exposed by the optional debug overlay `docker-compose.dev.yml` (see below).


## Debugging

Debugging of the backend can be done by attaching a debugger to it. Start cBioPortal with the debug overlay to enable a JDWP remote debugger on port 5005 (and to expose the cBioPortal and database ports listed above):

```
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d cbioportal
```

The JDWP agent is passed via `JAVA_TOOL_OPTIONS`, so no change to the container command is needed. For Visual Studio Code the MSKCC provides an [example configuration](https://github.com/cBioPortal/cbioportal/blob/master/README.md#%EF%B8%8F%EF%B8%8F-debugging).

To test a local frontend build, use the frontend overlay `docker-compose.frontend.yml` (requires `FRONTEND_DIST` set in `.env`):

```
docker compose -f docker-compose.yml -f docker-compose.frontend.yml up -d cbioportal
```

## License
All code from MTB-cBioPortal is published under the [GNU AGPL v3 License](./LICENSE).
