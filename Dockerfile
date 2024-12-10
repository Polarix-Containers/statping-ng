ARG VERSION=v0.91.0
ARG COMMIT=https://github.com/statping-ng/statping-ng/commit/66a1adaa66acfa9615d5b8661e3c0320109731c3

FROM ghcr.io/statping-ng/statping-ng:0 AS extract

FROM node:12.18.2-alpine AS frontend

ARG VERSION

WORKDIR /statping
ADD https://raw.githubusercontent.com/statping-ng/statping-ng/refs/tags/${VERSION}/frontend/package.json .
ADD https://raw.githubusercontent.com/statping-ng/statping-ng/refs/tags/v0.91.0/frontend/yarn.lock .
RUN yarn install --pure-lockfile --network-timeout 1000000
ADD https://github.com/statping-ng/statping-ng.git#${VERSION}:frontend .
RUN yarn build && yarn cache clean

# Statping Golang BACKEND building from source
# Creates "/go/bin/statping" and "/usr/local/bin/sass" for copying
FROM golang:alpine AS backend

ARG VERSION
ARG COMMIT

RUN apk add --update --no-cache libstdc++ gcc g++ make git autoconf \
    libtool ca-certificates linux-headers wget curl jq && \
    update-ca-certificates

WORKDIR /root
RUN git clone https://github.com/sass/sassc.git
RUN . sassc/script/bootstrap && make -C sassc -j4
# sassc binary: /root/sassc/bin/sassc

WORKDIR /go/src/github.com/statping-ng/statping-ng
ADD https://raw.githubusercontent.com/statping-ng/statping-ng/refs/tags/${VERSION}/go.mod ./
ADD https://raw.githubusercontent.com/statping-ng/statping-ng/refs/tags/${VERSION}/go.sum ./
RUN go mod download
ENV GO111MODULE on
ENV CGO_ENABLED 1
RUN go get github.com/stretchr/testify/assert && \
    go get github.com/stretchr/testify/require && \
	go get github.com/GeertJohan/go.rice/rice && \
	go get github.com/cortesi/modd/cmd/modd && \
	go get github.com/crazy-max/xgo
ADD https://github.com/statping-ng/statping-ng.git#${VERSION} .
COPY --from=frontend /statping/dist/ ./source/dist/
RUN make clean generate embed
RUN go build -a -ldflags "-s -w -extldflags -static -X main.VERSION=${VERSION} -X main.COMMIT=${COMMIT}" -o statping --tags "netgo linux" ./cmd
RUN chmod a+x statping && mv statping /go/bin/statping
# /go/bin/statping - statping binary
# /root/sassc/bin/sassc - sass binary
# /statping - Vue frontend (from frontend)

# Statping main Docker image that contains all required libraries
FROM alpine:latest

RUN apk --no-cache add libgcc libstdc++ ca-certificates curl jq && update-ca-certificates

COPY --from=backend /go/bin/statping /usr/local/bin/
COPY --from=backend /root/sassc/bin/sassc /usr/local/bin/
COPY --from=backend /usr/local/share/ca-certificates /usr/local/share/

WORKDIR /app
VOLUME /app

ENV IS_DOCKER=true
ENV SASS=/usr/local/bin/sassc
ENV STATPING_DIR=/app
ENV PORT=8080
ENV BASE_PATH=""

EXPOSE $PORT

HEALTHCHECK --interval=60s --timeout=10s --retries=3 CMD if [ -z "$BASE_PATH" ]; then HEALTHPATH="/health"; else HEALTHPATH="/$BASE_PATH/health" ; fi && curl -s "http://localhost:80$HEALTHPATH" | jq -r -e ".online==true"

CMD statping --port $PORT
