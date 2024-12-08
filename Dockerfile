# syntax=docker/dockerfile:1
ARG VCS_REF
ARG BUILD_DATE

FROM hexpm/elixir:1.17.2-erlang-27.0.1-alpine-3.20.2 as base
FROM base as builder
ENV MIX_ENV=prod
ENV ERL_EPMD_ADDRESS=127.0.0.1
ARG VCS_REF

WORKDIR /opt/akkoma

# build dependencies
RUN apk add --no-cache git gcc g++ musl-dev make cmake file-dev exiftool \
  ffmpeg imagemagick libmagic ncurses postgresql-client

# Create a build user
RUN addgroup -g 1000 akkoma && \
  adduser -u 1000 -G akkoma -D -h $(pwd) akkoma
USER akkoma

# Clone the akkoma repository at the specified ref
RUN echo "Using $VCS_REF" &&\
  git clone https://akkoma.dev/AkkomaGang/akkoma.git . &&\
  git checkout "$VCS_REF"

# Download all dependencies and compile the application
RUN mix local.hex --force &&\
  mix local.rebar --force &&\
  mix do deps.get, deps.compile, compile, phx.digest, release

FROM alpine:3.21 as runtime
ARG VCS_REF
ARG BUILD_DATE
LABEL org.opencontainers.image.title="akkoma" \
  org.opencontainers.image.description="Magically expressive social media" \
  org.opencontainers.image.vendor="jaredallard" \
  org.opencontainers.image.documentation="https://docs.akkoma.dev/stable/" \
  org.opencontainers.image.licenses="AGPL-3.0 AND GPL-3.0" \
  org.opencontainers.image.url="https://akkoma.dev" \
  org.opencontainers.image.revision=$VCS_REF \
  org.opencontainers.image.created=$BUILD_DATE
EXPOSE 4000

CMD trap 'exit' INT; /opt/akkoma/bin/pleroma start

WORKDIR /opt/akkoma

# Create a user for running the app
RUN addgroup -g 1000 akkoma && \
  adduser -u 1000 -G akkoma -D -h $(pwd) akkoma

# Install runtime dependencies
RUN apk add --no-cache file-dev exiftool ffmpeg imagemagick libmagic ncurses postgresql-client

# Copy the files from the builder image over.
COPY --chown=1000:1000 --from=builder /opt/akkoma/_build/prod/rel/pleroma .
COPY --chown=1000:1000 --from=builder /opt/akkoma/_build/prod/rel/pleroma_ctl .

USER akkoma

