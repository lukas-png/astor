FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    git subversion \
    perl cpanminus \
    gcc g++ make build-essential \
    unzip curl wget ca-certificates \
    ant maven \
    openjdk-8-jdk \
    openjdk-11-jdk \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA7_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV JAVA8_HOME=/usr/lib/jvm/java-8-openjdk-amd64

ENV JAVA_HOME=${JAVA7_HOME}
ENV PATH=${JAVA_HOME}/bin:${PATH}

RUN printf '%s\n' \
'#!/usr/bin/env bash' \
'set -euo pipefail' \
'export JAVA_HOME="'"${JAVA7_HOME}"'"' \
'export PATH="$JAVA_HOME/bin:${PATH//"$JAVA_HOME\/bin:"/}"' \
'java -version' \
> /usr/local/bin/use-java7 && chmod +x /usr/local/bin/use-java7

RUN printf '%s\n' \
'#!/usr/bin/env bash' \
'set -euo pipefail' \
'export JAVA_HOME="'"${JAVA8_HOME}"'"' \
'export PATH="$JAVA_HOME/bin:${PATH//"$JAVA_HOME\/bin:"/}"' \
'java -version' \
> /usr/local/bin/use-java8 && chmod +x /usr/local/bin/use-java8

# --- Defects4J ---
WORKDIR /opt
RUN git clone https://github.com/rjust/defects4j.git
WORKDIR /opt/defects4j
RUN /usr/local/bin/use-java7 >/dev/null 2>&1 || true
RUN cpanm --installdeps .
RUN ./init.sh

ENV D4J_HOME=/opt/defects4j
ENV PATH=/opt/defects4j/framework/bin:${PATH}

RUN printf '%s\n' \
'#!/usr/bin/env bash' \
'set -euo pipefail' \
'BUG="${1:-Lang-1}"' \
'WORK="${2:-/work}"' \
'PROJECT="${BUG%%-*}"' \
'BID="${BUG##*-}"' \
'export JAVA_HOME="'"${JAVA7_HOME}"'"' \
'export PATH="$JAVA_HOME/bin:${PATH//"$JAVA_HOME\/bin:"/}"' \
'mkdir -p "$WORK"' \
'defects4j checkout -p "$PROJECT" -v "${BID}b" -w "${WORK}/${BUG}"' \
'cd "${WORK}/${BUG}"' \
'defects4j compile' \
> /usr/local/bin/d4j-checkout && chmod +x /usr/local/bin/d4j-checkout

ENV ASTOR_HOME=/opt/astor

WORKDIR /work
CMD ["bash"]
