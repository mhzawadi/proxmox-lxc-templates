# ENVIRONMENT VARIABLES
ENV DISPLAY=:1 \
    VNC_PORT=5901 \
    NO_VNC_PORT=8080 \
    VNC_COL_DEPTH=32 \
    VNC_RESOLUTION=1280x900 \
    DEBIAN_FRONTEND=noninteractive \
    TERM=xterm

# INSTALL DEPENDENCIES
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
    xvfb xauth fluxbox git \
    wget sudo git bzip2 python3 ca-certificates \
    tigervnc-standalone-server tigervnc-common firefox-esr; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*; \
    mkdir /src; \
    git clone --branch v1.7.0 --single-branch https://github.com/novnc/noVNC.git /opt/noVNC; \
    git clone --branch v0.13.0 --single-branch https://github.com/novnc/websockify.git /opt/noVNC/utils/websockify; \
    ln -s /opt/noVNC/vnc_lite.html /opt/noVNC/index.html

# GET PULSAR EDIT
RUN echo "I'm building for ${TARGETPLATFORM}"; \
    if [ "${TARGETPLATFORM}" = 'linux/arm64' ]; then \
      echo "getting ARM.Linux.pulsar_${PULSAR_VER}_arm64.deb"; \
      APT_FILE=ARM.Linux.pulsar_${PULSAR_VER}_arm64.deb; \
    else \
      echo "getting Linux.pulsar_${PULSAR_VER}_amd64.deb"; \
      APT_FILE=Linux.pulsar_${PULSAR_VER}_amd64.deb; \
    fi; \
    wget https://github.com/pulsar-edit/pulsar/releases/download/v${PULSAR_VER}/${APT_FILE}; \
    apt-get update && \
    apt-get -y install ./${APT_FILE}; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*; \
    rm -f ./${APT_FILE}

COPY entrypoint.sh /src

EXPOSE 5901 8080
ENTRYPOINT ["/src/entrypoint.sh"]
