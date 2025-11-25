FROM debian:12

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx openssl ca-certificates && rm -rf /var/lib/apt/lists/*

# Remove default site if present; we'll copy config via bind mount
RUN mkdir -p /run/nginx

# Copy config and ssl separately
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/ssl /etc/nginx/ssl

EXPOSE 443

COPY tools/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
