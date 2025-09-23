FROM node:22-alpine
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install || yarn install --frozen-lockfile
COPY . .
EXPOSE 4000
CMD ["node", "index.js"]
