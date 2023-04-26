FROM alpine:3.17

RUN apk update && apk add jq && apk add curl

COPY build/run.jar  ./
COPY flink_job_loader/upload_run.sh  ./

ENV FLINK_HOST="localhost"
ENV FLINK_API_PORT=8081
ENV RUN_JAR="run.jar"

CMD ["sh", "upload_run.sh"]
