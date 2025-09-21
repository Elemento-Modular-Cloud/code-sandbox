#!/bin/bash

# Discourse Backup Script
# Automates database and file backups

set -e

# Configuration
BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="discourse_backup_$DATE"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔄 Starting Discourse backup...${NC}"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Check if services are running
if ! docker-compose ps | grep -q "Up"; then
    echo -e "${RED}❌ Discourse services are not running. Please start them first.${NC}"
    exit 1
fi

echo -e "${YELLOW}📊 Creating database backup...${NC}"

# Database backup
docker-compose exec -T postgres pg_dump -U discourse discourse > "$BACKUP_DIR/${BACKUP_NAME}_database.sql"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Database backup completed: ${BACKUP_NAME}_database.sql${NC}"
else
    echo -e "${RED}❌ Database backup failed${NC}"
    exit 1
fi

echo -e "${YELLOW}📁 Creating file uploads backup...${NC}"

# File uploads backup
docker cp discourse:/var/discourse/shared/standalone/uploads "$BACKUP_DIR/${BACKUP_NAME}_uploads"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ File uploads backup completed: ${BACKUP_NAME}_uploads${NC}"
else
    echo -e "${RED}❌ File uploads backup failed${NC}"
fi

echo -e "${YELLOW}📁 Creating configuration backup...${NC}"

# Configuration backup
docker cp discourse:/var/discourse/shared/standalone/config "$BACKUP_DIR/${BACKUP_NAME}_config"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Configuration backup completed: ${BACKUP_NAME}_config${NC}"
else
    echo -e "${RED}❌ Configuration backup failed${NC}"
fi

# Create compressed archive
echo -e "${YELLOW}🗜️  Creating compressed archive...${NC}"

cd "$BACKUP_DIR"
tar -czf "${BACKUP_NAME}.tar.gz" \
    "${BACKUP_NAME}_database.sql" \
    "${BACKUP_NAME}_uploads" \
    "${BACKUP_NAME}_config"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Compressed archive created: ${BACKUP_NAME}.tar.gz${NC}"
    
    # Clean up individual backup files
    rm -rf "${BACKUP_NAME}_database.sql" \
            "${BACKUP_NAME}_uploads" \
            "${BACKUP_NAME}_config"
    
    echo -e "${GREEN}🧹 Cleaned up individual backup files${NC}"
else
    echo -e "${RED}❌ Failed to create compressed archive${NC}"
fi

# Clean up old backups (keep last 7 days)
echo -e "${YELLOW}🧹 Cleaning up old backups (keeping last 7 days)...${NC}"

find "$BACKUP_DIR" -name "discourse_backup_*.tar.gz" -mtime +7 -delete

echo -e "${GREEN}🎉 Backup completed successfully!${NC}"
echo -e "${GREEN}📁 Backup location: $BACKUP_DIR/${BACKUP_NAME}.tar.gz${NC}"

# Display backup size
BACKUP_SIZE=$(du -h "$BACKUP_DIR/${BACKUP_NAME}.tar.gz" | cut -f1)
echo -e "${GREEN}📊 Backup size: $BACKUP_SIZE${NC}"

# List all backups
echo -e "${YELLOW}📋 Available backups:${NC}"
ls -lh "$BACKUP_DIR"/discourse_backup_*.tar.gz 2>/dev/null || echo "No backups found"

