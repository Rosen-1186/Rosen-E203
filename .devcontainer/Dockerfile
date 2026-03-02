FROM ubuntu:22.04

# 显式声明 root 权限进行系统级安装
USER root

# 1. 替换为国内清华镜像源 (使用 printf 避免 sed 权限和 I/O 错误)
RUN printf "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy main restricted universe multiverse\n\
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse\n\
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse\n\
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-security main restricted universe multiverse\n" > /etc/apt/sources.list

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai

# 2. 准备阶段：解除系统最小化限制 (unminimize)
# 这步会补全 man 手册和基础库，对学习操作系统和底层 API 至关重要
RUN rm -f /etc/dpkg/dpkg.cfg.d/excludes && \
    apt-get update && \
    export DEBIAN_FRONTEND=noninteractive && \
    apt-get install -y --no-install-recommends locales man-db manpages manpages-dev sudo && \
    yes | unminimize

# 3. 安装全套开发依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    # 基础编译与工具
    build-essential git vim wget curl ca-certificates bash-completion bc \
    # 仿真工具 (Verilator/Icarus/GTKWave)
    verilator iverilog gtkwave \
    # 蜂鸟 E203 & SoC 编译依赖
    device-tree-compiler autoconf automake autotools-dev libmpc-dev libmpfr-dev libgmp-dev \
    gawk bison flex texinfo gperf libtool patchutils zlib1g-dev libexpat1-dev \
    # 硬件调试与 USB 支持
    openocd libusb-1.0-0-dev usbutils \
    # Python 环境
    python3 python3-pip python3-setuptools python3-serial \
    # 注意：这里我们移除了 apt 的 gcc，只保留 gdb
    gdb-multiarch \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 下载自带完整 C 标准库 (newlib) 的官方预编译 RISC-V 工具链
RUN wget https://static.dev.sifive.com/dev-tools/riscv64-unknown-elf-gcc-8.3.0-2020.04.1-x86_64-linux-ubuntu14.tar.gz -O /tmp/riscv-gcc.tar.gz \
    && tar -xzf /tmp/riscv-gcc.tar.gz -C /opt/ \
    && rm /tmp/riscv-gcc.tar.gz \
    && mv /opt/riscv64-unknown-elf-gcc-8.3.0-2020.04.1-x86_64-linux-ubuntu14 /opt/riscv-gcc

# 1. 将原版工具链加入系统环境变量 (让 VS Code 能找到它)
ENV PATH="/opt/riscv-gcc/bin:${PATH}"

# 2. 建立欺骗 SDK 的快捷方式 (解决 Makefile 找不到 nuclei 前缀的问题)
RUN for tool in gcc g++ as ld objcopy objdump ar size; do \
        ln -s /opt/riscv-gcc/bin/riscv64-unknown-elf-$tool /usr/bin/riscv-nuclei-elf-$tool; \
    done

# 4. 彻底解决 Locale 问题
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# 5. 配置 rosen 用户 (UID/GID 1000 通常匹配 WSL2 默认用户)
ARG USERNAME=rosen
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# 6. 工作目录授权
WORKDIR /workspace
RUN chown -R $USERNAME:$USER_GID /workspace

# 7. 终端美化 (彩色提示符：rosen@e203-docker:~/workspace$)
RUN echo "export PS1='\[\e[32;1m\]\u@e203-docker\[\e[0m\]:\[\e[34;1m\]\w\[\e[0m\]\$ '" >> /home/$USERNAME/.bashrc

# 切换到普通用户
USER $USERNAME
