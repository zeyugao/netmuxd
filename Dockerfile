FROM ubuntu:focal-20220415 as builder

WORKDIR /work

RUN sed -i 's/archive.ubuntu.com/mirrors.ustc.edu.cn/g' /etc/apt/sources.list \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
	    build-essential \
	    pkg-config \
	    checkinstall \
	    git \
	    autoconf \
	    automake \
	    libtool-bin \
	    libplist-dev \
        libavahi-glib-dev libavahi-client-dev \
        libimobiledevice-dev \
        libusb-1.0-0-dev \
        libssl-dev \
        udev \
        libplist++-dev libtool autoconf automake \
        python3 python3-dev \
        curl usbmuxd \
        wget lsb-release wget software-properties-common

RUN for i in /etc/ssl/certs/*.pem; do HASH=$(openssl x509 -hash -noout -in $i); ln -s $(basename $i) /etc/ssl/certs/$HASH.0 || true; done

RUN wget https://apt.llvm.org/llvm.sh \
    && chmod +x llvm.sh \
    && ./llvm.sh 14

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

RUN git clone https://github.com/jkcoxson/rusty_libimobiledevice.git \
    && git clone https://github.com/jkcoxson/plist_plus.git \
    && git clone https://github.com/libimobiledevice/libimobiledevice-glue.git \
    && git clone https://github.com/zeyugao/zeroconf-rs.git \
    && git clone https://github.com/libimobiledevice/libplist.git \
    && git clone https://github.com/libimobiledevice/libusbmuxd.git

RUN cd libplist \
    && git checkout db93bae96d64140230ad050061632531644c46ad \
    && ./autogen.sh \
    && make \
    && make install

RUN cd libimobiledevice-glue \
    && git checkout c2e237ab5449b42461639c8e1eabbc61d0c386b7 \
    && ./autogen.sh \
    && make \
    && make install

RUN cd libusbmuxd \
    && git checkout a9a639d0102b9bbf30fd088e633c793316dbc873 \
    && ./autogen.sh \
    && make \
    && make install

RUN cd rusty_libimobiledevice && git checkout f8fd18f39c74d821258192a26b4e0c930fb48c85 && cd .. \
    && cd zeroconf-rs && git checkout 860b030064308d4318e2c6936886674d955c6472 && cd .. \
    && cd plist_plus && git checkout 7b6825f1ef89e84fd04746efec593159abec9d65 && cd ..

RUN . "$HOME/.cargo/env" && cargo install cargo-chef
RUN mkdir netmuxd
COPY recipe.json netmuxd
RUN . "$HOME/.cargo/env" && cd netmuxd && cargo chef cook --release --recipe-path recipe.json

COPY . netmuxd

RUN cd netmuxd \
    && . "$HOME/.cargo/env" \
    && cargo build --release

FROM ubuntu:20.04
RUN sed -i 's/archive.ubuntu.com/mirrors.ustc.edu.cn/g' /etc/apt/sources.list \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        libavahi-client-dev

COPY --from=builder /work/netmuxd/target/release/netmuxd /usr/local/bin/netmuxd
