# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t quote_app .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name quote_app quote_app

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.4.8
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

ARG WKHTMLTOX_VERSION=0.12.6.1-3

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      ca-certificates \
      chromium \
      curl \
      fontconfig \
      fonts-ipafont-gothic \
      fonts-noto-cjk \
      libjpeg62-turbo \
      libpng16-16 \
      libx11-6 \
      libxext6 \
      libxrender1 \
      xfonts-75dpi \
      xfonts-base \
      libjemalloc2 \
      libvips \
      postgresql-client && \
    arch="$(dpkg --print-architecture)" && \
    case "$arch" in \
      amd64) wkhtml_arch="amd64" ;; \
      arm64) wkhtml_arch="arm64" ;; \
      *) echo "Unsupported architecture for wkhtmltox package: $arch" && exit 1 ;; \
    esac && \
    wkhtml_deb="wkhtmltox_${WKHTMLTOX_VERSION}.bookworm_${wkhtml_arch}.deb" && \
    wkhtml_url="https://github.com/wkhtmltopdf/packaging/releases/download/${WKHTMLTOX_VERSION}/${wkhtml_deb}" && \
    echo "Downloading ${wkhtml_url}" && \
    curl -fL "${wkhtml_url}" -o "/tmp/${wkhtml_deb}" && \
    apt-get install --no-install-recommends -y "/tmp/${wkhtml_deb}" && \
    rm -f "/tmp/${wkhtml_deb}" && \
    fc-cache -f && \
    wkhtmltopdf -V && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment variables and enable jemalloc for reduced memory usage and latency.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so" \
    CHROME_BIN="/usr/bin/chromium" \
    GROVER_NO_SANDBOX="true" \
    QUOTE_PDF_ENGINE="grover" \
    QUOTE_PDF_FONT_PATH="/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf" \
    WKHTMLTOPDF_PATH="/usr/bin/wkhtmltopdf"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY vendor/* ./vendor/
COPY Gemfile Gemfile.lock ./

RUN bundle config set --local retry 5 && \
    bundle config set --local timeout 30 && \
    bundle install --jobs 1 && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
    bundle exec bootsnap precompile -j 1 --gemfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times.
# -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Adjust binfiles to be executable on Linux
RUN chmod +x bin/* && \
    sed -i "s/\r$//g" bin/* && \
    sed -i 's/ruby\.exe$/ruby/' bin/*

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile




# Final stage for app image
FROM base

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

# Copy built artifacts: gems, application
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
