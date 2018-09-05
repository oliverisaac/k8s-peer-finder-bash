FROM alpine:3.8
# Originally from Rory McCune <rorym@mccune.org.uk>
MAINTAINER Oliver Isaac <oisaac@gmail.com>

RUN apk --update add bind-tools bash && rm -rf /var/cache/apk/*

COPY peer-finder.sh /
RUN chmod +x /peer-finder.sh

ENTRYPOINT ["/peer-finder.sh"]

