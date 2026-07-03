# ==============================================================================
# Stage 1: Base 
# ==============================================================================
FROM ubuntu:26.04 AS base

# set noninteractive mode for apt-get to avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
# set timezone to Taipei
ENV TZ=Asia/Taipei

# create a non-root user to avoid file permission conflicts between host and container
ARG USERNAME=user
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(ALL\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# ==============================================================================
# Stage 2: Common Package Provider 
# ==============================================================================
FROM base AS common_pkg_provider

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    ccache \
    curl \
    git \
    gnupg \
    libgoogle-perftools-dev \
    numactl \
    perl \
    python3 \
    python3-pip \
    unzip \
    vim \
    wget \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --break-system-packages pytest

# ==============================================================================
# Stage 3: Verilator Provider 
# ==============================================================================
FROM common_pkg_provider AS verilator_provider

WORKDIR /tmp
# copy Verilator v5.024
RUN git clone https://github.com/verilator/verilator.git \
    && cd verilator \
    && git checkout v5.024 \
    && autoconf \
    && ./configure \
    && make -j$(nproc) \
    && make install

# ==============================================================================
# Stage 4: SystemC Provider 
# ==============================================================================
FROM common_pkg_provider AS systemc_provider

WORKDIR /tmp
# download and unpack SystemC 2.3.4
RUN wget https://github.com/accellera-official/systemc/archive/refs/tags/2.3.4.tar.gz \
    && tar -xf 2.3.4.tar.gz \
    && cd systemc-2.3.4 \
    && mkdir objdir \
    && cd objdir \
    && ../configure --prefix=/usr/local/systemc-2.3.4 \
    && make -j$(nproc) \
    && make install

# ==============================================================================
# Stage 5: Release 
# ==============================================================================

FROM common_pkg_provider AS release

# copy tool from verilator_provider 
COPY --from=verilator_provider /usr/local/ /usr/local/

# copy compiled SystemC libraries from systemc_provider
COPY --from=systemc_provider /usr/local/systemc-2.3.4 /usr/local/systemc-2.3.4

# set SystemC environment variables
ENV SYSTEMC_HOME=/usr/local/systemc-2.3.4
ENV LD_LIBRARY_PATH=$SYSTEMC_HOME/lib-linux64:$LD_LIBRARY_PATH

# set non-root user and working directory
USER user
WORKDIR /home/user
# set default command to bash
CMD ["/bin/bash"]