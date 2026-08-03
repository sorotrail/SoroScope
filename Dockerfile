FROM golang:1.25-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /out/soroscope ./cmd/soroscope

FROM alpine:3.20
RUN adduser -D -H soroscope && apk add --no-cache ca-certificates
USER soroscope
COPY --from=build /out/soroscope /usr/local/bin/soroscope
EXPOSE 8080
ENTRYPOINT ["soroscope"]
