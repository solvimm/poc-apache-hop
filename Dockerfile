# Use specific version for production, latest for development
ARG HOP_VERSION=latest
FROM apache/hop:${HOP_VERSION}

# Set environment variables with defaults
ENV HOP_USER=hop \
    HOP_HOME=/home/hop \
    PROJECT_HOME=/files \
    HOP_CONFIG_DIRECTORY=/home/hop/project-config \
    HOP_LOG_LEVEL=Basic \
    HOP_PLATFORM_RUNTIME=local \
    HOP_AUDIT_FOLDER=/home/hop/audit \
    HOP_SHARED_JDBC_FOLDER=/home/hop/shared-jdbc \
    HOP_WEB_HOST=0.0.0.0 \
    HOP_WEB_PORT=8080 \
    HOP_RUN_CONFIG=local \
    HOP_PROJECT_NAME=default-project \
    ENV_TYPE=development \
    # ADD THIS: Crash prevention Java options
    JAVA_OPTS="-Xmx1G -XX:+UseG1GC -Djava.net.preferIPv4Stack=true -Djava.awt.headless=true"

# Install only necessary dependencies
USER root
RUN apk add --no-cache \
        curl \
        jq \
        bash \
        gettext \
        # ADD THESE: Libraries to fix native crashes
        libc6-compat \
        gcompat \
        ca-certificates

# Create directory structure
RUN mkdir -p \
    ${PROJECT_HOME} \
    ${PROJECT_HOME}/drivers \
    ${PROJECT_HOME}/metadata \
    ${PROJECT_HOME}/pipelines \
    ${HOP_CONFIG_DIRECTORY} \
    ${HOP_AUDIT_FOLDER} \
    ${HOP_SHARED_JDBC_FOLDER} \
    /opt/hop/scripts

# Copy scripts
COPY --chown=hop:hop scripts/ /opt/hop/scripts/

# Copy project files based on actual structure
COPY --chown=hop:hop metadata/ ${PROJECT_HOME}/metadata/
COPY --chown=hop:hop drivers/ ${PROJECT_HOME}/drivers/
COPY --chown=hop:hop project-config.json ${PROJECT_HOME}/
COPY --chown=hop:hop pipelines/ ${PROJECT_HOME}/pipelines/

# Set permissions and make scripts executable
RUN chown -R hop:hop ${PROJECT_HOME} ${HOP_CONFIG_DIRECTORY} && \
    chmod -R 755 ${PROJECT_HOME} && \
    chmod +x /opt/hop/scripts/*.sh

USER hop
WORKDIR ${HOP_HOME}
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /opt/hop/scripts/healthcheck.sh

# Use entrypoint script for dynamic configuration
ENTRYPOINT ["/opt/hop/scripts/entrypoint.sh"]
CMD ["start"]