# Build a k6 that embeds xk6-sql and the Postgres driver.
# Pins known-good versions:
#   - k6 core:          v0.51.0 (override via --build-arg K6_VER)
#   - xk6-sql:          v1.0.5   (XK6_SQL_REF)
#   - xk6-sql-postgres: v0.1.1   (XK6_SQL_PG_REF)

ARG K6_VER=v0.51.0
ARG XK6_SQL_REF=v1.0.5
ARG XK6_SQL_PG_REF=v0.1.1

FROM golang:1.24-alpine AS builder
ARG K6_VER
ARG XK6_SQL_REF
ARG XK6_SQL_PG_REF

RUN apk add --no-cache git ca-certificates && update-ca-certificates
RUN go install go.k6.io/xk6/cmd/xk6@latest

# Build the custom k6 with both the core SQL extension and the Postgres driver.
RUN /go/bin/xk6 build ${K6_VER} \
    --with github.com/grafana/xk6-sql@${XK6_SQL_REF} \
    --with github.com/grafana/xk6-sql-driver-postgres@${XK6_SQL_PG_REF} \
    --output /go/bin/k6

FROM alpine:3.20
RUN apk add --no-cache ca-certificates && update-ca-certificates
COPY --from=builder /go/bin/k6 /usr/bin/k6

# for convenience if you `docker run ...` without args
ENTRYPOINT ["k6"]