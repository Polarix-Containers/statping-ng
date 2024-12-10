FROM ghcr.io/statping-ng/statping-ng:0 AS extract

FROM alpine:latest

LABEL maintainer="Thien Tran contact@tommytran.io"

ENV IS_DOCKER=true
ENV SASS=/usr/local/bin/sassc
ENV STATPING_DIR=/app
ENV PORT=8080
ENV BASE_PATH=""

RUN apk add ca-certificates curl libgcc libstdc++ jq \ 
    && update-ca-certificates \
    && rm -rf /var/cache/apk/*

COPY --from=extract /usr/local/bin/statping /usr/local/bin/
COPY --from=extract /usr/local/bin/sassc /usr/local/bin/
COPY --from=extract /usr/local/share/ca-certificates /usr/local/share/

COPY --from=ghcr.io/polarix-containers/hardened_malloc:latest /install /usr/local/lib/
ENV LD_PRELOAD="/usr/local/lib/libhardened_malloc.so"

WORKDIR /app
VOLUME /app

EXPOSE ${PORT}/tcp

HEALTHCHECK --interval=60s --timeout=10s --retries=3 CMD if [ -z "$BASE_PATH" ]; then HEALTHPATH="/health"; else HEALTHPATH="/$BASE_PATH/health" ; fi && curl -s "http://localhost:${PORT}$HEALTHPATH" | jq -r -e ".online==true"
CMD statping --port $PORT