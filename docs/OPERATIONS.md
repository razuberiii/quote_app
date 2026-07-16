# Operations

Update: `git pull --ff-only && docker build -t rubusoo:<sha> . && RUBUSOO_IMAGE=rubusoo:<sha> docker compose up -d`.

Logs: `docker compose logs -f --tail=200 web worker`.

Backup: `docker compose exec -T db pg_dump -U quote_app -Fc quote_app_production > /opt/data/quoteapp/backups/rubusoo-$(date +%Y%m%d%H%M%S).dump` and archive `/opt/data/quoteapp/storage`.

Rollback: set `RUBUSOO_IMAGE` to the prior immutable image tag and run `docker compose up -d`. Restore a database only when a non-reversible migration requires it.

Health: `curl -fsS http://127.0.0.1:3848/up`.
