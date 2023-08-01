FROM node:alpine as build

WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build
 
FROM nginx:alpine

WORKDIR /usr/share/nginx/html
COPY --from=build /app/build .
COPY --from=build /app/env.sh .
COPY --from=build /app/.env .
# COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80

# Make our shell script executable
RUN chmod +x ./env.sh

# Start Nginx server
CMD ["/bin/sh", "-c", "/usr/share/nginx/html/env.sh && nginx -g \"daemon off;\""]
