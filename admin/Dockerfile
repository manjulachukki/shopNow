# admin/Dockerfile
############################
# Stage 1: Build
############################
FROM node:20-alpine AS builder
WORKDIR /app

# Allow overriding npm TLS strictness in environments with corporate SSL interception.
ARG NPM_CONFIG_STRICT_SSL=false
ENV NPM_CONFIG_STRICT_SSL=${NPM_CONFIG_STRICT_SSL}

COPY package*.json ./
RUN npm config set strict-ssl ${NPM_CONFIG_STRICT_SSL} \
 && npm config set fetch-retries 5 \
 && npm config set fetch-retry-mintimeout 20000 \
 && npm config set fetch-retry-maxtimeout 120000 \
 && npm ci --no-audit --prefer-offline \
 && test -x node_modules/.bin/react-scripts

COPY . .
RUN npm run build

############################
# Stage 2: Runtime (nginx)
############################
FROM nginx:1.24-alpine

# Copy admin-specific nginx config included in the admin folder
COPY nginx/default.conf /etc/nginx/conf.d/default.conf

# Copy built static admin app
COPY --from=builder /app/build /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=15s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- --no-check-certificate http://127.0.0.1/health || exit 1

CMD ["nginx", "-g", "daemon off;"]

