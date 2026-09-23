# Deploying reportd with Docker Compose

Three self-contained stacks. Copy the folder you need (including `.env.example`), then:

```bash
cp .env.example .env
# edit .env
docker compose up -d
```

| Directory | Where | Traefik | BigQuery | Image |
|-----------|--------|---------|----------|--------|
| [external-no-gcp](external-no-gcp/) | Shared external dev (same pattern as other env stacks) | Yes (`ext_traefik`) | Dummy `REPORTD_*` values; BQ errors in logs are expected | `ghcr.io/blackberrius/reportd:latest` |
| [external-bigquery](external-bigquery/) | Same host/networks | Yes | Real GCP project, dataset, three tables, service-account JSON | `ghcr.io/blackberrius/reportd:latest` |
| [local-macos](local-macos/) | Laptop | No | Dummy values | Fork GHCR **or** local `Dockerfile` |

Health check: `GET /healthz`.

CI publishes multi-arch images from `develop` (`:develop` and `:latest`) and `main` (`:main`). Stacks default to `ghcr.io/blackberrius/reportd:latest`. After the first successful workflow run, make the package public (or grant pull access) under the repo's Packages settings if hosts need to pull without auth.

Browser Reporting API endpoints must be served over HTTPS. On the external stacks Traefik terminates TLS. On macOS use `http://localhost:8080` only for the dashboard and local tests.

Do not commit `.env` or `gcp-service-account.json`.

## External stacks

Requires Docker networks that already exist on the host:

- `ext_traefik` — Traefik listens here (`webinsecure` / `websecure`, `letsencrypt`)
- `inbound` — attached to Postgres (same convention as other services on that host)

The compose file also creates a project bridge named `${ENV_NAME}` (default `reportd`). Point DNS `${ENV_NAME}.${ENV_DOMAIN}` (for example `reportd.b-fine.be`) at the Traefik host.

Postgres data: `./postgres/pgdata` next to the compose file.

### Without GCP

`REPORTD_PROJECT`, `REPORTD_DATASET`, and table names must still be set (empty values stop the process). The example file uses `local` placeholders and does not mount credentials.

### With BigQuery

1. Create the GCP dataset and three empty tables that match `REPORTD_*` in `.env`.
2. Place a service-account key as `gcp-service-account.json` in this directory (write access to those tables).
3. Set real `REPORTD_PROJECT` and `REPORTD_DATASET` in `.env`.

reportd does not create the GCP project, dataset, or tables.

## macOS (no Traefik)

From this directory:

```bash
cp .env.example .env
docker compose pull
docker compose up -d
```

Dashboard: http://localhost:8080

Build from the repo `Dockerfile` (build context is the repository root):

```bash
docker compose up -d --build
```

Postgres uses a named volume (`reportd-pgdata`). Port 5432 is not published, so a local Postgres on the host is not occupied.

SQLite instead of Postgres (no Postgres service; database file on named volume `reportd-sqlite` at `/data`, writable by the app user):

```bash
docker compose -f docker-compose.sqlite.yml up -d
docker compose -f docker-compose.sqlite.yml up -d --build
```
