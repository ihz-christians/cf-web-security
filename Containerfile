# syntax=docker/dockerfile:1.6
# ------------------------------------------------------------------------------
# Golden Phat: Robust, Multi-Stage Security Toolkit
#
# Principles:
# 1. Source-Based: Builds Go and Rust tools from source to guarantee availability
#    and architecture compatibility (AMD64/ARM64).
# 2. Immutable: Pinning versions ensures builds are reproducible.
# 3. Minimal: The final runtime image contains only binaries, no compilers.
# ------------------------------------------------------------------------------

################################################################################
# STAGE 1: GO BUILDER
################################################################################
FROM debian:12-slim AS go-builder

ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive
ENV GOBIN=/out
ENV PATH="/opt/go/bin:${PATH}"

# Install dependencies for downloading Go
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Go (Pinned Version)
ARG GO_VERSION=1.22.3
RUN case "$TARGETARCH" in \
    amd64) GOARCH=amd64 ;; \
    arm64) GOARCH=arm64 ;; \
    *) echo "unsupported arch: $TARGETARCH" && exit 1 ;; \
    esac && \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${GOARCH}.tar.gz" \
    | tar -xz -C /opt

# Define tool versions
ARG SUBFINDER_VER=v2.6.6
ARG DNSX_VER=v1.2.1
ARG HTTPX_VER=v1.6.7
ARG NUCLEI_VER=v3.2.4
ARG FFUF_VER=v2.1.0
ARG KITERUNNER_VER=v1.0.2
ARG GAU_VER=v2.2.3
ARG DALFOX_VER=v2.9.1

# Compile Go tools (Grouped to reduce layers and cache)
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
# STAGE 2: RUST BUILDER
################################################################################
FROM rust:1-slim-bookworm AS rust-builder

ENV CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse

# Install compilation dependencies (OpenSSL is required for many network tools)
RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config \
    libssl-dev \
    git \
    make \
    perl \
    && rm -rf /var/lib/apt/lists/*

# Define tool versions
ARG FEROXBUSTER_VER=2.10.0
ARG RUSTSCAN_VER=2.1.1

# Compile Rust tools
# We install from crates.io which is more reliable than scraping release assets
RUN cargo install feroxbuster --version ${FEROXBUSTER_VER} --locked && \
    cargo install rustscan --version ${RUSTSCAN_VER}

################################################################################
# STAGE 3: RUNTIME IMAGE
################################################################################
FROM debian:12-slim

LABEL org.opencontainers.image.title="cf-web-api-security"
LABEL org.opencontainers.image.description="Go/Rust Pentest Toolkit for Cloudflare Pages, Workers, APIs"
LABEL org.opencontainers.image.licenses="MIT"

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/usr/local/bin:/opt/testssl:/etc/profile.d:${PATH}"

# Runtime dependencies
# Note: 'nmap' is often required by rustscan or similar tools for full functionality
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
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
    && rm -rf /var/lib/apt/lists/*

# --- Copy Artifacts from Builders ---

# Go Binaries
COPY --from=go-builder /out/* /usr/local/bin/
# Rust Binaries
COPY --from=rust-builder /usr/local/cargo/bin/feroxbuster /usr/local/bin/
COPY --from=rust-builder /usr/local/cargo/bin/rustscan /usr/local/bin/

# Convenience alias for kiterunner & jwt_tool
RUN ln -s /usr/local/bin/kiterunner /usr/local/bin/kr

# --- Third-Party Repositories (Cloned & Configured) ---

# testssl.sh (Pinned Tag)
ARG TESTSSL_TAG="3.2"
# h2csmuggler (Pinned Commit)
ARG H2CSMUGGLER_COMMIT="7ea573a9b13bfce6d0f5d4a96a82e637a9dafe2e"

RUN \
    # 1. testssl.sh
    git clone --depth 1 --branch "${TESTSSL_TAG}" https://github.com/drwetter/testssl.sh.git /opt/testssl && \
    # 2. h2csmuggler
    git clone https://github.com/BishopFox/h2csmuggler.git /opt/h2csmuggler && \
    cd /opt/h2csmuggler && git checkout "${H2CSMUGGLER_COMMIT}" && cd / && \
    # 3. jwt_tool
    git clone --depth 1 https://github.com/ticarpi/jwt_tool.git /opt/jwt_tool && \
    pip3 install -r /opt/jwt_tool/requirements.txt --break-system-packages && \
    chmod +x /opt/jwt_tool/jwt_tool.py && \
    ln -s /opt/jwt_tool/jwt_tool.py /usr/local/bin/jwt_tool && \
    # 4. Gf Patterns
    git clone https://github.com/1ndianl33t/Gf-Patterns /opt/gf-patterns && \
    mkdir -p /etc/skel/.gf && \
    cp /opt/gf-patterns/*.json /etc/skel/.gf/ && \
    rm -rf /opt/gf-patterns

# --- Python & Node Tools ---

# JS Supply Chain & Python Tools
# retire.js, arjun (Parameter Discovery), semgrep (SAST)
RUN npm install -g retire --no-fund --no-audit && \
    pip3 install arjun semgrep --break-system-packages

# --- Configuration & User ---

# Shell profile
COPY container/profile.d/pentest.sh /etc/profile.d/pentest.sh
RUN chmod 0644 /etc/profile.d/pentest.sh

# Non-root user setup
RUN useradd -m -u 10001 -s /bin/bash pentest && \
    mkdir -p /work/pentest && \
    chown -R pentest:pentest /work && \
    # Ensure gf patterns are in user home (redundancy for safety)
    if [ -d "/etc/skel/.gf" ]; then \
    cp -r /etc/skel/.gf /home/pentest/ || true; \
    chown -R pentest:pentest /home/pentest/.gf; \
    fi

WORKDIR /work
USER pentest

# Tini entrypoint for process safety
ENTRYPOINT ["/usr/bin/tini", "--"]

# Default command if none provided (interactive shell)
CMD ["/bin/bash"]
