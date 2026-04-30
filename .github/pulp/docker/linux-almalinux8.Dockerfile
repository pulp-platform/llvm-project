# Copyright 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

FROM almalinux:8.7

LABEL maintainer colluca@ethz.ch

RUN rpm --import https://repo.almalinux.org/almalinux/RPM-GPG-KEY-AlmaLinux
RUN dnf -y update && dnf -y group install 'Development tools'
RUN dnf config-manager --add-repo /etc/yum.repos.d/almalinux-powertools.repo
RUN dnf config-manager --set-enabled powertools
RUN dnf -y install dejagnu python3 texinfo wget expat-devel cmake ninja-build

WORKDIR /home/builder
