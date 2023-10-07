# syntax=docker/dockerfile:1-labs
FROM public.ecr.aws/docker/library/alpine:3.18 AS base
ARG BRANCH
ARG VERSION
ENV TZ=UTC

# source stage =================================================================
FROM base AS source
WORKDIR /src

# mandatory build-arg
RUN test -n "$BRANCH" && test -n "$VERSION"

# get and extract source from git
ADD https://github.com/cross-seed/cross-seed.git#v$VERSION ./

# dependencies
# RUN apk add --no-cache patch

# apply available patches
# COPY patches ./
# RUN find . -name "*.patch" -print0 | sort -z | xargs -t -0 -n1 patch -p1 -i

# build stage ==================================================================
FROM base AS build-backend
WORKDIR /src

# dependencies
RUN apk add --no-cache build-base python3 nodejs-current && corepack enable npm

# node_modules
COPY --from=source /src/package*.json /src/tsconfig.json ./
RUN npm ci --foreground-scripts=true

# build
COPY --from=source /src/src ./src
RUN npm run build

# cleanup
RUN npm prune --omit=dev && \
    find ./ \( -name "*.map" -o -name "*.ts" -o -name "*.md" \) -type f -delete

# runtime stage ================================================================
FROM base

ENV S6_VERBOSITY=0 S6_BEHAVIOUR_IF_STAGE2_FAILS=2 PUID=65534 PGID=65534
ENV DOCKER_ENV=true CONFIG_DIR=/config
WORKDIR /config
VOLUME /config
EXPOSE 2468

# copy files
COPY --from=build-backend /src/package.json /app/
COPY --from=build-backend /src/dist /app/dist
COPY --from=build-backend /src/node_modules /app/node_modules
COPY ./rootfs /

# runtime dependencies
RUN apk add --no-cache tzdata s6-overlay nodejs-current curl

# run using s6-overlay
ENTRYPOINT ["/init"]