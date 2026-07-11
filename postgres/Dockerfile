# PostgreSQL 16 with the pgAudit extension for database auditing.
# pgAudit is the core tool for Group 9 (Database Security Monitoring):
# it logs role changes, DDL, reads and writes in a structured, greppable format.
FROM postgres:16

# The official postgres image already has the PGDG apt repo configured,
# so we can pull the matching pgaudit build for PG 16.
RUN apt-get update \
    && apt-get install -y --no-install-recommends postgresql-16-pgaudit \
    && rm -rf /var/lib/apt/lists/*

# Where pgAudit / server logs are written. Promtail tails this directory,
# so it lives on a named volume shared with the promtail container.
RUN mkdir -p /var/log/postgresql \
    && chown -R postgres:postgres /var/log/postgresql
