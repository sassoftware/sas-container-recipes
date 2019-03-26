FROM golang:1.12.0

RUN apt-get update && \
    apt-get install -y openjdk-8-jdk-headless ansible && \
    rm -rf /var/lib/apt/lists/*

# We need to use dep or go mod to handle deps.
RUN go get -x -u gopkg.in/yaml.v2 github.com/docker/docker/api/types github.com/docker/docker/client

WORKDIR /sas-container-recipes

ENV GOCACHE /tmp/cache

COPY addons ./addons
COPY samples ./samples
COPY tests ./tests
COPY util ./util
COPY *.yml *.go ./ 

ENTRYPOINT ["/usr/local/go/bin/go", "run", "main.go", "container.go", "order.go"]
