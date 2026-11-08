# Base: node:24-alpine (Node 24 LTS on Alpine), pinned by its multi-arch
# index digest so every build gets the same bytes. Dependabot bumps it.
FROM node:24-alpine@sha256:a34ab6d7f6f4813f4d0c5469d74685604b962fbdbf5793a7bc7b4998ecb867c8 AS base

# Build stage: production dependencies only, exactly as the lockfile says.
FROM base AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts

# Runtime stage: node, the app source and its production dependencies.
FROM base AS runtime
# The package managers are build tooling the app never runs, and they held
# every HIGH/CRITICAL finding in the Alpine baseline scan, so they go.
RUN rm -rf /usr/local/lib/node_modules \
           /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack \
           /usr/local/bin/yarn /usr/local/bin/yarnpkg /opt/yarn-v*
ENV NODE_ENV=production
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY package.json app.js ./
USER node
EXPOSE 8080
CMD ["node", "app.js"]
