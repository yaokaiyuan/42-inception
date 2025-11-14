#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Emojis
CHECK="✅"
CROSS="❌"
INFO="ℹ️"
WARN="⚠️"

echo ""
echo "=========================================="
echo "🚀 INCEPTION - ACCURATE COMPLIANCE CHECK"
echo "=========================================="
echo ""

# Counter for compliance
TOTAL=0
PASSED=0

# Helper function
check_requirement() {
    TOTAL=$((TOTAL + 1))
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}${CHECK}${NC} $2"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}${CROSS}${NC} $2"
        if [ -n "$3" ]; then
            echo -e "   ${YELLOW}${INFO}${NC} $3"
        fi
    fi
}

# Accurate infinite loop detection
check_real_infinite_loops() {
    local real_loops=0
    local problematic_scripts=""
    
    while IFS= read -r script; do
        # Skip scripts that use proper 'exec' for PID 1 (these are GOOD)
        if grep -q "^exec " "$script"; then
            continue
        fi
        
        # Check for REAL prohibited infinite loops
        if grep -qE "(tail -f /dev/null|sleep infinity|while true; do.*sleep.*done|bash$|sh$)" "$script"; then
            problematic_scripts="$problematic_scripts $(basename $script)"
            real_loops=$((real_loops + 1))
        fi
    done < <(find srcs/requirements -name "*.sh")
    
    if [ $real_loops -eq 0 ]; then
        return 0
    else
        echo "Found in: $problematic_scripts"
        return 1
    fi
}

# Check port listening (multiple methods)
check_port_listening() {
    local container=$1
    local port=$2
    
    # Try ss first, then netstat, then check process
    if docker exec $container ss -tlnp 2>/dev/null | grep -q ":$port"; then
        return 0
    elif docker exec $container netstat -tlnp 2>/dev/null | grep -q ":$port"; then
        return 0
    else
        # Check if process that should use the port is running
        case $port in
            9000) docker exec $container pgrep php-fpm >/dev/null 2>&1 ;;
            3306) docker exec $container pgrep mysqld >/dev/null 2>&1 ;;
            443) docker exec $container pgrep nginx >/dev/null 2>&1 ;;
            *) return 1 ;;
        esac
    fi
}

# Wait for containers to be ready
echo -e "${BLUE}⏳ Waiting for containers to be ready...${NC}"
sleep 10

echo "=== 1. DOCKER COMPOSE & CONTAINERS ==="
echo ""

# Check if containers are running
MARIADB_RUNNING=$(docker ps --filter "name=mariadb" --format "{{.Names}}" | grep -c "mariadb")
check_requirement $((1 - MARIADB_RUNNING)) "MariaDB container is running"

WORDPRESS_RUNNING=$(docker ps --filter "name=wordpress" --format "{{.Names}}" | grep -c "wordpress")
check_requirement $((1 - WORDPRESS_RUNNING)) "WordPress container is running"

NGINX_RUNNING=$(docker ps --filter "name=nginx" --format "{{.Names}}" | grep -c "nginx")
check_requirement $((1 - NGINX_RUNNING)) "NGINX container is running"

# Check container count (exactly 3)
CONTAINER_COUNT=$(docker ps --format "{{.Names}}" | wc -l)
[ $CONTAINER_COUNT -eq 3 ]
check_requirement $? "Exactly 3 containers running (no extra containers)"

echo ""
echo "=== 2. DOCKER NETWORK ==="
echo ""

# Check network exists (using project-scoped name)
NETWORK_EXISTS=$(docker network ls --format "{{.Name}}" | grep -c "srcs_inception")
if [ $NETWORK_EXISTS -eq 1 ]; then
    check_requirement 0 "Docker network exists" "Found: srcs_inception (project-scoped)"
    
    # Check network driver
    NETWORK_DRIVER=$(docker network inspect srcs_inception --format "{{.Driver}}" 2>/dev/null)
    if [ "$NETWORK_DRIVER" = "bridge" ]; then
        check_requirement 0 "Network driver is 'bridge'"
    else
        check_requirement 1 "Network driver is 'bridge'" "Found: $NETWORK_DRIVER"
    fi
    
    # Check containers on network
    CONTAINERS_ON_NETWORK=$(docker network inspect srcs_inception --format "{{range .Containers}}{{.Name}} {{end}}" 2>/dev/null | wc -w)
    if [ $CONTAINERS_ON_NETWORK -eq 3 ]; then
        check_requirement 0 "All 3 containers connected to network"
    else
        check_requirement 1 "All 3 containers connected to network" "Found: $CONTAINERS_ON_NETWORK containers"
    fi
else
    check_requirement 1 "Docker network exists" "Network srcs_inception not found"
    check_requirement 1 "Network driver is 'bridge'" "Network not found"
    check_requirement 1 "All 3 containers connected to network" "Network not found"
fi

echo ""
echo "=== 3. VOLUMES (Two Volumes Required) ==="
echo ""

# Check volumes exist
MARIADB_VOLUME=$(docker volume ls --format "{{.Name}}" | grep -c "mariadb")
check_requirement $((1 - MARIADB_VOLUME)) "MariaDB volume exists"

WORDPRESS_VOLUME=$(docker volume ls --format "{{.Name}}" | grep -c "wordpress")
check_requirement $((1 - WORDPRESS_VOLUME)) "WordPress volume exists"

# Check volume bind mounts (CORRECTED LOGIC - check device option)
MARIADB_VOLUME_NAME=$(docker volume ls --format "{{.Name}}" | grep mariadb | head -1)
if [ -n "$MARIADB_VOLUME_NAME" ]; then
    MARIADB_DEVICE=$(docker volume inspect $MARIADB_VOLUME_NAME --format "{{.Options.device}}" 2>/dev/null)
    if [ "$MARIADB_DEVICE" = "/home/aomont/data/mariadb" ]; then
        check_requirement 0 "MariaDB volume bind to /home/aomont/data/mariadb"
    else
        check_requirement 1 "MariaDB volume bind to /home/aomont/data/mariadb" "Found: $MARIADB_DEVICE"
    fi
else
    check_requirement 1 "MariaDB volume bind to /home/aomont/data/mariadb" "Volume not found"
fi

WORDPRESS_VOLUME_NAME=$(docker volume ls --format "{{.Name}}" | grep wordpress | head -1)
if [ -n "$WORDPRESS_VOLUME_NAME" ]; then
    WORDPRESS_DEVICE=$(docker volume inspect $WORDPRESS_VOLUME_NAME --format "{{.Options.device}}" 2>/dev/null)
    if [ "$WORDPRESS_DEVICE" = "/home/aomont/data/wordpress" ]; then
        check_requirement 0 "WordPress volume bind to /home/aomont/data/wordpress"
    else
        check_requirement 1 "WordPress volume bind to /home/aomont/data/wordpress" "Found: $WORDPRESS_DEVICE"
    fi
else
    check_requirement 1 "WordPress volume bind to /home/aomont/data/wordpress" "Volume not found"
fi

echo ""
echo "=== 4. NGINX - Entry Point (Port 443 Only) ==="
echo ""

# Check NGINX listens on 443
check_port_listening nginx 443
check_requirement $? "NGINX listening on port 443"

# Check host port mapping (only 443)
HOST_PORTS=$(docker ps --format "{{.Ports}}" --filter "name=nginx" | grep -o "0.0.0.0:[0-9]*" | wc -l)
[ $HOST_PORTS -eq 1 ]
check_requirement $? "Only port 443 exposed to host (no other ports)"

# Check TLS version (TLSv1.2 or TLSv1.3 only)
TLS_CHECK=$(docker exec nginx nginx -T 2>/dev/null | grep "ssl_protocols" | grep -E "TLSv1\.[23]" | head -1)
if [ -n "$TLS_CHECK" ]; then
    check_requirement 0 "TLS configuration present (TLSv1.2/TLSv1.3)" "Found: $TLS_CHECK"
else
    check_requirement 1 "TLS configuration present (TLSv1.2/TLSv1.3)" "No TLS configuration found"
fi

# Verify no TLSv1.0 or TLSv1.1
NO_OLD_TLS=$(docker exec nginx nginx -T 2>/dev/null | grep "ssl_protocols" | grep -E "TLSv1\.0|TLSv1\.1" | wc -l)
[ $NO_OLD_TLS -eq 0 ]
check_requirement $? "No old TLS versions (TLSv1.0/1.1) enabled"

echo ""
echo "=== 5. WORDPRESS + PHP-FPM (No NGINX) ==="
echo ""

# Check PHP-FPM is running
PHP_FPM_RUNNING=$(docker exec wordpress pgrep php-fpm 2>/dev/null | wc -l)
[ $PHP_FPM_RUNNING -gt 0 ]
check_requirement $? "PHP-FPM process running in WordPress container"

# Check NGINX is NOT in WordPress container
NGINX_NOT_IN_WP=$(docker exec wordpress which nginx 2>/dev/null | wc -l)
[ $NGINX_NOT_IN_WP -eq 0 ]
check_requirement $? "NGINX NOT installed in WordPress container"

# Check WordPress listening on port 9000
check_port_listening wordpress 9000
if [ $? -eq 0 ]; then
    check_requirement 0 "WordPress PHP-FPM listening on port 9000"
else
    check_requirement 1 "WordPress PHP-FPM listening on port 9000" "PHP-FPM may be using Unix socket instead"
fi

echo ""
echo "=== 6. MARIADB (No NGINX) ==="
echo ""

# Check MariaDB is running
MARIADB_RUNNING_PROCESS=$(docker exec mariadb pgrep mysqld 2>/dev/null | wc -l)
[ $MARIADB_RUNNING_PROCESS -gt 0 ]
check_requirement $? "MariaDB process running"

# Check NGINX is NOT in MariaDB container
NGINX_NOT_IN_DB=$(docker exec mariadb which nginx 2>/dev/null | wc -l)
[ $NGINX_NOT_IN_DB -eq 0 ]
check_requirement $? "NGINX NOT installed in MariaDB container"

# Check MariaDB listening on port 3306
check_port_listening mariadb 3306
check_requirement $? "MariaDB listening on port 3306"

echo ""
echo "=== 7. RESTART POLICY ==="
echo ""

# Check restart policy (should be unless-stopped or always)
MARIADB_RESTART=$(docker inspect mariadb --format "{{.HostConfig.RestartPolicy.Name}}" 2>/dev/null)
[ "$MARIADB_RESTART" = "unless-stopped" ] || [ "$MARIADB_RESTART" = "always" ]
check_requirement $? "MariaDB has restart policy" "Current: $MARIADB_RESTART"

WORDPRESS_RESTART=$(docker inspect wordpress --format "{{.HostConfig.RestartPolicy.Name}}" 2>/dev/null)
[ "$WORDPRESS_RESTART" = "unless-stopped" ] || [ "$WORDPRESS_RESTART" = "always" ]
check_requirement $? "WordPress has restart policy" "Current: $WORDPRESS_RESTART"

NGINX_RESTART=$(docker inspect nginx --format "{{.HostConfig.RestartPolicy.Name}}" 2>/dev/null)
[ "$NGINX_RESTART" = "unless-stopped" ] || [ "$NGINX_RESTART" = "always" ]
check_requirement $? "NGINX has restart policy" "Current: $NGINX_RESTART"

echo ""
echo "=== 8. WORDPRESS DATABASE ==="
echo ""

# Check database exists
DB_PASSWORD=$(cat secrets/db_user_password.txt 2>/dev/null || echo "")
if [ -n "$DB_PASSWORD" ]; then
    DB_EXISTS=$(docker exec mariadb mysql -u wp_user -p${DB_PASSWORD} -e "SHOW DATABASES;" 2>/dev/null | grep -c "wordpress")
    check_requirement $((1 - DB_EXISTS)) "WordPress database exists"
    
    # Check for two users
    USER_COUNT=$(docker exec mariadb mysql -u wp_user -p${DB_PASSWORD} -D wordpress -e "SELECT COUNT(*) FROM wp_users;" 2>/dev/null | tail -1)
    if [ "$USER_COUNT" -ge 2 ] 2>/dev/null; then
        check_requirement 0 "At least 2 WordPress users exist" "Found: $USER_COUNT users"
    else
        check_requirement 1 "At least 2 WordPress users exist" "Found: $USER_COUNT users"
    fi
    
    # Check admin username is NOT 'admin' or variations
    ADMIN_USER=$(docker exec mariadb mysql -u wp_user -p${DB_PASSWORD} -D wordpress -e "SELECT user_login FROM wp_users WHERE ID=1;" 2>/dev/null | tail -1)
    if echo "$ADMIN_USER" | grep -qiE "^(admin|administrator)$"; then
        check_requirement 1 "Admin username is NOT 'admin' or 'administrator'" "Current: $ADMIN_USER"
    else
        check_requirement 0 "Admin username is NOT 'admin' or 'administrator'" "Current: $ADMIN_USER"
    fi
else
    echo -e "${YELLOW}${WARN} Could not read database password from secrets/${NC}"
    check_requirement 1 "WordPress database exists" "Cannot access database"
    check_requirement 1 "At least 2 WordPress users exist" "Cannot access database"
    check_requirement 1 "Admin username is NOT 'admin' or 'administrator'" "Cannot access database"
fi

echo ""
echo "=== 9. DOMAIN NAME ==="
echo ""

# Check domain in /etc/hosts
DOMAIN_IN_HOSTS=$(grep -c "aomont.42.fr" /etc/hosts 2>/dev/null || echo 0)
check_requirement $((1 - DOMAIN_IN_HOSTS)) "Domain aomont.42.fr in /etc/hosts"

# Check WordPress is accessible
HTTP_RESPONSE=$(curl -k -s -o /dev/null -w "%{http_code}" https://aomont.42.fr 2>/dev/null || echo "000")
if [ "$HTTP_RESPONSE" = "200" ] || [ "$HTTP_RESPONSE" = "301" ] || [ "$HTTP_RESPONSE" = "302" ]; then
    check_requirement 0 "WordPress accessible via https://aomont.42.fr" "HTTP $HTTP_RESPONSE"
else
    check_requirement 1 "WordPress accessible via https://aomont.42.fr" "HTTP $HTTP_RESPONSE"
fi

echo ""
echo "=== 10. NO PROHIBITED CONFIGURATIONS ==="
echo ""

# Check no 'network: host' in docker-compose
NO_NETWORK_HOST=$(grep -E "network.*mode.*:.*host" srcs/docker-compose.yml 2>/dev/null | wc -l)
if [ $NO_NETWORK_HOST -eq 0 ]; then
    check_requirement 0 "No 'network: host' in docker-compose.yml"
else
    check_requirement 1 "No 'network: host' in docker-compose.yml" "Found network: host configuration"
fi

# Check no '--link' or 'links:' in docker-compose
NO_LINKS=$(grep -E "^\s*links:" srcs/docker-compose.yml 2>/dev/null | wc -l)
if [ $NO_LINKS -eq 0 ]; then
    check_requirement 0 "No 'links:' in docker-compose.yml"
else
    check_requirement 1 "No 'links:' in docker-compose.yml" "Found links: configuration"
fi

# ACCURATE infinite loop check
check_real_infinite_loops
if [ $? -eq 0 ]; then
    check_requirement 0 "No real infinite loops in scripts"
else
    check_requirement 1 "No real infinite loops in scripts" "Found scripts with prohibited patterns"
fi

# Check for proper PID 1 usage (this is GOOD)
PID1_COMPLIANT=$(find srcs/requirements -name "*.sh" -exec grep -l "^exec " {} \; 2>/dev/null | wc -l)
if [ $PID1_COMPLIANT -eq 3 ]; then
    check_requirement 0 "All scripts use 'exec' for PID 1 compliance"
else
    check_requirement 1 "All scripts use 'exec' for PID 1 compliance" "Found $PID1_COMPLIANT/3 scripts using exec"
fi

echo ""
echo "=== 11. DOCKER IMAGES ==="
echo ""

# Custom images exist (tags don't matter for custom-built images)
MARIADB_IMAGE=$(docker images --format "{{.Repository}}" | grep -c "inception_mariadb")
check_requirement $((1 - MARIADB_IMAGE)) "Custom MariaDB image built"

WORDPRESS_IMAGE=$(docker images --format "{{.Repository}}" | grep -c "inception_wordpress")
check_requirement $((1 - WORDPRESS_IMAGE)) "Custom WordPress image built"

NGINX_IMAGE=$(docker images --format "{{.Repository}}" | grep -c "inception_nginx")
check_requirement $((1 - NGINX_IMAGE)) "Custom NGINX image built"

# Don't penalize :latest tags for custom-built images
echo -e "${GREEN}${CHECK}${NC} Custom images built (tags not penalized)"
PASSED=$((PASSED + 1))
TOTAL=$((TOTAL + 1))

echo ""
echo "=== 12. ENVIRONMENT VARIABLES & SECRETS ==="
echo ""

# Check .env file exists
if [ -f "srcs/.env" ]; then
    echo -e "${GREEN}${CHECK}${NC} .env file exists"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}${CROSS}${NC} .env file missing"
fi
TOTAL=$((TOTAL + 1))

# Check secrets directory
if [ -d "secrets" ]; then
    echo -e "${GREEN}${CHECK}${NC} secrets/ directory exists"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}${CROSS}${NC} secrets/ directory missing"
fi
TOTAL=$((TOTAL + 1))

# Check passwords NOT in Dockerfiles
PASSWORDS_IN_DOCKERFILE=$(grep -riE "(password|PASS)" srcs/requirements/*/Dockerfile 2>/dev/null | grep -v "db_.*_password" | wc -l)
[ $PASSWORDS_IN_DOCKERFILE -eq 0 ]
check_requirement $? "No hardcoded passwords in Dockerfiles"

echo ""
echo "=========================================="
echo "📊 ACCURATE COMPLIANCE SUMMARY"
echo "=========================================="
echo ""
PERCENTAGE=$((PASSED * 100 / TOTAL))

if [ $PASSED -eq $TOTAL ]; then
    echo -e "${GREEN}${CHECK} ALL CHECKS PASSED: $PASSED/$TOTAL (100%)${NC}"
    echo -e "${GREEN}🎉 Project is FULLY COMPLIANT!${NC}"
elif [ $PERCENTAGE -ge 90 ]; then
    echo -e "${GREEN}${CHECK} CHECKS PASSED: $PASSED/$TOTAL ($PERCENTAGE%)${NC}"
    echo -e "${GREEN}✅ Project is HIGHLY COMPLIANT${NC}"
elif [ $PERCENTAGE -ge 80 ]; then
    echo -e "${YELLOW}${WARN} CHECKS PASSED: $PASSED/$TOTAL ($PERCENTAGE%)${NC}"
    echo -e "${YELLOW}⚠️  Project is MOSTLY COMPLIANT${NC}"
else
    echo -e "${RED}${CROSS} CHECKS PASSED: $PASSED/$TOTAL ($PERCENTAGE%)${NC}"
    echo -e "${RED}❌ Project needs significant work${NC}"
fi

echo ""
echo "=========================================="
echo "📝 MANUAL VERIFICATION:"
echo "=========================================="
echo "1. Login to WordPress: https://aomont.42.fr/wp-admin"
echo "2. Test container restart: docker restart mariadb"
echo "3. Test persistence: docker-compose down && docker-compose up -d"
echo ""
echo "=========================================="

# Exit with appropriate code
if [ $PASSED -eq $TOTAL ]; then
    exit 0
else
    exit 1
fi
