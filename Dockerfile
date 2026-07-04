# ==============================================================================
# Stage 1: Base 
# ==============================================================================
FROM ubuntu:26.04 AS base
# set noninteractive mode for apt-get to avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
# set timezone to Asia/Taipei
ENV TZ=Asia/Taipei

RUN touch /var/mail/ubuntu && chown ubuntu /var/mail/ubuntu || true && \
    userdel -r ubuntu || true

ARG USERNAME=myuser
ARG USER_UID=1000
ARG USER_GID=1000

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
    autoconf \    
    automake \    
    gperf \       
    flex \        
    bison \ 
    file \
    libtool \
    help2man \
    bc \
    verilator \   
    && rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/bin/python3 /usr/bin/python
RUN pip install --break-system-packages pytest

# ==============================================================================
# Stage 3: SystemC Provider 
# ==============================================================================
FROM common_pkg_provider AS systemc_provider

WORKDIR /tmp
RUN git clone https://github.com/accellera-official/systemc.git \
    && cd systemc \
    && git checkout 2.3.4 \
    && autoreconf --install \
    && mkdir objdir \
    && cd objdir \
    && ../configure --prefix=/opt/systemc-2.3.4 CXXFLAGS="-std=c++17 -fpermissive" \
    && make -j$(nproc) \
    && make install

# ==============================================================================
# Stage 4: Release 
# ==============================================================================
FROM common_pkg_provider AS release

# 1. copy systemc from systemc_provider stage to release stage
COPY --from=systemc_provider /opt/systemc-2.3.4 /opt/systemc-2.3.4

# 2. copy and rename the frontend management tool eman.sh to the container's system tool eman
COPY eman.sh /usr/local/bin/eman
RUN chmod +x /usr/local/bin/eman

# 3. set environment variables
ENV SYSTEMC_HOME=/opt/systemc-2.3.4
ENV LD_LIBRARY_PATH=$SYSTEMC_HOME/lib-linux64

USER myuser
WORKDIR /home/myuser

CMD ["/bin/bash"]