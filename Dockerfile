# Dockerfile — serve static build with lightweight nginx
FROM nginx:alpine
# Remove default nginx content
RUN rm -rf /usr/share/nginx/html/*
# Copy build artefact (dist) into nginx html folder
COPY dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
