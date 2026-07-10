FROM postgres:16

# Install pgAudit from the PGDG apt repo that's already configured
# in the official postgres image
RUN apt-get update \
    && apt-get install -y --no-install-recommends postgresql-16-pgaudit \
    && rm -rf /var/lib/apt/lists/*
