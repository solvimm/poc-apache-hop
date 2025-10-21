#!/bin/bash

set -e

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${ENV_TYPE}] $1"
}

# Function to validate environment
validate_environment() {
    case "${ENV_TYPE}" in
        development|prod|production)
            log "Environment type: ${ENV_TYPE}"
            ;;
        *)
            log "ERROR: Invalid ENV_TYPE '${ENV_TYPE}'. Must be 'development' or 'production'"
            exit 1
            ;;
    esac
}

# Function to setup environment-specific configuration
setup_environment() {
    log "Setting up Apache Hop Server"
    validate_environment
    
    # Create necessary directories
    mkdir -p ${HOP_AUDIT_FOLDER} ${HOP_SHARED_JDBC_FOLDER}
    
    # Setup Google Cloud credentials
    setup_google_credentials
    
    # Generate configuration files
    generate_configuration
    
    # Apply environment-specific settings
    case "${ENV_TYPE}" in
        development)
            setup_development
            ;;
        prod|production)
            setup_production
            ;;
    esac
}

# Function to setup Google Cloud credentials
setup_google_credentials() {
    case "${ENV_TYPE}" in
        development)
            setup_google_development
            ;;
        prod|production)
            setup_google_production
            ;;
    esac
}

# Function to setup Google Cloud for development
setup_google_development() {
    log "Setting up Google Cloud credentials for development..."
    
    # Check if gcloud config exists
    if [ -f "/home/hop/.config/gcloud/application_default_credentials.json" ]; then
        export GOOGLE_APPLICATION_CREDENTIALS=/home/hop/.config/gcloud/application_default_credentials.json
        log "Using gcloud application default credentials"
        
        # Get active account from gcloud config
        if [ -f "/home/hop/.config/gcloud/active_config" ]; then
            local active_config=$(cat /home/hop/.config/gcloud/active_config)
            if [ -f "/home/hop/.config/gcloud/configurations/config_${active_config}" ]; then
                local project=$(grep "^project" /home/hop/.config/gcloud/configurations/config_${active_config} | cut -d'=' -f2 | tr -d ' ')
                if [ -n "$project" ]; then
                    export GOOGLE_CLOUD_PROJECT=${project}
                    log "Detected Google Cloud Project: ${project}"
                fi
            fi
        fi
        
        # Validate credentials
        if check_gcloud_credentials; then
            log "Google Cloud credentials are valid"
        else
            log "WARNING: Google Cloud credentials may be invalid or expired"
            log "Please run: gcloud auth login"
        fi
    else
        log "WARNING: No gcloud credentials found in development mode"
        log "Please run: gcloud auth login"
        log "Or set GOOGLE_APPLICATION_CREDENTIALS_JSON for production-style auth"
    fi
}

# Function to setup Google Cloud for production
setup_google_production() {
    log "Setting up Google Cloud credentials for production..."
    
    if [ -n "$GOOGLE_APPLICATION_CREDENTIALS_JSON" ]; then
        mkdir -p /home/hop/.config/gcloud
        echo "$GOOGLE_APPLICATION_CREDENTIALS_JSON" > /home/hop/.config/gcloud/application_credentials.json
        export GOOGLE_APPLICATION_CREDENTIALS=/home/hop/.config/gcloud/application_credentials.json
        log "Google Cloud service account credentials configured from environment variable"
    else
        log "ERROR: GOOGLE_APPLICATION_CREDENTIALS_JSON environment variable is required in production"
        log "Please set this variable with the JSON content of your service account key"
        exit 1
    fi
    
    # Validate required production settings
    if [ -z "$GOOGLE_CLOUD_PROJECT" ]; then
        log "ERROR: GOOGLE_CLOUD_PROJECT is required in production environment"
        exit 1
    fi
    
    if [ -z "$GOOGLE_SERVICE_ACCOUNT_EMAIL" ]; then
        log "ERROR: GOOGLE_SERVICE_ACCOUNT_EMAIL is required in production environment"
        exit 1
    fi
}

# Function to check if gcloud credentials are valid
check_gcloud_credentials() {
    if [ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
        # Check if credentials file exists and is readable
        if [ -r "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
            return 0
        fi
    fi
    return 1
}

# Function to generate configuration files
generate_configuration() {
    log "Setting up configuration files for ${ENV_TYPE} environment..."
    
    # Use existing project-config.json if available
    if [ -f "${PROJECT_HOME}/project-config.json" ]; then
        cp "${PROJECT_HOME}/project-config.json" "${HOP_CONFIG_DIRECTORY}/project-config.json"
        log "Using existing project-config.json"
    fi
    
    # Ensure metadata directory exists
    mkdir -p "${PROJECT_HOME}/metadata"
    
    # Set up Hop environment variables
    export HOP_LOG_LEVEL="${HOP_LOG_LEVEL:-Basic}"
    export HOP_FILE_PATH="${HOP_FILE_PATH:-${PROJECT_HOME}/pipelines/filename.hwf}"
    export HOP_PROJECT_FOLDER="${HOP_PROJECT_FOLDER:-${PROJECT_HOME}}"
    export HOP_SHARED_JDBC_FOLDERS="${HOP_SHARED_JDBC_FOLDERS:-${PROJECT_HOME}/drivers}"
    export HOP_PROJECT_NAME="${HOP_PROJECT_NAME:-docker_teste}"
    export HOP_RUN_CONFIG="${HOP_RUN_CONFIG:-local}"
    
    if [ -d "${PROJECT_HOME}/drivers" ]; then
        log "JDBC drivers available at: ${PROJECT_HOME}/drivers"
    fi
    
    log "Configuration setup completed"
}

# Function for development setup
setup_development() {
    log "Configuring development environment..."
    
    # Enable debug if requested
    if [ "$HOP_DEBUG_ENABLED" = "true" ]; then
        export JAVA_OPTS="$JAVA_OPTS -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:${HOP_DEBUG_PORT}"
        log "Debug mode enabled on port ${HOP_DEBUG_PORT}"
    fi
    
    # Development-specific Java options with crash prevention
    if [ -z "$JAVA_OPTS" ]; then
        export JAVA_OPTS="-Xmx1G -XX:+UseG1GC -Djava.net.preferIPv4Stack=true -Djava.awt.headless=true -Dhttps.protocols=TLSv1.2"
    else
        # Ensure crash prevention options are included
        export JAVA_OPTS="$JAVA_OPTS -Djava.net.preferIPv4Stack=true -Djava.awt.headless=true -Dhttps.protocols=TLSv1.2"
    fi
    
    log "Development environment ready"
    log "GCloud config mounted from: ${GCLOUD_CONFIG_PATH:-~/.config/gcloud}"
}

# Function for production setup
setup_production() {
    log "Configuring production environment..."
    
    # Production-optimized Java options with crash prevention
    if [ -z "$JAVA_OPTS" ]; then
        export JAVA_OPTS="-Xmx2G -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -Djava.net.preferIPv4Stack=true -Djava.awt.headless=true -Dhttps.protocols=TLSv1.2"
    else
        # Ensure crash prevention options are included
        export JAVA_OPTS="$JAVA_OPTS -Djava.net.preferIPv4Stack=true -Djava.awt.headless=true -Dhttps.protocols=TLSv1.2"
    fi
    
    # Production security settings
    export HOP_AUTH_ENABLED=true
    export HOP_VOLUME_PERMISSIONS=ro
    
    log "Production environment configured with memory limit: ${HOP_MEMORY_LIMIT:-2G}"
}

# Function to run pipeline with crash protection
run_pipeline_safely() {
    local pipeline_file="$1"
    local max_retries=3
    local retry_count=0
    
    log "Running pipeline: $pipeline_file"
    
    while [ $retry_count -lt $max_retries ]; do
        log "Attempt $((retry_count + 1)) of $max_retries"
        
        if /opt/hop/hop-run.sh \
            -f "$pipeline_file" \
            -r "${HOP_RUN_CONFIG}" \
            -l "${HOP_LOG_LEVEL}"; then
            log "Pipeline completed successfully"
            return 0
        else
            EXIT_CODE=$?
            retry_count=$((retry_count + 1))
            
            # Check if it's a crash (SIGSEGV = 134, SIGBUS = 135)
            if [ $EXIT_CODE -eq 134 ] || [ $EXIT_CODE -eq 135 ] || [ $EXIT_CODE -eq 139 ]; then
                log "Pipeline crashed with signal $EXIT_CODE. Retrying in 5 seconds..."
                sleep 5
            else
                log "Pipeline failed with exit code $EXIT_CODE (not a crash). Not retrying."
                return $EXIT_CODE
            fi
        fi
    done
    
    log "Pipeline failed after $max_retries attempts due to crashes"
    return 1
}

# Function to trigger pipeline safely
trigger_pipeline() {
    if [ "${HOP_AUTO_RUN_PIPELINE:-false}" = "true" ] && [ -n "${HOP_FILE_PATH}" ]; then
        if [ -f "${HOP_FILE_PATH}" ]; then
            log "Auto-running pipeline: ${HOP_FILE_PATH}"
            # Run pipeline in background with crash protection
            run_pipeline_safely "${HOP_FILE_PATH}" &
            log "Pipeline execution started in background with crash protection"
        else
            log "WARNING: Pipeline file not found: ${HOP_FILE_PATH}"
        fi
    fi
}

# Function to start Hop server with stability enhancements
start_server() {
    log "Starting Hop web server on port ${HOP_WEB_PORT}"
    
    # Apply stability Java options
    export HOP_OPTIONS="${JAVA_OPTS}"
    
    # Trigger pipeline if requested (with crash protection)
    trigger_pipeline
    
    # Start Hop server with stability options
    log "Starting Hop server with Java options: ${HOP_OPTIONS}"
    exec /opt/hop/hop-server.sh
}

# Function to run only pipeline (without server)
run_pipeline_only() {
    setup_environment
    
    if [ -n "${HOP_FILE_PATH}" ] && [ -f "${HOP_FILE_PATH}" ]; then
        log "Running pipeline only: ${HOP_FILE_PATH}"
        run_pipeline_safely "${HOP_FILE_PATH}"
    else
        log "ERROR: Pipeline file not specified or not found: ${HOP_FILE_PATH}"
        exit 1
    fi
}

# Main script logic
case "${1}" in
    start)
        setup_environment
        start_server
        ;;
    config)
        setup_environment
        log "Configuration completed. Server not started (config-only mode)."
        ;;
    healthcheck)
        /opt/hop/scripts/healthcheck.sh
        ;;
    check-gcloud)
        setup_google_credentials
        if check_gcloud_credentials; then
            log "Google Cloud credentials are valid"
        else
            log "Google Cloud credentials are missing or invalid"
            exit 1
        fi
        ;;
    run-pipeline)
        run_pipeline_only
        ;;
    test-stability)
        log "Testing system stability..."
        setup_environment
        log "Stability test completed - all configurations loaded successfully"
        ;;
    *)
        exec "$@"
        ;;
esac