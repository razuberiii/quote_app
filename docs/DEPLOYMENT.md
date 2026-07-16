# Deployment

Current production deployment: `https://next.rubusoo.com`, commit `63c805c`, image `rubusoo:63c805c`. Nginx configuration is `/etc/nginx/sites-available/next.rubusoo.com`; the pre-change backup is `/root/nginx-conf-backups/20260716T021026Z`. The Let's Encrypt certificate expires 2026-10-14 and has automatic renewal configured.

Production runs from `/opt/stacks/quoteapp` with persistent state in `/opt/data/quoteapp`. PostgreSQL is internal only; Rails binds `127.0.0.1:3848`; web and worker use the same image. Copy `.env.production.example` to `.env.production`, fill secrets, then:

```sh
docker build -t rubusoo:<git-sha> .
RUBUSOO_IMAGE=rubusoo:<git-sha> docker compose --env-file .env.production up -d
```

Nginx must proxy the selected unused subdomain to `127.0.0.1:3848`. Before modification back up relevant configuration under `/root/nginx-conf-backups/<timestamp>/`, run `nginx -t`, then reload. Never edit the root-domain server block.
