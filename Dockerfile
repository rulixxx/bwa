FROM  ubuntu:22.04 as builder

USER  root

# ALL tool versions used by opt-build.sh
# need to keep in sync with setup.sh 

# newer gitlab versions do not work
ARG BBB2_URL="https://gitlab.com/german.tischler/biobambam2/-/archive/2.0.185-release-20221211202123/biobambam2-2.0.185-release-20221211202123.tar.gz"
ARG BWAMEM2_GIT="https://github.com/bwa-mem2/bwa-mem2.git"
# accepts tags or commmit ids
ENV VER_HTSLIB="1.18"
ENV VER_SAMTOOLS="1.18"
ENV VER_LIBDEFLATE="v1.16"

ARG VER_BWA="v0.7.17"
#using master for bwamem2 which at this time is v2.2.1 
ARG BWAMEM2_TAG="v2.2.1" 


ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get -yq update
RUN apt-get install -yq --no-install-recommends locales
RUN apt-get install -yq --no-install-recommends g++
RUN apt-get install -yq --no-install-recommends ca-certificates
RUN apt-get install -yq --no-install-recommends cmake
RUN apt-get install -yq --no-install-recommends make
RUN apt-get install -yq --no-install-recommends bzip2
RUN apt-get install -yq --no-install-recommends gcc
RUN apt-get install -yq --no-install-recommends pkg-config
RUN apt-get install -yq --no-install-recommends wget
RUN apt-get install -yq --no-install-recommends locales
RUN apt-get install -yq --no-install-recommends zlib1g-dev
RUN apt-get install -yq --no-install-recommends libbz2-dev
RUN apt-get install -yq --no-install-recommends liblzma-dev
RUN apt-get install -yq --no-install-recommends libcurl4-openssl-dev
RUN apt-get install -yq --no-install-recommends libncurses5-dev
RUN apt-get install -yq --no-install-recommends libssl-dev
RUN apt-get install -yq --no-install-recommends libxml2-dev
RUN apt-get install -yq --no-install-recommends libgsl-dev
RUN apt-get install -yq --no-install-recommends libboost-dev
RUN apt-get install -yq --no-install-recommends git


RUN locale-gen en_US.UTF-8
RUN update-locale LANG=en_US.UTF-8

ENV OPT /opt/wtsi-cgp
ENV PATH $OPT/bin:$OPT/biobambam2/bin:$PATH
ENV PERL5LIB $OPT/lib/perl5
ENV LD_LIBRARY_PATH $OPT/lib
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8

RUN mkdir -p $OPT/bin

ADD build/opt-build.sh build/
RUN bash build/opt-build.sh $OPT

FROM ubuntu:22.04

LABEL maintainer="fl86" \
      description="bwa docker"

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get -yq update
RUN apt-get install -yq --no-install-recommends \
locales \
ca-certificates \
time \
zlib1g \
libxml2 \
libgsl27 \
libgomp1 \
libcurl4 \
parallel \
unattended-upgrades && \
unattended-upgrade -d -v && \
apt-get remove -yq unattended-upgrades && \
apt-get autoremove -yq

RUN locale-gen en_US.UTF-8
RUN update-locale LANG=en_US.UTF-8

ENV OPT /opt/wtsi-cgp
ENV PATH $OPT/bin:$PATH
ENV LD_LIBRARY_PATH $OPT/lib
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8

RUN mkdir -p $OPT
COPY --from=builder $OPT $OPT

## USER CONFIGURATION
RUN adduser --disabled-password --gecos '' ubuntu && chsh -s /bin/bash && mkdir -p /home/ubuntu

USER    ubuntu
WORKDIR /home/ubuntu

CMD ["/bin/bash"]
