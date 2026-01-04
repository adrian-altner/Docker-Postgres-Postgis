FROM postgres:16

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    postgis \
    postgresql-16-postgis-3 \
    postgresql-16-postgis-3-scripts \
  && rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint-initdb.d/ /docker-entrypoint-initdb.d/
RUN chmod -R a+rx /docker-entrypoint-initdb.d

COPY pg-extra-apply.template.sh /usr/local/bin/pg-extra-apply.template.sh
COPY entrypoint-wrapper.sh /usr/local/bin/entrypoint-wrapper.sh
RUN chmod a+rx /usr/local/bin/pg-extra-apply.template.sh /usr/local/bin/entrypoint-wrapper.sh

ENTRYPOINT ["/usr/local/bin/entrypoint-wrapper.sh"]
