FROM node:22-alpine
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install || yarn install --frozen-lockfile
COPY . .
EXPOSE 4200 4201
CMD ["node", "index.js"]