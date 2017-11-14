FROM centos:6
MAINTAINER The Apache Mesos Developers <dev@mesos.apache.org>

WORKDIR /tmp/build

RUN yum update -y && \
    yum install -y centos-release-scl && \
    yum install -y devtoolset-4 && \
    yum install -y git glibc-static python27 unzip

RUN wget https://cmake.org/files/v3.8/cmake-3.8.2-Linux-x86_64.sh && \
    bash cmake-3.8.2-Linux-x86_64.sh --skip-license --prefix=/usr/local

RUN wget https://github.com/ninja-build/ninja/releases/download/v1.8.2/ninja-linux.zip && \
    unzip ninja-linux.zip -d /usr/local/bin

RUN mkdir /tmp/llvm && \
    wget -O - https://releases.llvm.org/5.0.0/llvm-5.0.0.src.tar.xz | tar --strip-components=1 -xJ -C /tmp/llvm && \
    git clone --depth 1 -b mesos_50 http://github.com/mesos/clang.git /tmp/llvm/tools/clang

ENV TOOL="mesos-format"
ENV VERSION="2017-11-11"

ENTRYPOINT \
    scl enable devtoolset-4 python27 -- \
    cmake -GNinja \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX=/"${TOOL}/${VERSION}" \
          -DLLVM_BUILD_STATIC=ON /tmp/llvm && \
    cmake --build . --target clang-format && \
    cmake -DCOMPONENT=clang-format -P cmake_install.cmake && \
    tar cf /install/"${TOOL}-${VERSION}".linux.tar.gz /"${TOOL}"
