FROM debian:bookworm-slim AS build

COPY install-zola.sh /app/install-zola.sh
RUN apt-get -qq update \
    && apt-get install --yes -qq curl tar gzip \
    && bash /app/install-zola.sh

WORKDIR /app
COPY . /app
RUN zola build

FROM nginx:stable-alpine
ARG COMMIT_HASH="none"
ARG COMMIT_TAG="none"
LABEL COMMIT_TAG=$COMMIT_TAG
LABEL COMMIT_HASH=$COMMIT_HASH

COPY --chown=nginx:nginx --from=build /app/public/* /usr/share/nginx/html/
# COPY default.conf /etc/nginx/conf.d/default.conf
HEALTHCHECK --interval=5m --timeout=3s CMD curl --fail http://localhost || exit 1

ARG COMMIT_HASH="none"
ARG COMMIT_TAG="none"
ENV COMMIT_HASH=$COMMIT_HASH
ENV COMMIT_TAG=$COMMIT_TAG
LABEL commit-hash=$COMMIT_HASH
LABEL commit-tag=$COMMIT_TAG

ENTRYPOINT [ "nginx" , "-g", "daemon off;"]
