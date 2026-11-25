FROM alpine:3.22@sha256:49340b346798875b5592e5d420241f2f9cfba5f47e62ebb1446a1b34734e898f

RUN apk add --no-cache socat

USER 65534:65534
ENTRYPOINT ["socat", "TCP-LISTEN:27515,reuseaddr,fork,bind=0.0.0.0", "TCP:127.0.0.1:27514"]
