FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .

FROM node:20-alpine
RUN adduser -D appuser
WORKDIR /app
COPY --from=builder /app .
USER appuser
EXPOSE 3000
CMD ["node", "index.js"]