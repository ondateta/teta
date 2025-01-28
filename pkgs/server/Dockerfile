FROM debian:bullseye-slim

RUN apt update -y
RUN apt install -y git wget curl unzip lib32stdc++6 libglu1-mesa default-jdk-headless

WORKDIR /app

COPY . /app

ENV FLUTTER_ROOT="/app/opt/flutter"
RUN git clone https://github.com/flutter/flutter "${FLUTTER_ROOT}"
ENV PATH="${FLUTTER_ROOT}/bin:${PATH}"

RUN chmod -R a+w "${FLUTTER_ROOT}"

RUN echo "PORT=\$PORT" >> /app/.env \
    && echo "LLM_KEY=\$LLM_KEY" >> /app/.env \
    && echo "LLM_BASE_URL=\$LLM_BASE_URL" >> /app/.env \
    && echo "LLM_MODEL=\$LLM_MODEL" >> /app/.env

RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser

RUN git config --global --add safe.directory "${FLUTTER_ROOT}"

RUN dart pub get

RUN which dart

RUN dart run build_runner build --delete-conflicting-outputs 

RUN dart compile exe bin/server.dart -o bin/server

EXPOSE $PORT
ENTRYPOINT ["bin/server"]
