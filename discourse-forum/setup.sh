#!/bin/bash

# Discourse Server Setup Script
# This script helps you set up a Discourse server for your company

set -e

echo "🚀 Setting up Discourse Server for your company..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create .env file from example if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp env.example .env
    echo "⚠️  Please edit .env file with your actual configuration values before continuing."
    echo "   - Set your domain name"
    echo "   - Configure SMTP settings"
    echo "   - Set secure passwords"
    echo "   - Generate a secret key"
    echo ""
    read -p "Press Enter after you've configured .env file..."
fi

# Generate secret key if not set
if grep -q "your-secret-key" .env; then
    echo "🔑 Generating secret key..."
    SECRET_KEY=$(openssl rand -hex 64)
    sed -i.bak "s/your-secure-password/$SECRET_KEY/" .env
    echo "✅ Secret key generated and updated in .env file"
fi

# Generate database password if not set
if grep -q "your-secure-password" .env; then
    echo "🔑 Generating database password..."
    DB_PASSWORD=$(openssl rand -base64 32)
    sed -i.bak "s/your-secure-password/$DB_PASSWORD/" .env
    echo "✅ Database password generated and updated in .env file"
fi

# Generate Redis password if not set
if grep -q "your-redis-password" .env; then
    echo "🔑 Generating Redis password..."
    REDIS_PASSWORD=$(openssl rand -base64 32)
    sed -i.bak "s/your-redis-password/$REDIS_PASSWORD/" .env
    echo "✅ Redis password generated and updated in .env file"
fi

echo "🔧 Starting Discourse services..."
docker compose up -d

echo "⏳ Waiting for services to start..."
sleep 30

echo "📊 Checking service status..."
docker compose ps

echo ""
echo "🎉 Discourse server setup complete!"
echo ""
echo "Next steps:"
echo "1. Open your domain in a web browser"
echo "2. Complete the initial setup wizard"
echo "3. Create your first admin account"
echo "4. Configure company-specific settings"
echo ""
echo "Useful commands:"
echo "  - View logs: docker-compose logs -f"
echo "  - Stop services: docker-compose down"
echo "  - Restart services: docker-compose restart"
echo "  - Update Discourse: docker-compose pull && docker-compose up -d"
echo ""
echo "📚 Documentation: https://docs.discourse.org/"

