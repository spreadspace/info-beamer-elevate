FROM ubuntu:bionic

LABEL maintainer="Christian Pointner <equinox@spreadspace.org>"

ARG APT_MIRROR=http://archive.ubuntu.com/ubuntu
ARG APT_MIRROR_SECURITY=http://archive.ubuntu.com/ubuntu
RUN set -x \
    && echo "deb ${APT_MIRROR} bionic main universe" > /etc/apt/sources.list \
    && echo "deb ${APT_MIRROR} bionic-updates main universe" >> /etc/apt/sources.list \
    && echo "deb ${APT_MIRROR_SECURITY} bionic-security main universe" >> /etc/apt/sources.list \
    && echo 'APT::Install-Recommends "false";' > /etc/apt/apt.conf.d/02-norecommends \
    && apt-get update -q \
    && apt-get upgrade -y -q \
    && apt-get install -y -q tzdata locales curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN set -x \
    && apt-get update -q \
    && apt-get upgrade -y -q \
    && apt-get install -y -q python python-pyinotify python-requests python-tz \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN adduser --home /space --no-create-home --system --uid 1000 --group info-beamer

USER info-beamer
