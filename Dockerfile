# --- Builder stage ---
FROM elixir:1.17-otp-27-alpine AS builder

RUN apk add --no-cache build-base git nodejs npm

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

# Fetch dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# Copy config before compiling deps (needed for compile-time config)
COPY config/ config/

# Compile dependencies
RUN mix deps.compile

# Copy source
COPY lib/ lib/
COPY priv/ priv/

# Deploy assets if present
RUN if [ -d "assets" ]; then \
      mix assets.deploy; \
    fi

# Build release (standard mix release, not Burrito)
RUN mix release

# --- Runtime stage ---
FROM alpine:3.19 AS runtime

RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR /app

ENV MIX_ENV=prod \
    PORT=4000 \
    PHX_SERVER=true

# Copy the release from builder
COPY --from=builder /app/_build/prod/rel/kontor ./

EXPOSE 4000

CMD ["/app/bin/kontor", "start"]
