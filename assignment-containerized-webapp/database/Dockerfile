FROM postgres:16-alpine

ENV POSTGRES_DB=studentdb
ENV POSTGRES_USER=admin
ENV POSTGRES_PASSWORD=admin123

COPY init.sql /docker-entrypoint-initdb.d/