ARG VERSION=0.91.0
ARG NODE=16
ARG UID=3010
ARG GID=3010
ARG PORT=8080
ARG STATPING_DIR=/app
ARG BASE_PATH=""

FROM node:${NODE}-alpine AS frontend
ARG VERSION

RUN apk -U upgrade \
    && rm -rf /var/cache/apk/*

WORKDIR /install

ADD https://raw.githubusercontent.com/statping-ng/statping-ng/refs/tags/v${VERSION}/frontend/package.json .
ADD https://raw.githubusercontent.com/statping-ng/statping-ng/refs/tags/v${VERSION}/frontend/yarn.lock .
ADD https://github.com/statping-ng/statping-ng.git#v${VERSION}:frontend .

RUN yarn install --pure-lockfile \
    && yarn build \
    && yarn cache clean


FROM golang:alpine AS backend
ARG VERSION

RUN apk -U upgrade \
    && rm -rf /var/cache/apk/*

ADD https://raw.githubusercontent.com/statping-ng/statping-ng/refs/tags/v${VERSION}/go.mod .
ADD https://raw.githubusercontent.com/statping-ng/statping-ng/refs/tags/v${VERSION}/go.sum .
RUN go mod download
ENV GO111MODULE on
ENV CGO_ENABLED 0
ADD https://github.com/statping-ng/statping-ng.git#v${VERSION}:cmd ./cmd
ADD https://github.com/statping-ng/statping-ng.git#v${VERSION}:database ./database
ADD https://github.com/statping-ng/statping-ng.git#v${VERSION}:handlers ./handlers
ADD https://github.com/statping-ng/statping-ng.git#v${VERSION}:notifiers ./notifiers
ADD https://github.com/statping-ng/statping-ng.git#v${VERSION}:source ./source
ADD https://github.com/statping-ng/statping-ng.git#v${VERSION}:types ./types
ADD https://github.com/statping-ng/statping-ng.git#v${VERSION}:utils ./utils
COPY --from=frontend /install/dist/ ./source/dist/
RUN go install github.com/GeertJohan/go.rice/rice@latest \
    && cd source \
    && rice embed-go \
    && cd .. \
    && mkdir -p /install \
    && go build -a -ldflags "-s -w -extldflags -static -X main.VERSION=$VERSION" -o /install/statping --tags "netgo linux" ./cmd \
    && chmod +x /install/statping


FROM alpine:latest

ARG UID
ARG GID
ARG PORT
ARG STATPING_DIR
ARG BASE_PATH

ENV PORT=${PORT}
ENV STATPING_DIR=${STATPING_DIR}
ENV BASE_PATH=${BASE_PATH}

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
