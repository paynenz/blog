ARG VERSION

FROM nginx:alpine AS base
EXPOSE 80

FROM node:16.14-alpine AS build
ARG VERSION
WORKDIR /src
COPY package*.json /src
RUN npm version $VERSION
RUN npm ci
COPY . /src
RUN npm run build --prod

FROM build AS test
ENV CI=true
ENV CHROME_BIN=/usr/bin/chromium-browser
RUN apk add chromium
RUN npm test

FROM base AS final
COPY --from=build /src/dist/blog /usr/share/nginx/html
