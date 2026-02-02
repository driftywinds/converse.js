# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY src/headless/package*.json ./src/headless/
COPY src/log/package*.json ./src/log/

# Install dependencies
RUN npm ci --prefer-offline --no-audit

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM nginx:alpine

# Install Node.js for http-server (lightweight alternative to full Node)
RUN apk add --no-cache nodejs npm && \
    npm install -g http-server@14.1.0 && \
    apk del npm

# Copy built files from builder
COPY --from=builder /app/dist /app/dist
COPY --from=builder /app/*.html /app/
COPY --from=builder /app/images /app/images
COPY --from=builder /app/sounds /app/sounds
COPY --from=builder /app/logo /app/logo
COPY --from=builder /app/3rdparty /app/3rdparty
COPY --from=builder /app/src/website.js /app/src/website.js

WORKDIR /app

# Expose port
EXPOSE 8080

# Use http-server to serve the files
CMD ["http-server", "-p", "8080", "-c-1", "--cors"]
