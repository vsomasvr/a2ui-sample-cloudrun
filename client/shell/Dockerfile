# Stage 1: Build the React frontend
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
# The build explicitly depends on .env.production routing to /api
RUN npm run build

# Stage 2: Serve via Node Express (BFF)
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
# Install only the backend proxy dependencies
RUN npm install --omit=dev
COPY --from=builder /app/dist ./dist
COPY server.js ./

# Run as the unprivileged native Node user for maximum security matching our Agent
RUN chown -R node:node /app
USER node

EXPOSE 8080
ENV PORT=8080

CMD ["node", "server.js"]
