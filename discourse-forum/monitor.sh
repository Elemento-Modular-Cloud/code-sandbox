#!/bin/bash

# Discourse Monitoring Script
# Monitors the health and status of Discourse services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Discourse Server Health Check${NC}"
echo "=================================="
echo ""

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose is not installed${NC}"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}❌ docker-compose.yml not found. Please run this script from the discourse-forum directory.${NC}"
    exit 1
fi

echo -e "${BLUE}📊 Service Status:${NC}"
docker-compose ps
echo ""

# Check if services are running
if docker-compose ps | grep -q "Up"; then
    echo -e "${GREEN}✅ Services are running${NC}"
else
    echo -e "${RED}❌ Services are not running${NC}"
    echo "Starting services..."
    docker-compose up -d
    sleep 10
fi

echo ""

# Check service health
echo -e "${BLUE}🏥 Health Checks:${NC}"

# Check Discourse container
if docker-compose exec -T discourse pgrep -f "unicorn" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Discourse application is running${NC}"
else
    echo -e "${RED}❌ Discourse application is not responding${NC}"
fi

# Check PostgreSQL
if docker-compose exec -T postgres pg_isready -U discourse > /dev/null 2>&1; then
    echo -e "${GREEN}✅ PostgreSQL is ready${NC}"
else
    echo -e "${RED}❌ PostgreSQL is not responding${NC}"
fi

# Check Redis
if docker-compose exec -T redis redis-cli -a "$(grep DISCOURSE_REDIS_PASSWORD .env | cut -d'=' -f2)" ping > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Redis is responding${NC}"
else
    echo -e "${RED}❌ Redis is not responding${NC}"
fi

echo ""

# Check resource usage
echo -e "${BLUE}💾 Resource Usage:${NC}"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
echo ""

# Check disk usage
echo -e "${BLUE}💿 Disk Usage:${NC}"
df -h | grep -E "(Filesystem|/dev/)"
echo ""

# Check recent logs for errors
echo -e "${BLUE}📋 Recent Error Logs:${NC}"
echo "Discourse errors (last 10 lines):"
docker-compose logs --tail=10 discourse | grep -i error || echo "No recent errors found"
echo ""

echo "PostgreSQL errors (last 10 lines):"
docker-compose logs --tail=10 postgres | grep -i error || echo "No recent errors found"
echo ""

echo "Redis errors (last 10 lines):"
docker-compose logs --tail=10 redis | grep -i error || echo "No recent errors found"
echo ""

# Check backup status
echo -e "${BLUE}💾 Backup Status:${NC}"
if [ -d "backups" ] && [ "$(ls -A backups 2>/dev/null)" ]; then
    echo "Recent backups:"
    ls -lh backups/discourse_backup_*.tar.gz 2>/dev/null | tail -5 || echo "No backups found"
    
    # Check if backup is recent (within 24 hours)
    LATEST_BACKUP=$(find backups -name "discourse_backup_*.tar.gz" -mtime -1 2>/dev/null | head -1)
    if [ -n "$LATEST_BACKUP" ]; then
        echo -e "${GREEN}✅ Recent backup found: $(basename "$LATEST_BACKUP")${NC}"
    else
        echo -e "${YELLOW}⚠️  No recent backups (older than 24 hours)${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  No backups directory found${NC}"
fi

echo ""

# Check SSL certificate (if configured)
echo -e "${BLUE}🔒 SSL Certificate Status:${NC}"
HOSTNAME=$(grep DISCOURSE_HOSTNAME .env | cut -d'=' -f2 2>/dev/null || echo "not configured")
if [ "$HOSTNAME" != "not configured" ] && [ "$HOSTNAME" != "your-domain.com" ]; then
    if command -v openssl &> /dev/null; then
        echo "Checking SSL certificate for $HOSTNAME..."
        if echo | openssl s_client -servername "$HOSTNAME" -connect "$HOSTNAME:443" 2>/dev/null | openssl x509 -noout -dates; then
            echo -e "${GREEN}✅ SSL certificate is valid${NC}"
        else
            echo -e "${RED}❌ SSL certificate check failed${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  OpenSSL not available for certificate check${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Hostname not configured in .env file${NC}"
fi

echo ""

# Summary
echo -e "${BLUE}📊 Summary:${NC}"
RUNNING_SERVICES=$(docker-compose ps | grep -c "Up" || echo "0")
TOTAL_SERVICES=$(docker-compose ps | grep -c "discourse\|postgres\|redis" || echo "0")

if [ "$RUNNING_SERVICES" -eq "$TOTAL_SERVICES" ]; then
    echo -e "${GREEN}🎉 All services are running properly!${NC}"
else
    echo -e "${RED}⚠️  $RUNNING_SERVICES/$TOTAL_SERVICES services are running${NC}"
fi

echo ""
echo -e "${BLUE}💡 Useful Commands:${NC}"
echo "  View logs: docker-compose logs -f"
echo "  Restart: docker-compose restart"
echo "  Stop: docker-compose down"
echo "  Start: docker-compose up -d"
echo "  Backup: ./backup.sh"
echo "  Update: docker-compose pull && docker-compose up -d"

