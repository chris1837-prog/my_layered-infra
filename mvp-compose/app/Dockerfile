FROM node:20-alpine
WORKDIR /usr/src/app

# Install only production deps
COPY package*.json ./
RUN npm install --omit=dev

# App source
COPY src ./src

ENV NODE_ENV=production
EXPOSE 3000

CMD ["node", "src/server.js"]
