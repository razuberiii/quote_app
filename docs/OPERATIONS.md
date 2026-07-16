# Operations

Update: `git pull --ff-only && docker build -t rubusoo:<sha> . && RUBUSOO_IMAGE=rubusoo:<sha> docker compose --env-file .env.production up -d`.

Logs: `docker compose logs -f --tail=200 web worker`.

Backup: `docker compose exec -T db pg_dump -U quote_app -Fc quote_app_production > /opt/data/quoteapp/backups/rubusoo-$(date +%Y%m%d%H%M%S).dump` and archive `/opt/data/quoteapp/storage`.

Rollback: `RUBUSOO_IMAGE=rubusoo:<previous-sha> docker compose --env-file .env.production up -d`. Restore a database only when a non-reversible migration requires it.

Current database backup: `/opt/data/quoteapp/backups/post-migration-20260716T020658Z.dump`. Nginx backup: `/root/nginx-conf-backups/20260716T021026Z`.

Health: `curl -fsS http://127.0.0.1:3848/up`.
