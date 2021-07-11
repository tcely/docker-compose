FROM docker/compose:1.29.2
LABEL maintainer="https://keybase.io/tcely"

ENV ALPINE_VERSION=v3.13

RUN mv -v /etc/apk/repositories /etc/apk/repositories.orig && \
    cp -v -p /etc/apk/repositories.orig /etc/apk/repositories && \
    sed -e "s,/v[0-9][^/]*/,/${ALPINE_VERSION}/," /etc/apk/repositories.orig > /etc/apk/repositories && \
    diff -u /etc/apk/repositories.orig /etc/apk/repositories || :

ENV PASS_VERSION=1.7.4

RUN apk --update upgrade -a && \
    apk add \
        bash git gnupg \
    && \
    apk add --virtual .build-depends \
        make \
    && \
    rm -rf /var/cache/apk/*

ADD https://github.com/tcely/docker-restic/raw/master/SigningKeys.pass /tmp/

RUN mkdir -v -m 0700 -p /root/.gnupg && \
    gpg2 --no-options --verbose --keyid-format 0xlong --keyserver-options auto-key-retrieve=true \
        --import /tmp/SigningKeys.pass && \
    git clone --no-checkout --dissociate --reference-if-able /password-store.git \
    'https://git.zx2c4.com/password-store' \
    '/root/password-store' && \
    (cd '/root/password-store' && \
        git tag -v "${PASS_VERSION}" && \
        git checkout "${PASS_VERSION}" && \
        make PREFIX='/usr/local' install \
    ) && \
    apk del --purge .build-depends && \
    rm -rf /var/cache/apk/* /root/.gnupg /tmp/SigningKeys.pass /root/password-store

ENV DCP_VERSION=v0.6.4

ADD https://github.com/docker/docker-credential-helpers/releases/download/${DCP_VERSION}/docker-credential-pass-${DCP_VERSION}-amd64.tar.gz /tmp/docker-credential-pass.tar.gz

RUN tar -C /tmp/ -zxvvpf /tmp/docker-credential-pass.tar.gz && \
    rm -v /tmp/docker-credential-pass.tar.gz && \
    install -v -p -o root -g root -m 00755 -t /usr/local/bin/ /tmp/docker-credential-pass && \
    rm -v /tmp/docker-credential-pass

