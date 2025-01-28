FROM alpine:latest

RUN apk update && apk add --no-cache \
    git \
    wget \
    curl \
    unzip \
    openjdk11 \
    libstdc++ \
    mesa-gl

WORKDIR /app

COPY . /app

ENV FLUTTER_ROOT="/app/opt/flutter"
RUN if [ ! -d "/app/opt/flutter" ]; then \
        git clone https://github.com/flutter/flutter "${FLUTTER_ROOT}"; \
    fi
ENV PATH="${FLUTTER_ROOT}/bin:${PATH}"

RUN chmod -R a+w "${FLUTTER_ROOT}"

RUN echo "PORT=\$PORT" >> /app/.env \
    && echo "LLM_KEY=\$LLM_KEY" >> /app/.env \
    && echo "LLM_BASE_URL=\$LLM_BASE_URL" >> /app/.env \
    && echo "LLM_MODEL=\$LLM_MODEL" >> /app/.env

RUN apk update && apk add --no-cache shadow && useradd -m appuser && chown -R appuser:appuser /app
USER appuser

RUN git config --global --add safe.directory "${FLUTTER_ROOT}"

RUN apk add --no-cache bash
RUN flutter clean

RUN dart pub get

RUN which dart

RUN dart run build_runner build --delete-conflicting-outputs 

RUN dart compile exe bin/server.dart -o bin/server

EXPOSE $PORT
ENTRYPOINT ["bin/server"]
