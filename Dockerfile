FROM debian:bullseye AS docker-cli

# Install docker in this container that way we can use docker-cli later
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - \
    && echo "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update && apt-get install -y docker-ce-cli

# Make a new container that will be the final image \
FROM debian:bullseye-slim

# Copy docker-cli from the previous container
COPY --from=docker-cli /usr/bin/docker /usr/bin/docker

# Copy the shell script that will handle port forwarding
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# Install the packages we need
# So far we only need natpmpc
RUN apt-get update && apt-get install --no-install-suggests --no-install-recommends -y \
    natpmpc \
    && rm -rf /var/lib/apt/lists/* \
    && apt clean \
    && chmod +x /usr/local/bin/docker-entrypoint.sh

# Set the command that will be run when the container starts
CMD ["/usr/local/bin/docker-entrypoint.sh"]
