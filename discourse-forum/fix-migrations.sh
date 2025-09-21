#!/bin/bash

# Fix Discourse Migration Issues Script
# This script helps resolve common database migration problems

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Fixing Discourse Migration Issues...${NC}"
echo "=============================================="
echo ""

# Check if we're in the right directory
if [ ! -f "docker-compose.local.yml" ]; then
    echo -e "${RED}❌ docker-compose.local.yml not found. Please run this script from the discourse-forum directory.${NC}"
    exit 1
fi

echo -e "${YELLOW}🛑 Stopping all services...${NC}"
docker compose -f docker-compose.local.yml down

echo -e "${YELLOW}🧹 Cleaning up volumes to start fresh...${NC}"
docker compose -f docker-compose.local.yml down -v

echo -e "${YELLOW}🗑️  Removing any existing containers...${NC}"
docker rm -f discourse_local discourse_postgres_local discourse_redis_local 2>/dev/null || true

echo -e "${YELLOW}🧹 Cleaning up Docker system...${NC}"
docker system prune -f

echo -e "${BLUE}🔧 Starting services with fixed configuration...${NC}"
docker compose -f docker-compose.local.yml up -d

echo -e "${YELLOW}⏳ Waiting for PostgreSQL to be ready...${NC}"
sleep 30

# Check if PostgreSQL is ready
echo -e "${BLUE}🔍 Checking PostgreSQL status...${NC}"
if docker compose -f docker-compose.local.yml exec postgres pg_isready -U discourse; then
    echo -e "${GREEN}✅ PostgreSQL is ready${NC}"
else
    echo -e "${RED}❌ PostgreSQL is not ready yet, waiting more...${NC}"
    sleep 30
fi

echo -e "${BLUE}🔍 Checking if vector extension is available...${NC}"
if docker compose -f docker-compose.local.yml exec postgres psql -U discourse -d discourse -c "SELECT * FROM pg_extension WHERE extname = 'vector';" 2>/dev/null | grep -q vector; then
    echo -e "${GREEN}✅ Vector extension is available${NC}"
else
    echo -e "${YELLOW}⚠️  Vector extension not found, this might cause issues${NC}"
fi

echo -e "${YELLOW}⏳ Waiting for Discourse to start (this may take 10-15 minutes)...${NC}"
echo -e "${YELLOW}   The first startup with migrations can take a while${NC}"

# Wait and check logs
sleep 60

echo -e "${BLUE}📊 Checking service status...${NC}"
docker compose -f docker-compose.local.yml ps

echo -e "${BLUE}📋 Recent Discourse logs (last 20 lines):${NC}"
docker compose -f docker-compose.local.yml logs --tail=20 discourse

echo ""
echo -e "${GREEN}🎉 Migration fix attempt completed!${NC}"
echo ""
echo -e "${BLUE}🌐 Access your Discourse server:${NC}"
echo -e "${GREEN}   Main URL: http://localhost:3000${NC}"
echo -e "${GREEN}   Admin Panel: http://localhost:3000/admin${NC}"
echo ""
echo -e "${BLUE}🔍 If you still have issues:${NC}"
echo -e "${YELLOW}   1. Check logs: docker compose -f docker-compose.local.yml logs -f discourse${NC}"
echo -e "${YELLOW}   2. Wait longer - first startup can take 15+ minutes${NC}"
echo -e "${YELLOW}   3. Check database: docker compose -f docker-compose.local.yml exec postgres psql -U discourse -d discourse${NC}"
echo ""
echo -e "${BLUE}📚 Useful commands:${NC}"
echo -e "${GREEN}   View all logs: docker compose -f docker-compose.local.yml logs -f${NC}"
echo -e "${GREEN}   Restart Discourse: docker compose -f docker-compose.local.yml restart discourse${NC}"
echo -e "${GREEN}   Check database: docker compose -f docker-compose.local.yml exec postgres psql -U discourse -d discourse -c '\\l'${NC}"

