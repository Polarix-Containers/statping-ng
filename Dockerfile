ARG VERSION=0.91.0
ARG NODE=16
ARG UID=3010
ARG GID=3010

FROM node:${NODE}-alpine AS frontend
ARG VERSION

RUN apk -U upgrade \
    && rm -rf /var/cache/apk/*

WORKDIR /statping
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

WORKDIR /go/src/github.com/statping-ng/statping-ng
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
COPY --from=frontend /statping/dist/ ./source/dist/
RUN go install github.com/GeertJohan/go.rice/rice@latest
RUN cd source && rice embed-go
RUN go build -a -ldflags "-s -w -extldflags -static -X main.VERSION=$VERSION" -o statping --tags "netgo linux" ./cmd
RUN chmod a+x statping && mv statping /go/bin/statping
# /go/bin/statping - statping binary
# /statping - Vue frontend (from frontend)

# Statping main Docker image that contains all required libraries
FROM alpine:latest

ENV IS_DOCKER=true
ENV STATPING_DIR=/app
ENV PORT=8080
ENV BASE_PATH=""

RUN apk -U upgrade \
    && apk add ca-certificates curl jq libgcc libstdc++ sassc \
    && update-ca-certificates \
    && rm -rf /var/cache/apk/*

COPY --from=backend /go/bin/statping /usr/local/bin/
COPY --from=backend /usr/local/share/ca-certificates /usr/local/share/

WORKDIR /app
VOLUME /app

EXPOSE $PORT

HEALTHCHECK --interval=60s --timeout=10s --retries=3 CMD if [ -z "$BASE_PATH" ]; then HEALTHPATH="/health"; else HEALTHPATH="/$BASE_PATH/health" ; fi && curl -s "http://localhost:80$HEALTHPATH" | jq -r -e ".online==true"

CMD statping --port $PORT
