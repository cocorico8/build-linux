# Use the Node v20.10.0 base image
FROM node:20.10.0

# Install necessary tools and dependencies (git, git-lfs, and zstd)
RUN apt-get update && \
    apt-get install -y git git-lfs zstd && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set the working directory to /code
WORKDIR /code
