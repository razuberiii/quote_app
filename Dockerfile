# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.4.8

# Gems and application compilation are isolated from browser/PDF runtime packages.
# `docker build --target test` never installs Chromium or fonts.
FROM ruby:${RUBY_VERSION}-slim AS build
WORKDIR /rails
ENV BUNDLE_PATH=/usr/local/bundle BUNDLE_JOBS=2 BUNDLE_RETRY=5
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends build-essential libpq-dev libyaml-dev pkg-config
COPY Gemfile Gemfile.lock ./
RUN --mount=type=cache,target=/root/.bundle \
    --mount=type=cache,target=/usr/local/bundle/cache \
    bundle install && bundle exec bootsnap precompile --gemfile
COPY . .
RUN chmod +x bin/* && sed -i 's/\r$//' bin/* && sed -i 's/ruby\.exe$/ruby/' bin/* && \
    bundle exec bootsnap precompile app/ lib/ && \
    SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

FROM build AS test
ENV RAILS_ENV=test
CMD ["bundle", "exec", "rails", "test"]

FROM ruby:${RUBY_VERSION}-slim AS runtime
WORKDIR /rails
ENV RAILS_ENV=production \
    BUNDLE_PATH=/usr/local/bundle \
    CHROME_BIN=/usr/bin/chromium \
    GROVER_NO_SANDBOX=true \
    QUOTE_PDF_ENGINE=grover
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      chromium curl fonts-noto-cjk libjemalloc2 libpq5 libvips poppler-utils && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so.2 && \
    rm -rf /var/lib/apt/lists/*
ENV LD_PRELOAD=/usr/local/lib/libjemalloc.so.2
RUN groupadd --system --gid 1000 rails && useradd rails --uid 1000 --gid 1000 --create-home
COPY --from=build --chown=rails:rails /usr/local/bundle /usr/local/bundle
COPY --from=build --chown=rails:rails /rails /rails
USER 1000:1000
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
