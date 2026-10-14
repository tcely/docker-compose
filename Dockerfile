# syntax=docker/dockerfile:1
# check=error=true

ARG VERSION_ALPINE='3.24'
ARG VERSION_COMPOSE='2.40.3'
ARG VERSION_DCP='0.9.10'
ARG VERSION_PASS='1.7.4'

FROM "docker/compose-bin:v${VERSION_COMPOSE}" AS compose-bin

FROM scratch AS downloads
WORKDIR /downloaded
ADD https://github.com/tcely/docker-restic/raw/master/SigningKeys.pass /downloaded/

ARG VERSION_DCP
ADD "https://github.com/docker/docker-credential-helpers/releases/download/v${VERSION_DCP}/docker-credential-pass-v${VERSION_DCP}.linux-amd64" /downloaded/docker-credential-pass
ADD "https://github.com/docker/docker-credential-helpers/releases/download/v${VERSION_DCP}/checksums.txt" /downloaded/docker-credential-pass.checksums.txt

FROM docker:26-cli

ARG VERSION_ALPINE
RUN mv -v /etc/apk/repositories /etc/apk/repositories.orig && \
    cp -v -p /etc/apk/repositories.orig /etc/apk/repositories && \
    sed -e "s,/v[0-9][^/]*/,/v${VERSION_ALPINE}/," /etc/apk/repositories.orig > /etc/apk/repositories && \
    diff -u /etc/apk/repositories.orig /etc/apk/repositories || :
ENV ALPINE_VERSION="v${VERSION_ALPINE}"

RUN --mount=type=tmpfs,target=/var/cache/apk \
    apk --update upgrade -a && \
    apk add \
        bash coreutils git gnupg \
    && \
    apk add --virtual .build-depends \
        make

COPY --chmod=+rx docker-compose-entrypoint.sh /usr/local/bin/docker-compose-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-compose-entrypoint.sh"]
RUN rm -v -f /usr/local/bin/docker-compose
COPY --from=compose-bin --chmod=+rx /docker-compose /usr/local/bin/docker-compose

ARG VERSION_PASS
RUN --mount=type=tmpfs,target=/tmp \
    --mount=type=bind,source=/downloaded/SigningKeys.pass,target=/tmp/SigningKeys.pass,from=downloads \
    mkdir -v -m 0700 -p /root/.gnupg && \
    gpg2 --no-options --verbose --keyid-format 0xlong --keyserver-options auto-key-retrieve=true \
        --import /tmp/SigningKeys.pass && \
    git clone --no-checkout --dissociate --reference-if-able /password-store.git \
    'https://git.zx2c4.com/password-store' \
    '/root/password-store' && \
    (cd '/root/password-store' && \
        git tag -v "${VERSION_PASS}" && \
        git checkout "${VERSION_PASS}" && \
        make PREFIX='/usr/local' install \
    ) && \
    apk del --purge .build-depends && \
    rm -rf /var/cache/apk/* /root/.gnupg /root/password-store
ENV PASS_VERSION="${VERSION_PASS}"

ARG VERSION_DCP
RUN --mount=type=tmpfs,target=/tmp \
    --mount=type=bind,source=/downloaded/docker-credential-pass,target=/tmp/docker-credential-pass,from=downloads \
    --mount=type=bind,source=/downloaded/docker-credential-pass.checksums.txt,target=/tmp/docker-credential-pass.checksums.txt,from=downloads \
    cd /tmp && \
    ln -v -s -f -T docker-credential-pass "docker-credential-pass-v${VERSION_DCP}.linux-amd64" && \
    cksum -a sha256 --check --strict --warn --ignore-missing docker-credential-pass.checksums.txt && \
    install -v -p -o root -g root -m 00755 -t /usr/local/bin/ /tmp/docker-credential-pass
ENV DOCKER_CREDENTIAL_PASS_VERSION="v${VERSION_DCP}"

