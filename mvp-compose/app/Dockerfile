# Basis-Image: Debian Slim with Node.js 20
FROM node:20-slim
WORKDIR /usr/src/app
# install bash, curl, unzip, 
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    unzip \
    # Clean up APT cache to reduce image size
    && rm -rf /var/lib/apt/lists/*

COPY package*.json ./
RUN npm ci --omit=dev

COPY src ./src

USER node
ENV NODE_ENV=production
EXPOSE 3000
CMD ["node", "src/server.js"]