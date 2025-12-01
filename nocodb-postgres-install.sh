#!/usr/bin/env bash

if [ "$1" == '--debug' ]; then
	set -x
fi

set -e

# Constants
NOCO_HOME="/opt/nocodb"
REQUIRED_PORTS=(8081)
state_file="$NOCO_HOME/noco.state"
state_dlim="|"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
ORANGE='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

# Global variables
CONFIG_DOMAIN_NAME=""
CONFIG_SSL_ENABLED=""
CONFIG_EDITION=""
CONFIG_LICENSE_KEY=""
CONFIG_REDIS_ENABLED=""
CONFIG_MINIO_ENABLED=""
CONFIG_MINIO_DOMAIN_NAME=""
CONFIG_MINIO_SSL_ENABLED=""
CONFIG_WATCHTOWER_ENABLED=""
CONFIG_NUM_INSTANCES=""
CONFIG_POSTGRES_PASSWORD=""
CONFIG_POSTGRES_USER=""
CONFIG_POSTGRES_DB=""
CONFIG_REDIS_PASSWORD=""
CONFIG_MINIO_ACCESS_KEY=""
CONFIG_MINIO_ACCESS_SECRET=""
CONFIG_DOCKER_COMMAND=""
CONFIG_NOCODB_PORT=""

declare -a message_arr

# Utility functions
print_color() { printf "${1}%s${NC}\n" "$2"; }
print_info() { print_color "$BLUE" "INFO: $1"; }
print_success() { print_color "$GREEN" "SUCCESS: $1"; }
print_warning() { print_color "$YELLOW" "WARNING: $1"; }
print_error() { print_color "$RED" "ERROR: $1"; }

die() {
	: "${1:?}"
	printf "\033[31;1merr: %b\033[0m\n" "$1"
	exit "${2:-1}"
}

trim() {
	: "${1:?}"
	_trimstr="${1#"${1%%[![:space:]]*}"}"
	_trimstr="${_trimstr%"${_trimstr##*[![:space:]]}"}"
	echo "$_trimstr"
}

kvstore_get() {
	line=
	_key=
	_value=

	[ -s "$state_file" ] || return 1

	while read -r line; do
		[ -z "$line" ] && continue

		_key="${line%%"$state_dlim"*}"
		_key="$(trim "$_key")"

		case "$_key" in
		\#*) continue ;;
		esac

		if [ "$1" = "getval" ]; then
			[ "$2" != "$_key" ] && continue

			_value="${line##*"$state_dlim"}"
			_value="$(trim "$_value")"
			echo "$_value"
			return 0
		else
			echo "$_key"
		fi
	done <"$state_file"

	unset _key _value
	[ "$1" = "getval" ] && return 1
}

kvstore_rm() {
	: "${1:?}"
	cl=
	line=
	file=
	old_ifs="$IFS"

	IFS=
	while read -r line; do
		cl="$line\n"

		key="$(trim "${cl%%"$state_dlim"*}")"
		if [ "$key" = "$1" ]; then
			continue
		fi

		file="${file}${cl}"
	done <"$state_file"

	IFS="$old_ifs"
	printf "$file" >"$state_file"
	unset cl line file value old_ifs
}

kvstore_valverify() {
	case "$1" in
	*"\n"* | *$state_dlim*) return 1 ;;
	esac
}

kvstore_set() {
	: "${1:?}"
	: "${2:?}"

	key="$(echo "$1" | tr -d "$state_dlim")"
	key="$(trim "$key")"
	val="$(trim "$2")"

	kvstore_get getval "$key" >/dev/null &&
		die "keys must be unique"
	kvstore_valverify "$val" ||
		die "invalid: $val"

	echo "${key:?} $state_dlim $val" >>"$state_file"
}

print_box_message() {
	local message=("$@")
	local edge="======================================"
	local padding="  "

	echo "$edge"
	for element in "${message[@]}"; do
		echo "${padding}${element}"
	done
	echo "$edge"
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

is_valid_domain() {
	local domain_regex="^([a-zA-Z0-9]([-a-zA-Z0-9]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([-a-zA-Z0-9]{0,61}[a-zA-Z0-9])?\.[a-zA-Z]{2,}$"
	[[ "$1" =~ $domain_regex ]]
}

urlencode() {
	local string="$1"
	local strlen=${#string}
	local encoded=""
	local pos c o

	for ((pos = 0; pos < strlen; pos++)); do
		c=${string:$pos:1}
		case "$c" in
		[-_.~a-zA-Z0-9]) o="$c" ;;
		*) printf -v o '%%%02X' "'$c" ;;
		esac
		encoded+="$o"
	done
	echo "$encoded"
}

generate_password() {
	if ! pass="$(kvstore_get getval generated_password)"; then
		pass="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 32)"
		kvstore_set generated_password "$pass"
	fi
	echo "$pass"
}

get_public_ip() {
	local ip

	if command -v curl >/dev/null 2>&1; then
		ip="$(curl -s -4 https://ip.me 2>/dev/null)"
		if echo "$ip" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
			echo "$ip"
			return
		fi
	fi

	echo "localhost"
}

get_nproc() {
	if command -v nproc &>/dev/null; then
		nproc
	else
		if [[ -f /proc/cpuinfo ]]; then
			grep -c ^processor /proc/cpuinfo
		else
			echo 1
		fi
	fi
}

prompt() {
	local prompt_text="$1"
	local default_value="$2"
	local response

	if [ -n "$default_value" ]; then
		prompt_text+=" (default: $default_value)"
	fi
	prompt_text+=": "

	read -r -p "$prompt_text" response
	if [ -z "$response" ] && [ -n "$default_value" ]; then
		echo "$default_value"
	else
		echo "$response"
	fi
}

prompt_oneof() {
	local response
	local resp_upper
	local oneof_text
	local prompt_text="$1"
	local default_response="$2"
	shift 2

	prompt_text+=" (default: $default_response) "
	oneof_text+="["
	for one in "$@"; do
		oneof_text+="$one,"
	done
	oneof_text="${oneof_text%%,}]"
	prompt_text+="${oneof_text}: "

	while true; do
		read -r -p "$prompt_text" response
		if [ -z "$response" ]; then
			echo "$default_response"
			return
		fi

		for one in "$@"; do
			resp_upper="$(echo "$response" | tr '[:lower:]' '[:upper:]')"
			one_upper="$(echo "$one" | tr '[:lower:]' '[:upper:]')"
			if [ "$resp_upper" = "$one_upper" ]; then
				echo "$one"
				return
			fi
		done
		print_error "This field should be one of ${oneof_text}."
	done
}

prompt_required() {
	local prompt_text="$1"
	local response

	while true; do
		read -r -p "$prompt_text: " response
		if [ -n "$response" ]; then
			echo "$response"
			return
		fi
		print_error "This field is required."
	done
}

confirm() {
	local prompt_text="$1"
	local default_response="${2:-N}"
	local secondary_response
	local response
	case "$default_response" in
	"Y") secondary_response="N" ;;
	"N") secondary_response="Y" ;;
	esac

	response="$(prompt_oneof "$prompt_text" "$default_response" "$secondary_response")"
	if [ "$response" = "Y" ]; then
		return 0
	elif [ "$response" = "N" ]; then
		return 1
	fi
}

is_ip() {
	local input="$1"
	[[ "$input" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

install_package() {
	if command_exists apt; then
		apt update && apt install -y "$1"
	elif command_exists yum; then
		yum install -y "$1"
	else
		print_error "Package manager not found. Please install $1 manually."
		exit 1
	fi
}

check_for_docker_sudo() {
	if docker ps >/dev/null 2>&1; then
		echo "n"
	else
		echo "y"
	fi
}

print_empty_line() {
	local count=${1:-1}
	for ((i = 0; i < count; i++)); do
		echo
	done
}

check_if_docker_is_running() {
	if ! $CONFIG_DOCKER_COMMAND ps >/dev/null 2>&1; then
		print_warning "Docker is not running."
		exit 1
	fi
}

check_existing_installation() {
	mkdir -p "$NOCO_HOME"

	if [ -f "$NOCO_HOME/docker-compose.yml" ]; then
		print_info "NocoDB is already installed at $NOCO_HOME"
		if confirm "Do you want to reinstall/reconfigure NocoDB" "N"; then
			cd "$NOCO_HOME" || exit 1
			$CONFIG_DOCKER_COMMAND compose down
		else
			exit 0
		fi
	fi
}

check_system_requirements() {
	print_info "Performing NocoDB system check and setup"

	for tool in docker wget lsof; do
		if ! command_exists "$tool"; then
			print_warning "$tool is not installed."
			if [ "$tool" = "docker" ]; then
				wget -qO- https://get.docker.com/ | sh
			else
				install_package "$tool"
			fi
		fi
	done

	for port in "${REQUIRED_PORTS[@]}"; do
		if lsof -Pi :"$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
			print_warning "Port $port is in use. Please choose a different port or free this port."
		fi
	done

	print_success "System check completed successfully"
}

get_user_inputs() {
	clear || :
	cat <<EOF
╔════════════════════════════════════════╗
║   NocoDB PostgreSQL Setup Assistant    ║
╚════════════════════════════════════════╝
EOF
	print_empty_line
	echo -e "${BOLD}Starting configuration...${NC}"
	print_empty_line

	# Port Configuration
	CONFIG_NOCODB_PORT=$(prompt "Enter the port for NocoDB" "8081")
	print_empty_line

	# Database Configuration
	echo -e "${BOLD}PostgreSQL Database Configuration...${NC}"
	print_empty_line
	CONFIG_POSTGRES_DB=$(prompt "Enter PostgreSQL database name" "nocodb")
	CONFIG_POSTGRES_USER=$(prompt "Enter PostgreSQL username" "nocodb")
	CONFIG_POSTGRES_PASSWORD=$(prompt "Enter PostgreSQL password" "nocodb_secret_2024")
	print_empty_line

	# Domain Configuration
	CONFIG_DOMAIN_NAME=$(prompt "Enter the domain name for NocoDB (or press Enter to skip)" "")

	if [ -n "$CONFIG_DOMAIN_NAME" ]; then
		print_empty_line
		CONFIG_SSL_ENABLED=$(prompt_oneof "Configure with SSL" "N" "Y")
		print_empty_line
	else
		CONFIG_SSL_ENABLED="N"
	fi

	# Redis Configuration
	CONFIG_REDIS_ENABLED=$(prompt_oneof "Enable Redis for caching" "Y" "N")
	print_empty_line

	# MinIO Configuration
	CONFIG_MINIO_ENABLED=$(prompt_oneof "Enable MinIO for file storage" "Y" "N")
	print_empty_line

	# Watchtower
	CONFIG_WATCHTOWER_ENABLED=$(prompt_oneof "Enable Watchtower for automatic updates" "Y" "N")
	print_empty_line

	# Number of instances
	CONFIG_NUM_INSTANCES=1

	print_empty_line
	cat <<EOF
╔════════════════════════════════════════╗
║         Configuration Summary          ║
╚════════════════════════════════════════╝
EOF
	print_empty_line
	echo -e "${BOLD}NocoDB Port:${NC} $CONFIG_NOCODB_PORT"
	echo -e "${BOLD}PostgreSQL Database:${NC} $CONFIG_POSTGRES_DB"
	echo -e "${BOLD}PostgreSQL User:${NC} $CONFIG_POSTGRES_USER"
	if [ -n "$CONFIG_DOMAIN_NAME" ]; then
		echo -e "${BOLD}Domain:${NC} $CONFIG_DOMAIN_NAME"
		echo -e "${BOLD}SSL:${NC} $CONFIG_SSL_ENABLED"
	fi
	echo -e "${BOLD}Redis:${NC} $CONFIG_REDIS_ENABLED"
	echo -e "${BOLD}MinIO:${NC} $CONFIG_MINIO_ENABLED"
	print_empty_line
}

generate_credentials() {
	if [ "$CONFIG_REDIS_ENABLED" = "Y" ]; then
		CONFIG_REDIS_PASSWORD=$(generate_password)
	fi
	if [ "$CONFIG_MINIO_ENABLED" = "Y" ]; then
		CONFIG_MINIO_ACCESS_KEY=$(generate_password)
		CONFIG_MINIO_ACCESS_SECRET=$(generate_password)
	fi
}

create_docker_compose_file() {
	local compose_file="$NOCO_HOME/docker-compose.yml"
	local image="nocodb/nocodb:latest"

	cat >"$compose_file" <<EOF
services:
  nocodb-db:
    image: postgres:15
    container_name: nocodb-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${CONFIG_POSTGRES_DB}
      POSTGRES_USER: ${CONFIG_POSTGRES_USER}
      POSTGRES_PASSWORD: ${CONFIG_POSTGRES_PASSWORD}
    volumes:
      - nocodb_postgres_data:/var/lib/postgresql/data
    networks:
      - nocodb-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${CONFIG_POSTGRES_USER} -d ${CONFIG_POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5

  nocodb:
    image: ${image}
    container_name: nocodb
    restart: unless-stopped
    ports:
      - "${CONFIG_NOCODB_PORT}:8080"
    env_file: docker.env
    depends_on:
      nocodb-db:
        condition: service_healthy
EOF

	if [ "$CONFIG_REDIS_ENABLED" = "Y" ]; then
		cat >>"$compose_file" <<EOF
      - redis
EOF
	fi

	if [ "$CONFIG_MINIO_ENABLED" = "Y" ]; then
		cat >>"$compose_file" <<EOF
      - minio
EOF
	fi

	cat >>"$compose_file" <<EOF
    volumes:
      - nocodb_data:/usr/app/data
    networks:
      - nocodb-network
EOF

	if [ "$CONFIG_REDIS_ENABLED" = "Y" ]; then
		cat >>"$compose_file" <<EOF

  redis:
    image: redis:latest
    container_name: nocodb-redis
    restart: unless-stopped
    command: redis-server --requirepass "${CONFIG_REDIS_PASSWORD}"
    volumes:
      - redis_data:/data
    networks:
      - nocodb-network
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${CONFIG_REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
EOF
	fi

	if [ "$CONFIG_MINIO_ENABLED" = "Y" ]; then
		cat >>"$compose_file" <<EOF

  minio:
    image: minio/minio:latest
    container_name: nocodb-minio
    restart: unless-stopped
    environment:
      MINIO_ROOT_USER: ${CONFIG_MINIO_ACCESS_KEY}
      MINIO_ROOT_PASSWORD: ${CONFIG_MINIO_ACCESS_SECRET}
    command: server /data --console-address ":9001"
    volumes:
      - minio_data:/data
    ports:
      - "9000:9000"
      - "9001:9001"
    networks:
      - nocodb-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3
EOF
	fi

	if [ "$CONFIG_WATCHTOWER_ENABLED" = "Y" ]; then
		cat >>"$compose_file" <<EOF

  watchtower:
    image: containrrr/watchtower
    container_name: nocodb-watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --schedule "0 2 * * 6" --cleanup
    restart: unless-stopped
    networks:
      - nocodb-network
EOF
	fi

	cat >>"$compose_file" <<EOF

volumes:
  nocodb_postgres_data:
  nocodb_data:
EOF

	if [ "$CONFIG_REDIS_ENABLED" = "Y" ]; then
		cat >>"$compose_file" <<EOF
  redis_data:
EOF
	fi

	if [ "$CONFIG_MINIO_ENABLED" = "Y" ]; then
		cat >>"$compose_file" <<EOF
  minio_data:
EOF
	fi

	cat >>"$compose_file" <<EOF

networks:
  nocodb-network:
    driver: bridge
EOF

	print_success "Docker Compose file created at $compose_file"
}

create_env_file() {
	local env_file="$NOCO_HOME/docker.env"
	local encoded_password
	encoded_password=$(urlencode "${CONFIG_POSTGRES_PASSWORD}")

	cat >"$env_file" <<EOF
# PostgreSQL Configuration
NC_DB=pg://nocodb-db:5432?u=${CONFIG_POSTGRES_USER}&p=${encoded_password}&d=${CONFIG_POSTGRES_DB}
EOF

	if [ -n "$CONFIG_DOMAIN_NAME" ]; then
		if [ "$CONFIG_SSL_ENABLED" = "Y" ]; then
			echo "NC_PUBLIC_URL=https://${CONFIG_DOMAIN_NAME}" >>"$env_file"
		else
			echo "NC_PUBLIC_URL=http://${CONFIG_DOMAIN_NAME}" >>"$env_file"
		fi
	fi

	if [ "$CONFIG_REDIS_ENABLED" = "Y" ]; then
		local encoded_redis_password
		encoded_redis_password=$(urlencode "${CONFIG_REDIS_PASSWORD}")
		cat >>"$env_file" <<EOF

# Redis Configuration
NC_REDIS_URL=redis://:${encoded_redis_password}@redis:6379/0
EOF
	fi

	if [ "$CONFIG_MINIO_ENABLED" = "Y" ]; then
		cat >>"$env_file" <<EOF

# MinIO Configuration
NC_S3_BUCKET_NAME=nocodb
NC_S3_REGION=us-east-1
NC_S3_ACCESS_KEY=${CONFIG_MINIO_ACCESS_KEY}
NC_S3_ACCESS_SECRET=${CONFIG_MINIO_ACCESS_SECRET}
NC_S3_ENDPOINT=http://minio:9000
NC_S3_FORCE_PATH_STYLE=true
EOF
	fi

	print_success "Environment file created at $env_file"
}

create_management_scripts() {
	# Update script
	cat >"$NOCO_HOME/update.sh" <<EOF
#!/bin/bash
cd "$NOCO_HOME" || exit 1
$CONFIG_DOCKER_COMMAND compose pull
$CONFIG_DOCKER_COMMAND compose up -d --force-recreate
$CONFIG_DOCKER_COMMAND image prune -a -f
EOF
	chmod +x "$NOCO_HOME/update.sh"

	# Start script
	cat >"$NOCO_HOME/start.sh" <<EOF
#!/bin/bash
cd "$NOCO_HOME" || exit 1
$CONFIG_DOCKER_COMMAND compose up -d
EOF
	chmod +x "$NOCO_HOME/start.sh"

	# Stop script
	cat >"$NOCO_HOME/stop.sh" <<EOF
#!/bin/bash
cd "$NOCO_HOME" || exit 1
$CONFIG_DOCKER_COMMAND compose down
EOF
	chmod +x "$NOCO_HOME/stop.sh"

	# Restart script
	cat >"$NOCO_HOME/restart.sh" <<EOF
#!/bin/bash
cd "$NOCO_HOME" || exit 1
$CONFIG_DOCKER_COMMAND compose restart
EOF
	chmod +x "$NOCO_HOME/restart.sh"

	# Logs script
	cat >"$NOCO_HOME/logs.sh" <<EOF
#!/bin/bash
cd "$NOCO_HOME" || exit 1
$CONFIG_DOCKER_COMMAND compose logs -f
EOF
	chmod +x "$NOCO_HOME/logs.sh"

	message_arr+=("Management scripts created in $NOCO_HOME/")
	message_arr+=("  - start.sh: Start services")
	message_arr+=("  - stop.sh: Stop services")
	message_arr+=("  - restart.sh: Restart services")
	message_arr+=("  - update.sh: Update to latest version")
	message_arr+=("  - logs.sh: View logs")
}

start_services() {
	cd "$NOCO_HOME" || exit 1
	print_info "Pulling Docker images..."
	$CONFIG_DOCKER_COMMAND compose pull
	print_info "Starting services..."
	$CONFIG_DOCKER_COMMAND compose up -d
	print_empty_line
	print_success "Services started successfully!"
	print_empty_line
	sleep 3
}

display_completion_message() {
	if [ -n "$CONFIG_DOMAIN_NAME" ]; then
		if [ "$CONFIG_SSL_ENABLED" = "Y" ]; then
			message_arr+=("NocoDB is available at: https://${CONFIG_DOMAIN_NAME}")
		else
			message_arr+=("NocoDB is available at: http://${CONFIG_DOMAIN_NAME}")
		fi
	else
		message_arr+=("NocoDB is available at: http://localhost:${CONFIG_NOCODB_PORT}")
		message_arr+=("  or http://$(get_public_ip):${CONFIG_NOCODB_PORT}")
	fi

	if [ "$CONFIG_MINIO_ENABLED" = "Y" ]; then
		message_arr+=("")
		message_arr+=("MinIO Console: http://localhost:9001")
		message_arr+=("  Username: ${CONFIG_MINIO_ACCESS_KEY}")
		message_arr+=("  Password: ${CONFIG_MINIO_ACCESS_SECRET}")
	fi

	message_arr+=("")
	message_arr+=("Installation directory: $NOCO_HOME")

	print_empty_line
	print_box_message "${message_arr[@]}"
	print_empty_line
}

main() {
	CONFIG_DOCKER_COMMAND=$([ "$(check_for_docker_sudo)" = "y" ] && echo "sudo docker" || echo "docker")

	check_if_docker_is_running
	check_existing_installation
	check_system_requirements
	get_user_inputs
	generate_credentials
	create_docker_compose_file
	create_env_file
	create_management_scripts
	start_services
	display_completion_message

	print_success "NocoDB installation completed!"
}

main "$@"
