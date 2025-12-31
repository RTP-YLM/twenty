# Multi-stage build to reduce final image size
FROM node:20-slim AS base

# Install system dependencies for canvas and other native modules
RUN apt-get update && apt-get install -y \
    python3 \
    build-essential \
    pkg-config \
    libcairo2-dev \
    libpango1.0-dev \
    libjpeg-dev \
    libgif-dev \
    librsvg2-dev \
    libpixman-1-dev \
    && rm -rf /var/lib/apt/lists/*

# Enable corepack for yarn
RUN corepack enable

WORKDIR /app

# Copy package files
COPY package.json yarn.lock .yarnrc.yml ./
COPY .yarn ./.yarn
COPY packages/twenty-server/package.json ./packages/twenty-server/
COPY packages/twenty-shared/package.json ./packages/twenty-shared/
COPY packages/twenty-emails/package.json ./packages/twenty-emails/

# Copy patches directory (required for patched dependencies)
COPY packages/twenty-server/patches ./packages/twenty-server/patches

# Install all dependencies (needed for build)
RUN yarn workspaces focus twenty-server

# Copy source files
COPY packages/twenty-server ./packages/twenty-server
COPY packages/twenty-shared ./packages/twenty-shared
COPY packages/twenty-emails ./packages/twenty-emails
COPY nx.json tsconfig.base.json ./

# Build the server
RUN npx nx build twenty-server --skip-nx-cache

# Production stage - copy only necessary files
FROM node:20-slim AS production

# Install runtime dependencies for canvas
RUN apt-get update && apt-get install -y \
    libcairo2 \
    libpango-1.0-0 \
    libjpeg62-turbo \
    libgif7 \
    librsvg2-2 \
    libpixman-1-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy built artifacts and production dependencies
COPY --from=base /app/packages/twenty-server/dist ./dist
COPY --from=base /app/packages/twenty-server/package.json ./package.json
COPY --from=base /app/node_modules ./node_modules

# Expose port
EXPOSE 3000

# Start the server
CMD ["node", "dist/main"]
