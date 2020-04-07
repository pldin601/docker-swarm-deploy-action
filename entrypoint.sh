#!/bin/sh
set -e +u

if [ -z "$INPUT_REMOTE_HOST" ]; then
    echo "Input remote_host is required!"
    exit 1
fi

# Extra handling for SSH-based connections.
if [ ${INPUT_REMOTE_HOST#"ssh://"} != "$INPUT_REMOTE_HOST" ]; then
    SSH_HOST=${INPUT_REMOTE_HOST#"ssh://"}
    SSH_HOST=${SSH_HOST#*@}

    if [ -z "$INPUT_SSH_PRIVATE_KEY" ]; then
        echo "Input ssh_private_key is required for SSH hosts!"
        exit 1
    fi

    if [ -z "$INPUT_SSH_PUBLIC_KEY" ]; then
        echo "Input ssh_public_key is required for SSH hosts!"
        exit 1
    fi

    echo "Registering SSH keys..."

    # Save private key to a file and register it with the agent.
    mkdir -p "$HOME/.ssh"
    printf '%s' "$INPUT_SSH_PRIVATE_KEY" > "$HOME/.ssh/docker"
    chmod 600 "$HOME/.ssh/docker"
    eval $(ssh-agent)
    ssh-add "$HOME/.ssh/docker"

    # Add public key to known hosts.
    ssh-keyscan -H "$SSH_HOST" >> /etc/ssh/ssh_known_hosts
fi

if [ -n "$INPUT_AWS_ACCESS_KEY_ID" ] && [ -n "$INPUT_AWS_SECRET_ACCESS_KEY" ]; then
  echo "Setting AWS credentials..."
  aws configure set aws_access_key_id "$INPUT_AWS_ACCESS_KEY_ID"
  aws configure set aws_secret_access_key "$INPUT_AWS_SECRET_ACCESS_KEY"

  echo "Executing aws ecr get-login..."
  aws ecr get-login --no-include-email --region eu-central-1 | sh
fi

if [ -n "$INPUT_DOCKER_USERNAME" ] && [ -n "$INPUT_DOCKER_PASSWORD" ] && [ -n "$INPUT_DOCKER_REGISTRY" ]; then
  echo "Logging in to the registry..."
  docker login -u "$INPUT_DOCKER_USERNAME" -p "$INPUT_DOCKER_PASSWORD" "$INPUT_DOCKER_REGISTRY"
fi

echo "Connecting to $INPUT_REMOTE_HOST..."
docker --host "$INPUT_REMOTE_HOST" "$@" 2>&1
