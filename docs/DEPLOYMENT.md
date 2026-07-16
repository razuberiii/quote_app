# Deployment

Production runs from `/opt/stacks/quoteapp` with persistent state in `/opt/data/quoteapp`. PostgreSQL is internal only; Rails binds `127.0.0.1:3848`; web and worker use the same image. Copy `.env.production.example` to `.env.production`, fill secrets, then:

```sh
docker build -t rubusoo:<git-sha> .
RUBUSOO_IMAGE=rubusoo:<git-sha> docker compose up -d
```

Nginx must proxy the selected unused subdomain to `127.0.0.1:3848`. Before modification back up relevant configuration under `/root/nginx-conf-backups/<timestamp>/`, run `nginx -t`, then reload. Never edit the root-domain server block.
