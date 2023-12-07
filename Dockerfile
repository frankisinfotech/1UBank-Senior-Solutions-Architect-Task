FROM node:18-alpine
WORKDIR /app

COPY package*.json ./

RUN npm install -g npm@10.2.4
RUN npm install

COPY . .
RUN npm run build

EXPOSE 3000

CMD ["npm", "start"]
