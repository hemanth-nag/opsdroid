# Use Ubuntu-based Python image
ARG BASE_IMAGE="python:3.13-slim"
FROM $BASE_IMAGE AS builder
LABEL maintainer="Jacob Tomlinson <jacob@tomlinson.email>"

WORKDIR /usr/src/app

ARG EXTRAS=[all,connector_matrix_e2e]
ENV DEPS_DIR=/usr/src/app/deps

# Copy source
COPY . .

# Install build tools and libraries to build OpsDroid and dependencies
RUN apt-get update && \
    apt-get install -y \
    build-essential \
    cargo \
    gcc \
    git \
    libffi-dev \
    libolm-dev \
    libssl-dev \
    python3-dev \
    libzmq3-dev \
    ssh \
    wget \
    curl \
    && pip install --upgrade \
    build \
    pip \
    setuptools \
    setuptools-scm \
    wheel \
    && mkdir -p "${DEPS_DIR}" \
    && pip download --prefer-binary -d ${DEPS_DIR} .${EXTRAS} \
    && pip wheel -w ${DEPS_DIR} ${DEPS_DIR}/*.tar.gz \
    && count=$(ls -1 ${DEPS_DIR}/*.zip 2>/dev/null | wc -l) && if [ $count != 0 ]; then pip wheel -w ${DEPS_DIR} ${DEPS_DIR}/*.zip ; fi \
    && python -m build --wheel --outdir ${DEPS_DIR}

FROM $BASE_IMAGE AS runtime
LABEL maintainer="Jacob Tomlinson <jacob@tomlinson.email>"
LABEL maintainer="Rémy Greinhofer <remy.greinhofer@gmail.com>"

WORKDIR /usr/src/app

ARG EXTRAS=[all,connector_matrix_e2e]
ENV DEPS_DIR=/usr/src/app/deps

# Copy pre-built dependencies
COPY --from=builder ${DEPS_DIR}/*.whl ${DEPS_DIR}/

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y \
    git \
    libolm3 \
    libzmq3-dev \
    && pip install --upgrade pip setuptools \
    && pip install --no-cache-dir --no-index -f ${DEPS_DIR} \
    $(find ${DEPS_DIR} -type f -name opsdroid-*-any.whl)${EXTRAS} \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ${DEPS_DIR}/* \
    && useradd -u 1001 -m opsdroid

EXPOSE 8080

USER opsdroid
ENTRYPOINT ["opsdroid"]
CMD ["start"]
