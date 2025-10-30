# Basis-Image: Debian Slim with Node.js 20
FROM node:20-slim
WORKDIR /usr/src/app
# install bash, curl, unzip, 
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    unzip
    
COPY package*.json ./
RUN npm ci

COPY src ./src

USER node
ENV NODE_ENV=production
EXPOSE 3000

# Healthcheck: ensures the container is marked "healthy" once the app is reachable on port 3000.
# This allows CI pipelines (e.g. Compose Smoke Test) to wait until the service is ready before running tests.
HEALTHCHECK --interval=10s --timeout=5s --retries=5 \
  CMD curl -f http://localhost:3000 || exit 1

CMD ["node", "src/server.js"]