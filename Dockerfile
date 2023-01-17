FROM golang:1.19.3 AS build
RUN mkdir /build
WORKDIR /build
COPY ./api/ .
RUN useradd -u 10001 scratchuser
RUN apt update && apt -y install ca-certificates && mkdir /persist && chown scratchuser:scratchuser /persist && mkdir /keys && chown scratchuser:scratchuser /keys && chmod -R 0700 /keys

RUN CGO_ENABLED=1 GOOS=linux go build -a -ldflags '-linkmode external -extldflags "-static"' -o app .

FROM scratch
COPY --from=build /etc/passwd /etc/passwd
COPY --chown=10001:10001 --from=build /persist /persist
COPY --chown=10001:10001 --from=build /keys /keys
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=build /build/app .

USER 10001
CMD [ "./app" ] 
EXPOSE 8080