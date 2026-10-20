FROM node:24-alpine AS development

WORKDIR /app
ENV XDG_DATA_HOME=/tmp
COPY --chown=node:node app/frontend/package.json app/frontend/package-lock.json ./
RUN npm ci --no-audit --no-fund && chown -R node:node /app
COPY --chown=node:node app/frontend/ ./

USER node
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=5 \
    CMD ["node", "-e", "fetch('http://127.0.0.1:8080/').then(r => { if (!r.ok) process.exit(1); }).catch(() => process.exit(1))"]
CMD ["npm", "run", "dev"]

FROM development AS build

ARG VITE_API_BASE=/api
ENV VITE_API_BASE=${VITE_API_BASE}
RUN npm run build

FROM nginx:1.30-alpine AS production

COPY infra/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist/ /usr/share/nginx/html/

EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --retries=5 \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/nginx-healthz || exit 1

# Keep the official Nginx entrypoint and graceful stop signal.
