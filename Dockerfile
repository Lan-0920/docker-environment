# ==============================================================================
# Stage 1: Base 
# ==============================================================================
FROM ubuntu:26.04 AS base
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Taipei

RUN touch /var/mail/ubuntu && chown ubuntu /var/mail/ubuntu || true && \
    userdel -r ubuntu || true

ARG USERNAME=jane
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
    g++\
    libfl-dev \
    libfl2 \
    zlib1g \
    && rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/bin/python3 /usr/bin/python
RUN pip install --break-system-packages pytest

# ==============================================================================
# Stage 3: Verilator v5.032 
# ==============================================================================
FROM common_pkg_provider AS verilator_5_032

WORKDIR /tmp
RUN git clone https://github.com/verilator/verilator.git \
    && cd verilator \
    && git checkout v5.032 \
    && unset VERILATOR_ROOT \
    && autoconf \
    && ./configure --prefix=/opt/verilator/v5.032 CXXFLAGS="-std=c++17 -fpermissive -Wno-error" \
    && make -j$(nproc) \
    && make install

# ==============================================================================
# Stage 4: SystemC Provider
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
# Stage 5: Release 
# ==============================================================================
FROM common_pkg_provider AS release

# 1. copy SystemC
COPY --from=systemc_provider /opt/systemc-2.3.4 /opt/systemc-2.3.4

# 2. copy Verilator 
COPY --from=verilator_5_032 /opt/verilator/v5.032 /opt/verilator/v5.032

# 3. create symbolic link for Verilator
RUN ln -sf /opt/verilator/v5.032/bin/verilator /usr/local/bin/verilator

# 4. copy eman.sh to /usr/local/bin and make it executable
COPY eman.sh /usr/local/bin/eman
RUN chmod +x /usr/local/bin/eman

# 5. set environment variables
ENV SYSTEMC_HOME=/opt/systemc-2.3.4
ENV LD_LIBRARY_PATH=$SYSTEMC_HOME/lib-linux64

USER $USERNAME
WORKDIR /home/$USERNAME

CMD ["/bin/bash"]