FROM hadolint/hadolint:latest-alpine AS hadolint

FROM docker:cli

RUN apk add --no-cache \
    bash \
    docker-cli-compose \
    nodejs \
    npm \
    py3-pip \
    shellcheck \
    shfmt \
  && pip install --break-system-packages --no-cache-dir yamllint \
  && npm install --global markdownlint-cli2 prettier

COPY --from=hadolint /bin/hadolint /usr/local/bin/hadolint

WORKDIR /workspace

CMD ["bash"]
