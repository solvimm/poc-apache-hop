#!/bin/bash

# Simple healthcheck for Apache Hop server
# Checks if the web interface is responding

HOP_WEB_PORT=${HOP_WEB_PORT:-8080}
HOP_WEB_HOST=${HOP_WEB_HOST:-localhost}

# Check if the web interface is responding
if curl -f -s "http://${HOP_WEB_HOST}:${HOP_WEB_PORT}/hop" > /dev/null 2>&1; then
    echo "Hop server is healthy"
    exit 0
else
    echo "Hop server is not responding"
    exit 1
fi