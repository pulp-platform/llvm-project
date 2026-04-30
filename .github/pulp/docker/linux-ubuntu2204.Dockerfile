# Copyright 2022 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

FROM ubuntu:22.04

LABEL maintainer colluca@ethz.ch

RUN apt-get -y update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y git flex bison build-essential dejagnu git python3 python3-distutils texinfo wget libexpat-dev \
                       ninja-build ccache cmake

# Some tests require the user running testing to exist and have a home directory
# These values match what the Embecosm Buildbot builders are set up to use
# RUN useradd -m -u 1002 builder

WORKDIR /home/builder
