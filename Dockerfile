# Creates an environment for running the SAS Container Recipes tool.
# This Dockerfile is built and run by the `build.sh` script.
FROM golang:1.18

ARG USER_UID=1000
ARG DOCKER_GID=997

RUN apt-get update && \
    apt-get install -y openjdk-11-jdk-headless ansible && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd --gid ${DOCKER_GID} docker
RUN useradd --uid ${USER_UID} \
    --gid ${DOCKER_GID} \
    --create-home \
    --shell /bin/bash \
    sas

WORKDIR /sas-container-recipes

RUN chmod 777 /sas-container-recipes

COPY --chown=sas:docker addons ./addons
COPY --chown=sas:docker samples ./samples
COPY --chown=sas:docker tests ./tests
COPY --chown=sas:docker util ./util
COPY --chown=sas:docker *.yml *.go go.mod ./
COPY --chown=sas:docker util/sas-orchestration ./util/programming-only-single/sas-orchestration

RUN go get -d -u gopkg.in/yaml.v2 github.com/docker/docker/api/types github.com/docker/docker/client && \
    go mod download && \
    chown -R ${USER_GID}:${DOCKER_GID} /sas-container-recipes

USER sas

ENTRYPOINT ["/usr/local/go/bin/go", "run", "main.go", "container.go", "order.go"]
