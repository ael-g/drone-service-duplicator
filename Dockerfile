FROM alpine:latest
RUN apk update && apk --no-cache add curl ca-certificates bash py2-pip jq
RUN pip install yq
RUN curl -Lo /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
RUN chmod +x /usr/local/bin/kubectl
COPY update.sh /bin/
ENTRYPOINT ["/bin/bash"]
CMD ["/bin/update.sh"]
