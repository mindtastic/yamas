FROM elixir:1.13.4-alpine AS builder

# Install system dependencies
RUN mix local.hex --force
RUN mix local.rebar --force

# Add source
ADD . /build/
WORKDIR /build

ENV MIX_ENV=prod

# Fetch elixir dependecies
RUN mix deps.get

# Compile
RUN mix compile

# Run test-suite
RUN mix compile

# Buid release
RUN mix release yamas

############################
FROM alpine:latest AS runner

RUN apk add --no-cache openssl ncurses-libs libgcc libstdc++

# Install release
COPY --from=builder /build/_build/prod/rel/yamas /app

# Configure environment
ENV RELEASE_DISTRIBUTION="name"
ENV RELEASE_NAME = "yamas"

# Override those at runtime, especially the cookie!
# Otherwise the one generate by `mix release`
# will used. This can be a security issue
ENV RELEASE_IP = "127.0.0.1"
ENV RELEASE_COOKIE = ""

# Full node name if spawned in an elixir cluster
ENV RELEASE_NODE="${RELEASE_NAME}@${RELEASE_IP}"

ENTRYPOINT [ "/app/bin/yamas" ]
CMD ["start"]