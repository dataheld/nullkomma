ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}

ARG UBUNTU_VERSION
ARG R_VERSION
ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git build-essential gfortran sudo locales \
    && localedef -i en_US -f UTF-8 en_US.UTF-8 \
    && curl --fail --show-error --location \
      "https://cdn.posit.co/r/ubuntu-$(echo "$UBUNTU_VERSION" | tr -d .)/pkgs/r-${R_VERSION}_1_${TARGETARCH}.deb" \
      --output /tmp/r.deb \
    && apt-get install -y --no-install-recommends /tmp/r.deb \
    && rm /tmp/r.deb \
    && rm -rf /var/lib/apt/lists/*
ENV PATH="/opt/R/${R_VERSION}/bin:${PATH}" R_VERSION=${R_VERSION} UBUNTU_VERSION=${UBUNTU_VERSION}
ENV LANG=en_US.UTF-8
RUN useradd --create-home developer && mkdir /project && chown developer /project \
    && echo 'developer ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/developer
COPY --chown=developer:developer project /fixture
COPY run.sh /test.sh
USER developer
WORKDIR /project
