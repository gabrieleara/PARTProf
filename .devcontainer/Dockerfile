# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.155.1/containers/debian/.devcontainer/base.Dockerfile

# [Choice] Debian version: buster, stretch
ARG VARIANT="buster"
FROM mcr.microsoft.com/vscode/devcontainers/base:0-${VARIANT}

# Basic development packages:
RUN apt update && export DEBIAN_FRONTEND=noninteractive && \
    apt -y install build-essential cmake gdb && \
    apt autoremove -y && \
    apt clean -y && \
    rm -rf /var/lib/apt/lists

# Other interesting packages: cppcheck valgrind clang lldb llvm

# ** [Optional] Uncomment this section to install additional packages. **
# RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
#     && apt-get -y install --no-install-recommends <your-package-list-here>
