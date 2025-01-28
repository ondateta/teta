FROM debian:bullseye-slim

# Install Dependencies.
RUN apt update -y
RUN apt install -y git wget curl unzip lib32stdc++6 libglu1-mesa default-jdk-headless

WORKDIR /app

COPY . /app

# Install Flutter.
ENV FLUTTER_ROOT="/app/opt/flutter"
RUN git clone https://github.com/flutter/flutter "${FLUTTER_ROOT}"
ENV PATH="${FLUTTER_ROOT}/bin:${PATH}"

# Disable analytics and crash reporting on the builder.
RUN flutter config --no-analytics

# Perform an artifact precache so that no extra assets need to be downloaded on demand.
RUN flutter precache
# Perform a doctor run.
RUN flutter doctor -v
# Switch to the correct channel
ARG channel=stable
RUN flutter channel $channel
# Perform a flutter upgrade
RUN flutter upgrade

# Install dependencies
RUN dart pub get

# Verify that dart is available
RUN which dart

RUN dart --version

RUN dart run build_runner build --delete-conflicting-outputs 

RUN dart compile exe bin/server.dart -o bin/server

EXPOSE 8080
ENTRYPOINT ["bin/dazero"]
