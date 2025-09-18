ARG DEBIAN_VERSION=bookworm-slim
ARG BASEDEV_VERSION=v0.28.0

FROM debian:${DEBIAN_VERSION} AS chktex
ARG CHKTEX_VERSION=1.7.9
WORKDIR /tmp/workdir
RUN apt update -y && \
    apt install -y --no-install-recommends g++ make wget perl perl-modules
RUN wget -qO- http://download.savannah.gnu.org/releases/chktex/chktex-${CHKTEX_VERSION}.tar.gz | \
    tar -xz --strip-components=1
RUN ./configure && \
    make && \
    mv chktex /tmp && \
    rm -r *

FROM ghcr.io/qdm12/basedevcontainer:${BASEDEV_VERSION}-debian
ARG BUILD_DATE
ARG COMMIT
ARG VERSION=local
LABEL \
    org.opencontainers.image.authors="bastienvty@protonmail.com" \
    org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.version=$VERSION \
    org.opencontainers.image.revision=$COMMIT \
    org.opencontainers.image.url="https://github.com/bastienvty/latexdevcontainer" \
    org.opencontainers.image.documentation="https://github.com/bastienvty/latexdevcontainer" \
    org.opencontainers.image.source="https://github.com/bastienvty/latexdevcontainer" \
    org.opencontainers.image.title="Latex Dev container Debian" \
    org.opencontainers.image.description="Latex development container for Visual Studio Code Remote Containers development"
WORKDIR /tmp/texlive
ARG SCHEME=scheme-basic
ARG DOCFILES=0
ARG SRCFILES=0
ARG TEXLIVE_VERSION=2025
ARG TEXLIVE_MIRROR=http://ctan.math.utah.edu/ctan/tex-archive/systems/texlive/tlnet
# Avoid duplicate apt sources warnings on Bookworm+
RUN if [ -f /etc/apt/sources.list.d/debian.sources ] && [ -f /etc/apt/sources.list ]; then rm -f /etc/apt/sources.list; fi
RUN apt update -y && \
    apt install -y --no-install-recommends wget gnupg cpanminus libfontconfig1 && \
    wget -qO- ${TEXLIVE_MIRROR}/install-tl-unx.tar.gz | \
    tar -xz --strip-components=1 && \
    export TEXLIVE_INSTALL_NO_CONTEXT_CACHE=1 && \
    export TEXLIVE_INSTALL_NO_WELCOME=1 && \
    printf "selected_scheme ${SCHEME}\ninstopt_letter 0\ntlpdbopt_autobackup 0\ntlpdbopt_desktop_integration 0\ntlpdbopt_file_assocs 0\ntlpdbopt_install_docfiles ${DOCFILES}\ntlpdbopt_install_srcfiles ${SRCFILES}" > profile.txt && \
    perl install-tl -profile profile.txt --location ${TEXLIVE_MIRROR} && \
    # Cleanup
    cd && \
    apt clean autoclean && \
    apt autoremove -y && \
    rm -rf /var/lib/{apt,dpkg,cache,log}/ /tmp/texlive /usr/local/texlive/${TEXLIVE_VERSION}/*.log
ENV PATH=${PATH}:/usr/local/texlive/${TEXLIVE_VERSION}/bin/x86_64-linux:/usr/local/texlive/${TEXLIVE_VERSION}/bin/aarch64-linux
WORKDIR /workspace
# Latexindent dependencies
RUN apt update -y && \
    apt install -y --no-install-recommends cpanminus make gcc libc6-dev python3 python3-pip && \
    cpanm -n -q Log::Log4perl && \
    cpanm -n -q XString && \
    cpanm -n -q Log::Dispatch::File && \
    cpanm -n -q YAML::Tiny && \
    cpanm -n -q File::HomeDir && \
    cpanm -n -q Unicode::GCString && \
    apt remove -y cpanminus make gcc libc6-dev && \
    apt clean autoclean && \
    apt autoremove -y && \
    rm -rf /var/lib/{apt,dpkg,cache,log}/
RUN tlmgr install latexindent latexmk && \
    texhash && \
    rm /usr/local/texlive/${TEXLIVE_VERSION}/texmf-var/web2c/*.log && \
    rm /usr/local/texlive/${TEXLIVE_VERSION}/tlpkg/texlive.tlpdb.main.*
COPY --from=chktex /tmp/chktex /usr/local/bin/chktex
COPY shell/.zshrc-specific shell/.welcome.sh /root/
# Verify binaries work and have the right permissions
RUN tlmgr version && \
    latexmk -version && \
    texhash --version && \
    chktex --version
