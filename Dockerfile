FROM ghcr.io/tizbac/pmoxs3backuproxy:v0.0.6 as binary
FROM nginxinc/nginx-unprivileged:stable

# We need to switch to root temporarily to install packages and set permissions.
USER root

# Install supercronic and other dependencies
RUN apt-get update && apt-get install -y wget procps && \
    wget https://github.com/aptible/supercronic/releases/download/v0.2.34/supercronic-linux-amd64 -O /usr/local/bin/supercronic && \
    chmod +x /usr/local/bin/supercronic && \
    rm -rf /var/lib/apt/lists/*

# Copy all necessary files from the build context and the binary stage
COPY garbagecollector /etc/nginx/crontab
COPY garbagecollector.sh /etc/nginx/garbagecollector.sh
COPY nginx.conf /etc/nginx/nginx.conf
COPY entrypoint.sh /entrypoint.sh
COPY --from=binary /pmoxs3backuproxy /pmoxs3backuproxy
COPY --from=binary /garbagecollector /garbagecollector
COPY --from=binary /server.crt /server.crt
COPY --from=binary /server.key /server.key

# Set correct permissions and ownership for all files
RUN chmod 0644 /etc/nginx/crontab && \
    chmod +x /etc/nginx/garbagecollector.sh && \
    chmod +x /entrypoint.sh && \
    chown nginx:nginx /etc/nginx/crontab /etc/nginx/garbagecollector.sh

# Switch to the non-privileged user for runtime
USER nginx

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
