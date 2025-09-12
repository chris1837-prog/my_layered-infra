{{ .domain }} {
    reverse_proxy {{ .app_private_ip }}:{{ .app_port }}

    header_up X-Forwarded-For {remote_host}
    header_up X-Forwarded-Proto {scheme}

    log {
        output file /var/log/caddy/access.log
        format json
    }

    tls you@example.com
}
