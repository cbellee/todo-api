FROM golang:latest AS builder
COPY ./src/ /
WORKDIR /
RUN CGO_ENABLED=1 GOOS=linux go build -ldflags="-s -w" -o api .

FROM scratch 
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /api /
ENTRYPOINT ["/api"]
EXPOSE 8080
