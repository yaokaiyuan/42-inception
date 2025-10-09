FROM debian:12

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx openssl ca-certificates && rm -rf /var/lib/apt/lists/*

# Remove default site if present; we'll copy config via bind mount
RUN mkdir -p /run/nginx

COPY conf /etc/nginx/conf.d

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]
