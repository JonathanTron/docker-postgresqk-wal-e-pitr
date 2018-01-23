FROM postgres:10.1-alpine

MAINTAINER Tron Jonathan <jonathan@tron.name>

# python3, wal-e
ENV \
  LZOP_VERSION=1.03 \
  WALE_VERSION=1.1.0

RUN set -x \
  && echo "@community http://nl.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories \
  && apk add --update python3 python3-dev wget openssl-dev bash sed jq curl alpine-sdk linux-headers musl-dev gnupg lzo-dev pv@community libffi-dev \
  && python3 -m ensurepip \
  && rm -r /usr/lib/python*/ensurepip \
  && pip3 install --upgrade pip setuptools \
  && rm -rf /root/.cache \
  && rm -rf /var/cache/apk/* \
  && pip3 install --no-cache-dir wal-e[aws,azure,google,swift]==${WALE_VERSION} awscli envdir --upgrade

# Install lzop from source.
RUN \
  wget https://www.lzop.org/download/lzop-${LZOP_VERSION}.tar.gz -O /tmp/lzop-${LZOP_VERSION}.tar.gz && \
  tar xvfz /tmp/lzop-${LZOP_VERSION}.tar.gz -C /tmp && \
  cd /tmp/lzop-${LZOP_VERSION} && \
  wget -q -O - "https://raw.githubusercontent.com/openembedded/openembedded-core/master/meta/recipes-support/lzop/lzop/lzop-1.03-gcc6.patch" | git apply -v && \
  ./configure && \
  make && \
  make install && \
  cd / && \
  rm -r /tmp/lzop-${LZOP_VERSION}*

RUN mv /usr/local/bin/docker-entrypoint.sh /usr/local/bin/docker-entrypoint-orig.sh
COPY postgresql.conf /var/lib/postgres/postgresql.conf
COPY pg_hba.conf /var/lib/postgres/pg_hba.conf
COPY entrypoint.sh /usr/local/bin/docker-entrypoint.sh
