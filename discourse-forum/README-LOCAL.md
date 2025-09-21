# Local Discourse Testing Setup

This guide will help you set up and test Discourse locally on your machine.

## 🚀 Quick Start for Local Testing

### 1. Prerequisites
- **Docker Desktop** installed and running
- **Docker Compose** (usually included with Docker Desktop)
- **4GB+ RAM** available for Docker
- **10GB+ free disk space**

### 2. Start Local Discourse
```bash
# Make the script executable
chmod +x setup-local.sh

# Run the local setup
./setup-local.sh
```

### 3. Access Your Local Forum
- **Main URL**: http://localhost:3000
- **Admin Panel**: http://localhost:3000/admin

## 🔧 Local Configuration

### Port Mapping
- **3000** → Discourse web interface (main)
- **3001** → HTTPS (not needed locally)
- **5433** → PostgreSQL database
- **6380** → Redis cache

### Local vs Production
| Feature | Local Testing | Production |
|---------|---------------|------------|
| Hostname | localhost:3000 | your-domain.com |
| SMTP | Disabled | Configured |
| SSL | Not required | Required |
| Ports | 3000+ | 80/443 |
| Security | Basic | Enhanced |

## 🐳 Docker Commands for Local Testing

### Start Services
```bash
docker-compose -f docker-compose.local.yml up -d
```

### View Logs
```bash
# All services
docker-compose -f docker-compose.local.yml logs -f

# Specific service
docker-compose -f docker-compose.local.yml logs -f discourse
```

### Stop Services
```bash
docker-compose -f docker-compose.local.yml down
```

### Restart Services
```bash
docker-compose -f docker-compose.local.yml restart
```

### Check Status
```bash
docker-compose -f docker-compose.local.yml ps
```

## 📊 Monitoring Local Services

### Check Resource Usage
```bash
docker stats
```

### View Container Details
```bash
docker ps
docker inspect discourse_local
```

### Access Database (if needed)
```bash
docker-compose -f docker-compose.local.yml exec postgres psql -U discourse -d discourse
```

### Access Redis (if needed)
```bash
docker-compose -f docker-compose.local.yml exec redis redis-cli -a redis_local_password
```

## 🧪 Testing Features

### What You Can Test Locally
- ✅ User registration and login
- ✅ Creating categories and topics
- ✅ Posting and replying
- ✅ User management
- ✅ Admin panel features
- ✅ Basic customization
- ✅ Mobile responsiveness

### What's Limited Locally
- ❌ Email notifications (SMTP disabled)
- ❌ External integrations
- ❌ SSL/HTTPS
- ❌ Domain-specific features
- ❌ Production performance

## 🔍 Troubleshooting Local Issues

### Common Problems

**1. Port Already in Use**
```bash
# Check what's using the ports
lsof -i :3000
lsof -i :5433
lsof -i :6380

# Kill processes if needed
kill -9 <PID>
```

**2. Docker Permission Issues**
```bash
# On macOS/Linux, ensure Docker has proper permissions
sudo chown $USER:$USER ~/.docker
```

**3. Services Won't Start**
```bash
# Check Docker logs
docker-compose -f docker-compose.local.yml logs

# Check Docker system status
docker system df
docker system prune  # Clean up unused resources
```

**4. Discourse Takes Too Long to Start**
```bash
# Check if containers are healthy
docker-compose -f docker-compose.local.yml ps

# View startup logs
docker-compose -f docker-compose.local.yml logs -f discourse
```

### Performance Issues

**Low Memory**
- Increase Docker memory limit in Docker Desktop
- Close other applications
- Restart Docker Desktop

**Slow Startup**
- First run always takes longer (5-10 minutes)
- Subsequent starts are faster
- Check your machine's resources

## 🎯 Local Development Workflow

### 1. Development Cycle
```bash
# Start services
./setup-local.sh

# Make changes to configuration
# Test in browser at localhost:3000

# Stop services when done
docker-compose -f docker-compose.local.yml down
```

### 2. Testing Changes
- Modify `docker-compose.local.yml` for configuration changes
- Edit `env.local` for environment variables
- Restart services to apply changes

### 3. Data Persistence
- Local data is stored in Docker volumes
- Data persists between container restarts
- Use `docker-compose -f docker-compose.local.yml down -v` to clear all data

## 🔄 Updating Local Discourse

### Update to Latest Version
```bash
# Pull latest images
docker-compose -f docker-compose.local.yml pull

# Restart with new images
docker-compose -f docker-compose.local.yml up -d
```

### Backup Local Data (Optional)
```bash
# Create backup before updating
docker-compose -f docker-compose.local.yml exec postgres pg_dump -U discourse discourse > local_backup.sql
```

## 📱 Testing Mobile Experience

### Browser Developer Tools
1. Open http://localhost:3000
2. Press F12 to open DevTools
3. Click the mobile device icon
4. Test different screen sizes

### Mobile Testing
- Test on actual mobile devices
- Check touch interactions
- Verify responsive design
- Test mobile-specific features

## 🚀 Moving to Production

### When Ready to Deploy
1. **Update Configuration**
   - Change `docker-compose.yml` (not local)
   - Configure proper domain
   - Set up SMTP
   - Enable SSL

2. **Security Hardening**
   - Change default passwords
   - Generate new secret keys
   - Configure firewall
   - Set up monitoring

3. **Data Migration**
   - Export local data if needed
   - Set up production database
   - Configure backups
   - Test production setup

## 📚 Additional Resources

- [Discourse Documentation](https://docs.discourse.org/)
- [Docker Documentation](https://docs.docker.com/)
- [Local Development Best Practices](https://docs.discourse.org/category/developers)

---

**Happy Local Testing! 🎉**

Remember: This is for development and testing only. Use the production setup for your actual company forum.

