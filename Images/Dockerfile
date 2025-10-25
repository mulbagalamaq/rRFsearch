FROM ubuntu:22.04

LABEL maintainer="anirudhbantwalbaliga@gmail.com"
LABEL description="Atria - Ultra-fast and accurate adapter and quality trimming"

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
    wget \
    g++ \
    make \
    zlib1g-dev \
    libsuitesparse-dev \
    libopenblas-dev \
    pigz \
    pbzip2 \
    && rm -rf /var/lib/apt/lists/*

# Download and install Atria
WORKDIR /opt
RUN wget https://github.com/cihga39871/Atria/releases/download/v4.1.4/atria-4.1.4-linux-ubuntu22.tar.gz && \
    tar -xxf atria-4.1.4-linux-ubuntu22.tar.gz && \
    rm atria-4.1.4-linux-ubuntu22.tar.gz && \
    chmod +x atria-4.1.4/bin/atria

# Add to PATH
ENV PATH="/opt/atria-4.1.4/bin:${PATH}"

WORKDIR /data

# Test installation
RUN atria --version
