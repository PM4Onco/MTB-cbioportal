FROM alpine as build

RUN mkdir -p /opt/shinyproxy/
RUN wget https://www.shinyproxy.io/downloads/shinyproxy-2.5.0.jar -O /opt/shinyproxy/shinyproxy.jar

FROM gcr.io/distroless/java21-debian12

COPY --from=build /opt/shinyproxy/shinyproxy.jar /app/shinyproxy.jar
COPY application.yml /app/application.yml
WORKDIR /app
CMD ["/app/shinyproxy.jar"]
