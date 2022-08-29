ARG VERSION

FROM nginx:alpine AS base
EXPOSE 80
EXPOSE 443

FROM node:16.14-alpine AS build
ARG VERSION
WORKDIR /src
RUN apk add chromium
COPY package*.json /src
RUN npm version $VERSION
RUN npm ci
COPY . /src
RUN npm run build --prod

FROM build AS test
ENV CI=true
ENV CHROME_BIN=/usr/bin/chromium-browser
RUN npm test

FROM base AS final
COPY --from=build /src/dist/blog /usr/share/nginx/html
