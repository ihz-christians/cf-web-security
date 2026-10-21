# syntax=docker/dockerfile:1.6
# ------------------------------------------------------------------------------
# Mehrstufiges Image für Sicherheitsprüfungen
#
# Grundsätze:
# 1. Go- und Rust-Werkzeuge werden für die unterstützten Architekturen gebaut.
# 2. Einige Werkzeugversionen sind festgelegt; nicht alle Abhängigkeiten sind
#    versioniert, daher sind identische Builds nicht garantiert.
# 3. Das Laufzeit-Image enthält keine Go- oder Rust-Compiler.
# ------------------------------------------------------------------------------

################################################################################
# STUFE 1: GO-BUILD
################################################################################
FROM debian:12-slim AS go-builder

ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive
ENV GOBIN=/out
ENV PATH="/opt/go/bin:${PATH}"

# Abhängigkeiten zum Herunterladen von Go installieren
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Festgelegte Go-Version installieren
ARG GO_VERSION=1.22.3
RUN case "$TARGETARCH" in \
    amd64) GOARCH=amd64 ;; \
    arm64) GOARCH=arm64 ;; \
    *) echo "unsupported arch: $TARGETARCH" && exit 1 ;; \
    esac && \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${GOARCH}.tar.gz" \
    | tar -xz -C /opt

# Werkzeugversionen festlegen
ARG SUBFINDER_VER=v2.6.6
ARG DNSX_VER=v1.2.1
ARG HTTPX_VER=v1.6.7
ARG NUCLEI_VER=v3.2.4
ARG FFUF_VER=v2.1.0
ARG KITERUNNER_VER=v1.0.2
ARG GAU_VER=v2.2.3
ARG DALFOX_VER=v2.9.1

# Go-Werkzeuge gemeinsam installieren, um Build-Schichten zu reduzieren
RUN go install "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@${SUBFINDER_VER}" && \
    go install "github.com/projectdiscovery/dnsx/cmd/dnsx@${DNSX_VER}" && \
    go install "github.com/projectdiscovery/httpx/cmd/httpx@${HTTPX_VER}" && \
    go install "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@${NUCLEI_VER}" && \
    go install "github.com/ffuf/ffuf/v2@${FFUF_VER}" && \
    go install "github.com/assetnote/kiterunner/cmd/kiterunner@${KITERUNNER_VER}" && \
    go install "github.com/lc/gau/v2/cmd/gau@${GAU_VER}" && \
    go install "github.com/hahwul/dalfox/v2@${DALFOX_VER}" && \
    go install "github.com/tomnomnom/gf@latest" && \
    go install "github.com/tomnomnom/qsreplace@latest"

################################################################################
# STUFE 2: RUST-BUILD
################################################################################
FROM rust:1-slim-bookworm AS rust-builder

ENV CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse

# Build-Abhängigkeiten installieren (OpenSSL wird von mehreren Netzwerkwerkzeugen benötigt)
RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config \
    libssl-dev \
    git \
    make \
    perl \
    && rm -rf /var/lib/apt/lists/*

# Werkzeugversionen festlegen
ARG FEROXBUSTER_VER=2.10.0
ARG RUSTSCAN_VER=2.1.1

# Rust-Werkzeuge installieren.
# Die Installation erfolgt über crates.io statt über heruntergeladene Release-Dateien.
RUN cargo install feroxbuster --version ${FEROXBUSTER_VER} --locked && \
    cargo install rustscan --version ${RUSTSCAN_VER}

################################################################################
# STUFE 3: LAUFZEIT-IMAGE
################################################################################
FROM debian:12-slim

LABEL org.opencontainers.image.title="cf-web-api-security"
LABEL org.opencontainers.image.description="Go/Rust Pentest Toolkit for Cloudflare Pages, Workers, APIs"
LABEL org.opencontainers.image.licenses="MIT"

ENV DEBIAN_FRONTEND=noninteractive
ENV TESTSSL_INSTALL_DIR="/opt/testssl"
ENV PATH="/usr/local/bin:/opt/testssl:/etc/profile.d:${PATH}"

# Laufzeitabhängigkeiten
# nmap wird für bestimmte Funktionen von rustscan und ähnlichen Werkzeugen benötigt.
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    bsdextrautils \
    ca-certificates \
    curl \
    dnsutils \
    git \
    jq \
    netcat-traditional \
    nmap \
    nodejs \
    npm \
    python3 \
    python3-pip \
    openssl \
    procps \
    ripgrep \
    tini \
    unzip \
    util-linux \
    wget \
    xxd \
    && rm -rf /var/lib/apt/lists/*

# --- Drittanbieter-Repositories herunterladen und einrichten ---

# Festgelegter Tag für testssl.sh
ARG TESTSSL_TAG="3.2"
# Festgelegter Commit für h2csmuggler
ARG H2CSMUGGLER_COMMIT="7ea573a9b13bfce6d0f5d4a96a82e637a9dafe2e"

RUN \
    # 1. testssl.sh
    git clone --depth 1 --branch "${TESTSSL_TAG}" https://github.com/drwetter/testssl.sh.git /opt/testssl && \
    ln -s /opt/testssl/testssl.sh /usr/local/bin/testssl.sh && \
    # 2. h2csmuggler
    git clone https://github.com/BishopFox/h2csmuggler.git /opt/h2csmuggler && \
    cd /opt/h2csmuggler && git checkout "${H2CSMUGGLER_COMMIT}" && \
    if [ -f requirements.txt ]; then pip3 install -r requirements.txt --break-system-packages; fi && \
    chmod +x h2csmuggler.py && \
    ln -s /opt/h2csmuggler/h2csmuggler.py /usr/local/bin/h2csmuggler && cd / && \
    # 3. jwt_tool
    git clone --depth 1 https://github.com/ticarpi/jwt_tool.git /opt/jwt_tool && \
    pip3 install -r /opt/jwt_tool/requirements.txt --break-system-packages && \
    chmod +x /opt/jwt_tool/jwt_tool.py && \
    ln -s /opt/jwt_tool/jwt_tool.py /usr/local/bin/jwt_tool && \
    # 4. gf-Muster
    git clone https://github.com/1ndianl33t/Gf-Patterns /opt/gf-patterns && \
    mkdir -p /etc/skel/.gf && \
    cp /opt/gf-patterns/*.json /etc/skel/.gf/ && \
    rm -rf /opt/gf-patterns

# --- Python- und Node.js-Werkzeuge ---

# JavaScript-Lieferkette und Python-Werkzeuge
# retire.js, arjun (Parametersuche), semgrep (statische Quellcodeanalyse)
RUN npm install -g retire --no-fund --no-audit && \
    pip3 install arjun semgrep --break-system-packages

# --- Build-Ergebnisse übernehmen ---

# Go-Programme nach pip kopieren, damit etwa ProjectDiscovery-httpx Vorrang vor gleichnamigen Python-Paketen hat.
COPY --from=go-builder /out/* /usr/local/bin/
# Rust-Programme
COPY --from=rust-builder /usr/local/cargo/bin/feroxbuster /usr/local/bin/
COPY --from=rust-builder /usr/local/cargo/bin/rustscan /usr/local/bin/

# Kurzname für kiterunner
RUN ln -s /usr/local/bin/kiterunner /usr/local/bin/kr

# --- Konfiguration und Benutzer ---

# Shell-Profil
COPY container/profile.d/pentest.sh /etc/profile.d/pentest.sh
RUN chmod 0644 /etc/profile.d/pentest.sh

# Nicht privilegierten Benutzer einrichten
RUN useradd -m -u 10001 -s /bin/bash pentest && \
    mkdir -p /work/pentest && \
    chown -R pentest:pentest /work && \
    # gf-Muster zusätzlich im Benutzerverzeichnis ablegen.
    if [ -d "/etc/skel/.gf" ]; then \
    cp -r /etc/skel/.gf /home/pentest/ || true; \
    chown -R pentest:pentest /home/pentest/.gf; \
    fi

WORKDIR /work
USER pentest

# Tini als Einstiegspunkt für die Prozessverwaltung verwenden
ENTRYPOINT ["/usr/bin/tini", "--"]

# Standardbefehl, falls keiner angegeben wurde (interaktive Shell)
CMD ["/bin/bash"]
