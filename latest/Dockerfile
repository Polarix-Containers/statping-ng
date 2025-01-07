ARG VERSION=0.91.0
ARG NODE=16
ARG UID=200008
ARG GID=200008
ARG PORT=8080
ARG STATPING_DIR=/app
ARG BASE_PATH=""

FROM node:${NODE}-alpine AS frontend
ARG VERSION

RUN apk -U upgrade \
    && rm -rf /var/cache/apk/*

WORKDIR /install

ADD https://github.com/statping-ng/statping-ng.git#v${VERSION}:frontend .

RUN yarn install --pure-lockfile \
    && yarn build \
    && yarn cache clean

# ======================================= #

FROM golang:alpine AS backend
ARG VERSION

RUN apk -U upgrade \
    && rm -rf /var/cache/apk/*

ADD https://github.com/statping-ng/statping-ng.git#v${VERSION} .
COPY --from=frontend /install/dist/ ./source/dist/

ENV GO111MODULE on

# Ideally this should be set to 1 and built against hardened_malloc.
# However, Go version has to be downgraded to 1.21, otherwise
# the build process will just fail.
ENV CGO_ENABLED 0


RUN go mod download \
    && go install github.com/GeertJohan/go.rice/rice@latest \
    && cd source \
    && rice embed-go \
    && cd .. \
    && mkdir -p /install \
    && go build -a -ldflags "-s -w -extldflags -static -X main.VERSION=${VERSION}" -o /install/statping --tags "netgo linux" ./cmd \
    && chmod +x /install/statping

# ======================================= #

FROM alpine:latest

ARG UID
ARG GID
ARG PORT
ARG STATPING_DIR
ARG BASE_PATH

ENV PORT ${PORT}
ENV STATPING_DIR ${STATPING_DIR}
ENV BASE_PATH ${BASE_PATH}

LABEL maintainer="Thien Tran contact@tommytran.io"

RUN apk -U upgrade \
    && apk add ca-certificates curl jq libgcc libstdc++ sassc \
    && update-ca-certificates \
    && rm -rf /var/cache/apk/*

RUN --network=none \
    addgroup -g ${GID} statping-ng \
    && adduser -u ${UID} --ingroup statping-ng --disabled-password --system statping-ng

COPY --from=backend /install/statping /usr/local/bin/

COPY --from=ghcr.io/polarix-containers/hardened_malloc:latest /install /usr/local/lib/
ENV LD_PRELOAD="/usr/local/lib/libhardened_malloc.so"

USER statping-ng

WORKDIR ${STATPING_DIR}
VOLUME ${STATPING_DIR}

EXPOSE $PORT/tcp

CMD statping --port $PORT

HEALTHCHECK --interval=60s --timeout=10s --retries=3 \
    CMD if [ -z "${BASE_PATH}" ]; then HEALTHPATH="/health"; else HEALTHPATH="/${BASE_PATH}/health" ; fi && curl -s "http://localhost:${PORT}${HEALTHPATH}" | jq -r -e ".online==true"
