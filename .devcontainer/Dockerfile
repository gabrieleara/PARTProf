# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.155.1/containers/debian/.devcontainer/base.Dockerfile

# [Choice] Debian version: buster, stretch
ARG VARIANT="buster"
FROM gabrieleara/dev_environment:python

# CMake is required for the embedded component
RUN export DEBIAN_FRONTEND=noninteractive && apt-get update \
    && apt-get -y install build-essential cmake gdb \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists

RUN conda install sympy scipy \
    && conda install -c conda-forge lmfit

# Other interesting packages: cppcheck valgrind clang lldb llvm

# ** [Optional] Uncomment this section to install additional packages. **
# RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
#     && apt-get -y install --no-install-recommends <your-package-list-here>
