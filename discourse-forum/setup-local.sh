#!/bin/bash

# Local Discourse Testing Setup Script
# This script helps you set up Discourse for local testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Setting up Discourse Server for Local Testing...${NC}"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed. Please install Docker first.${NC}"
    echo "Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose is not installed. Please install Docker Compose first.${NC}"
    echo "Visit: https://docs.docker.com/compose/install/"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}❌ Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker and Docker Compose are available${NC}"

# Create .env file from local template if it doesn't exist
if [ ! -f .env ]; then
    echo -e "${YELLOW}📝 Creating .env file from local template...${NC}"
    cp env.local .env
    echo -e "${GREEN}✅ .env file created for local testing${NC}"
fi

echo -e "${BLUE}🔧 Starting Discourse services for local testing...${NC}"

# Start services using local docker-compose file
docker compose -f docker-compose.local.yml up -d

echo -e "${YELLOW}⏳ Waiting for services to start (this may take a few minutes)...${NC}"
echo -e "${YELLOW}   Discourse is starting up - this can take 5-10 minutes on first run${NC}"

# Wait for services to be ready
sleep 30

echo -e "${BLUE}📊 Checking service status...${NC}"
docker compose -f docker-compose.local.yml ps

echo ""
echo -e "${GREEN}🎉 Local Discourse server setup complete!${NC}"
echo ""
echo -e "${BLUE}🌐 Access your local Discourse server:${NC}"
echo -e "${GREEN}   Main URL: http://localhost:3000${NC}"
echo -e "${GREEN}   Admin Panel: http://localhost:3000/admin${NC}"
echo ""
echo -e "${BLUE}📋 Local Testing Information:${NC}"
echo -e "${YELLOW}   • Port 3000: Discourse web interface${NC}"
echo -e "${YELLOW}   • Port 3001: HTTPS (not needed for local testing)${NC}"
echo -e "${YELLOW}   • Port 5433: PostgreSQL database${NC}"
echo -e "${YELLOW}   • Port 6380: Redis cache${NC}"
echo ""
echo -e "${BLUE}🔧 Useful Commands:${NC}"
echo -e "${GREEN}   View logs: docker-compose -f docker-compose.local.yml logs -f${NC}"
echo -e "${GREEN}   Stop services: docker-compose -f docker-compose.local.yml down${NC}"
echo -e "${GREEN}   Restart services: docker-compose -f docker-compose.local.yml restart${NC}"
echo -e "${GREEN}   Update Discourse: docker-compose -f docker-compose.local.yml pull && docker-compose -f docker-compose.local.yml up -d${NC}"
echo ""
echo -e "${BLUE}⚠️  Important Notes:${NC}"
echo -e "${YELLOW}   • This is a LOCAL TESTING setup only${NC}"
echo -e "${YELLOW}   • Email notifications are disabled for local testing${NC}"
echo -e "${YELLOW}   • Use strong passwords in production${NC}"
echo -e "${YELLOW}   • First startup may take 5-10 minutes${NC}"
echo ""
echo -e "${BLUE}🚀 Next Steps:${NC}"
echo -e "${GREEN}   1. Wait for Discourse to fully start (check logs if needed)${NC}"
echo -e "${GREEN}   2. Open http://localhost:3000 in your browser${NC}"
echo -e "${GREEN}   3. Complete the initial setup wizard${NC}"
echo -e "${GREEN}   4. Create your first admin account${NC}"
echo -e "${GREEN}   5. Start customizing for your company!${NC}"
echo ""
echo -e "${BLUE}📚 Documentation: https://docs.discourse.org/${NC}"
echo -e "${BLUE}🔍 Local Testing Guide: COMPANY_SETUP.md${NC}"

