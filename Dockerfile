ARG UBUNTU_VERSION=20.04
ARG DEFAULT_INSTALL_SELECTION=yes
ARG INSTALL_KERNEL=${DEFAULT_INSTALL_SELECTION}
ARG INSTALL_CAPSTONE=${DEFAULT_INSTALL_SELECTION}
ARG INSTALL_VIRTIOFSD=${DEFAULT_INSTALL_SELECTION}
ARG INSTALL_GDB=${DEFAULT_INSTALL_SELECTION}
ARG INSTALL_TOOLS_APT=${DEFAULT_INSTALL_SELECTION}
ARG INSTALL_TOOLS_PIP=${DEFAULT_INSTALL_SELECTION}  

FROM ubuntu:${UBUNTU_VERSION} as essentials

SHELL ["/bin/bash", "-ceov", "pipefail"]

ENV DEBIAN_FRONTEND noninteractive
ENV LC_CTYPE=C.UTF-8

RUN <<EOF
    rm -f /etc/apt/apt.conf.d/docker-clean
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

    (set +o pipefail; yes | unminimize)

    dpkg --add-architecture i386

    apt-get clean && rm -rf /var/lib/apt/lists/*
EOF

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && xargs apt-get install --no-install-recommends -yqq <<EOF && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
        ca-certificates
        curl
        netcat-openbsd
        socat
        sudo
        vim
        wget
        unzip
EOF

RUN rm -f /usr/lib/python3.*/EXTERNALLY-MANAGED


################################################################################
# Essential tools
FROM essentials as builder-essentials

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && xargs apt-get install --no-install-recommends -yqq <<EOF && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
        build-essential
EOF

################################################################################
# Basic tools
FROM builder-essentials as builder

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && xargs apt-get install --no-install-recommends -yqq <<EOF && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
        autoconf
        bc
        bison
        cargo
        clang
        cmake
        cpio
        flex
	    dwarves
        g++-multilib
        gcc-multilib
        git
        libc6-dev-i386
        libc6:i386
        libedit-dev
        libelf-dev
        libffi-dev
        libglib2.0-dev
        libgmp-dev
        libini-config-dev
        libncurses5:i386
        libpcap-dev
        libpixman-1-dev
        libseccomp-dev
        libssl-dev
        libstdc++6:i386
        libtool-bin
        llvm
        man-db
        manpages-dev
        nasm
        python-is-python3
        python3-dev
        python3-pip
        rubygems
        squashfs-tools
        upx-ucl
        p7zip-full
EOF

################################################################################
# Kernel

FROM builder as builder-kernel-no
RUN mkdir /opt/linux
FROM builder as builder-kernel-yes
COPY ./linux-5.4.tar.gz /
RUN <<EOF
    mkdir /opt/linux
    cp linux-5.4.tar.gz /opt/linux
    tar -C /opt/linux -xf /opt/linux/linux-5.4.tar.gz
    cd /opt/linux/linux-5.4
    make defconfig
EOF

RUN awk '{$1=$1};1' >> /opt/linux/linux-5.4/.config <<EOF
    CONFIG_9P_FS=y
    CONFIG_9P_FS_POSIX_ACL=y
    CONFIG_9P_FS_SECURITY=y
    CONFIG_BALLOON_COMPACTION=y
    CONFIG_CRYPTO_DEV_VIRTIO=y
    CONFIG_DEBUG_FS=y
    CONFIG_DEBUG_INFO=y
    CONFIG_DEBUG_INFO_BTF=y
    CONFIG_DEBUG_INFO_DWARF4=y
    CONFIG_DEBUG_INFO_REDUCED=n
    CONFIG_DEBUG_INFO_SPLIT=n
    CONFIG_DEVPTS_FS=y
    CONFIG_DRM_VIRTIO_GPU=y
    CONFIG_FRAME_POINTER=y
    CONFIG_GDB_SCRIPTS=y
    CONFIG_HW_RANDOM_VIRTIO=y
    CONFIG_HYPERVISOR_GUEST=y
    CONFIG_NET_9P=y
    CONFIG_NET_9P_DEBUG=n
    CONFIG_NET_9P_VIRTIO=y
    CONFIG_PARAVIRT=y
    CONFIG_PCI=y
    CONFIG_PCI_HOST_GENERIC=y
    CONFIG_VIRTIO_BALLOON=y
    CONFIG_VIRTIO_BLK=y
    CONFIG_VIRTIO_BLK_SCSI=y
    CONFIG_VIRTIO_CONSOLE=y
    CONFIG_VIRTIO_INPUT=y
    CONFIG_VIRTIO_NET=y
    CONFIG_VIRTIO_PCI=y
    CONFIG_VIRTIO_PCI_LEGACY=y
EOF

RUN <<EOF
    cd /opt/linux/linux-5.4
    make -j$(nproc) bzImage
    ln -sf $PWD/arch/x86/boot/bzImage ../bzImage
    ln -sf $PWD/vmlinux ../vmlinux
EOF

# compile scripts for gdb ultilites
RUN <<EOF 
    cd /opt/linux/linux-5.4 
    make -j$(nproc) scripts_gdb 
EOF

FROM builder-kernel-${INSTALL_KERNEL} as builder-kernel

################################################################################
# Virtiofsd

FROM builder as builder-virtiofsd-no
RUN mkdir /opt/virtiofsd
FROM builder as builder-virtiofsd-yes
RUN <<EOF
    mkdir /opt/virtiofsd && cd "$_"
    wget -q -O ./build.zip "https://gitlab.com/virtio-fs/virtiofsd/-/jobs/artifacts/main/download?job=publish"
    unzip -p ./build.zip "$(zipinfo -1 ./build.zip | head -n1)" > ./virtiofsd
    rm -f ./build.zip
    chmod +x ./virtiofsd
EOF
FROM builder-virtiofsd-${INSTALL_VIRTIOFSD} as builder-virtiofsd


################################################################################
# capstone

FROM builder as builder-capstone-no
FROM builder as builder-capstone-yes
RUN <<EOF
    git clone --depth 1 https://github.com/capstone-engine/capstone /opt/capstone
    cd /opt/capstone
    make
    make install
EOF
FROM builder-capstone-${INSTALL_CAPSTONE} as builder-capstone

################################################################################
# GDB

FROM builder as builder-gdb-no
FROM builder as builder-gdb-yes

RUN <<EOF
    mkdir /opt/gdb
    wget -O - https://ftp.gnu.org/gnu/gdb/gdb-11.1.tar.gz | tar xzC /opt/gdb
    cd /opt/gdb/gdb-11.1
    mkdir build
    cd build
    ../configure --prefix=/usr --with-python=/usr/bin/python3
    make -j$(nproc)
    make install
EOF

RUN <<EOF
    git clone --depth 1 --recurse-submodules https://github.com/pwndbg/pwndbg /opt/pwndbg
    cd /opt/pwndbg
    ./setup.sh

    git clone --depth 1 https://github.com/jerdna-regeiz/splitmind /opt/splitmind
    git clone --depth 1 https://github.com/nccgroup/libslub /opt/libslub
    cd /opt/libslub
    pip install -r requirements.txt
EOF

FROM builder-gdb-${INSTALL_GDB} as builder-gdb

################################################################################

FROM essentials as builder-tools-apt-no
FROM essentials as builder-tools-apt-yes

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && xargs apt-get install --no-install-recommends -yqq <<EOF && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
        arping
        binutils
        binutils-aarch64-linux-gnu
        binwalk
        debianutils
        diffutils
        ed
        elfutils
        emacs
        ethtool
        exiftool
        expect
        findutils
	    finger
        gcc-aarch64-linux-gnu
        gdb
        gdb-multiarch
        gnupg-utils
        hexedit
        iproute2
        iputils-ping
        ipython3
        keyutils
        kmod
        libc6-arm64-cross
        libc6-dev-arm64-cross
        less
        ltrace
        nano
        neovim
        net-tools
        nmap
        openssh-server
        parallel
        patchelf
        pcre2-utils
        psutils
        python3-ipdb
        qemu-user
        qemu-system-x86
        qemu-utils
        rsync
        silversearcher-ag
        strace
        tmux
        whiptail
        zip
EOF

FROM builder-tools-apt-${INSTALL_TOOLS_APT} as builder-tools-apt

FROM builder as builder-tools-pip-no
FROM builder as builder-tools-pip-yes

RUN xargs pip install --force-reinstall <<EOF
    angr
    asteval
    git+https://github.com/Gallopsled/pwntools#egg=pwntools
    git+https://github.com/secdev/scapy#egg=scapy
    psutil
    pycryptodome
    requests
EOF

RUN ln -sf /usr/bin/ipython3 /usr/bin/ipython

FROM builder-tools-pip-${INSTALL_TOOLS_PIP} as builder-tools-pip

################################################################################
# pwn.college

FROM builder-essentials as builder-pwn.college
RUN mkdir /opt/pwn.college
COPY docker-initialize.sh /opt/pwn.college/docker-initialize.sh
COPY docker-entrypoint.sh /opt/pwn.college/docker-entrypoint.sh
COPY setuid_interpreter.c /opt/pwn.college/setuid_interpreter.c
COPY vm /opt/pwn.college/vm

RUN gcc /opt/pwn.college/setuid_interpreter.c -DSUID_PYTHON -o /opt/pwn.college/python && \
    gcc /opt/pwn.college/setuid_interpreter.c -DSUID_BASH -o /opt/pwn.college/bash && \
    gcc /opt/pwn.college/setuid_interpreter.c -DSUID_SH -o /opt/pwn.college/sh && \
    rm /opt/pwn.college/setuid_interpreter.c

################################################################################
# build 

FROM ubuntu:${UBUNTU_VERSION} as challenge-nano

SHELL ["/bin/bash", "-ceov", "pipefail"]

ENV LC_CTYPE=C.UTF-8

COPY --link --from=essentials / /
COPY --link --from=builder-pwn.college /opt/pwn.college /opt/pwn.college
COPY ./launch_challenge.sh /opt/pwn.college/launch_challenge.sh

RUN <<EOF
    chmod +x /opt/pwn.college/docker-initialize.sh
    chmod +xs /opt/pwn.college/launch_challenge.sh
    ln -sf /opt/pwn.college/vm/vm /usr/local/bin/vm
    ln -sf /opt/pwn.college/launch_challenge.sh /usr/local/bin/launch_challenge
    ln -sf /home/hacker/.tmux.conf /root/.tmux.conf
    
    ln -sf /home/hacker/.pwn.conf /root/.pwn.conf

    mkdir /challenge
    install -m 400 <(echo 'pwn.college{th1s_1s_0x1c31ce1c3!}') /flag
EOF

################################################################################
FROM challenge-nano as challenge-kernel
# copy the final image
COPY --link --from=builder-essentials / /
COPY --link --from=builder / /
COPY --link --from=builder-kernel-yes /opt/linux /opt/linux
COPY --link --from=builder-capstone-yes / /
COPY --link --from=builder-virtiofsd-yes /opt/virtiofsd /opt/virtiofsd
COPY --link --from=builder-gdb-yes / /
COPY --link --from=builder-tools-pip-yes / /
COPY --link --from=builder-tools-apt-yes / /

################################################################################
# Final image

FROM challenge-kernel as challenge

RUN echo "root:root" | chpasswd

RUN <<EOF
    if [ -f /etc/ssh/ssh_config ]
    then
        echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config
        echo "UserKnownHostsFile=/dev/null" >> /etc/ssh/ssh_config
        echo "LogLevel ERROR" >> /etc/ssh/ssh_config
    fi
EOF

RUN <<EOF
    if [ -f /etc/ssh/sshd_config ]
    then
        sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config
        sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords yes/g' /etc/ssh/sshd_config
        sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
    fi
EOF

RUN <<EOF
    if id ubuntu; then userdel -f -r ubuntu; fi
    useradd -s /bin/bash -m hacker
    passwd -d hacker
    echo "hacker:hacker" | chpasswd
    echo "hacker ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/hacker
    find / -xdev -type f -perm -4000 -exec chmod u-s {} \;
    chmod u+s /opt/pwn.college/python \
              /opt/pwn.college/bash \
              /opt/pwn.college/sh \
              /opt/pwn.college/vm/vm \

EOF


# resolve a dumb bug in gdbinit
RUN <<EOF 
    ln -sf /home/hacker/.gdbinit /root/.gdbinit 
EOF

WORKDIR /root
