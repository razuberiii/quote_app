# Migration

Migration `20260716000000_create_rubusoo_commercial_core` is additive. It preserves all existing users, companies, customers, products, quotes, quote items, shares and uploads. Companies receive plan/workspace fields; quotes receive follow-up and studio fields; new immutable commercial tables are introduced alongside legacy sharing.

Before production migration, create a PostgreSQL custom-format dump and storage archive. Rollback removes only the newly added Rubusoo commercial entities and columns; it does not rewrite legacy rows.

Production migration completed successfully on 2026-07-16. The post-migration custom-format backup is `/opt/data/quoteapp/backups/post-migration-20260716T020658Z.dump`. The deployment used a new PostgreSQL volume, so no legacy production rows were overwritten.
