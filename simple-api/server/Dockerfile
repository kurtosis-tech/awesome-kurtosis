FROM node:18-alpine
WORKDIR /usr/app
COPY ./* ./
RUN npm install
RUN npm run build
RUN npm run postbuild

EXPOSE 8080

ENV NODE_ENV="production"
CMD ["node", "./build/index.js"]
