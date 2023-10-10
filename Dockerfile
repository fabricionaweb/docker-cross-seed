# syntax=docker/dockerfile:1-labs
FROM public.ecr.aws/docker/library/alpine:3.18 AS base
ENV TZ=UTC

# source stage =================================================================
FROM base AS source
WORKDIR /src

# get and extract source from git
ARG VERSION
ADD https://github.com/cross-seed/cross-seed.git#v$VERSION ./

# build stage ==================================================================
FROM base AS build-backend
WORKDIR /src

# dependencies
RUN apk add --no-cache build-base python3 nodejs-current && corepack enable npm

# node_modules
COPY --from=source /src/package*.json /src/tsconfig.json ./
RUN npm ci --fund=false --audit=false

# source and build
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

# runtime dependencies
RUN apk add --no-cache tzdata s6-overlay nodejs-current curl

# copy files
COPY --from=source /src/package.json /app/
COPY --from=build-backend /src/node_modules /app/node_modules
COPY --from=build-backend /src/dist /app/dist
COPY ./rootfs/. /

# run using s6-overlay
ENTRYPOINT ["/init"]
