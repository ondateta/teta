FROM debian:bullseye-slim

RUN apt update -y
RUN apt install -y git wget curl unzip lib32stdc++6 libglu1-mesa default-jdk-headless

WORKDIR /app

COPY . /app

ENV FLUTTER_ROOT="/app/opt/flutter"
RUN git clone https://github.com/flutter/flutter "${FLUTTER_ROOT}"
ENV PATH="${FLUTTER_ROOT}/bin:${PATH}"

RUN flutter config --no-analytics

RUN dart pub get

RUN which dart

RUN dart run build_runner build --delete-conflicting-outputs 

RUN dart compile exe bin/server.dart -o bin/server

EXPOSE 8080
ENTRYPOINT ["bin/server"]
