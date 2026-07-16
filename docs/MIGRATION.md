# Migration

Migration `20260716000000_create_rubusoo_commercial_core` is additive. It preserves all existing users, companies, customers, products, quotes, quote items, shares and uploads. Companies receive plan/workspace fields; quotes receive follow-up and studio fields; new immutable commercial tables are introduced alongside legacy sharing.

Before production migration, create a PostgreSQL custom-format dump and storage archive. Rollback removes only the newly added Rubusoo commercial entities and columns; it does not rewrite legacy rows.
