# Company Discourse Server

A complete Discourse forum setup for your company using Docker Compose.

## 🚀 Quick Start

1. **Clone or download this repository**
2. **Run the setup script:**
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```
3. **Follow the prompts to configure your server**

## 📋 Prerequisites

- **Server Requirements:**
  - Minimum 2GB RAM
  - 2 CPU cores
  - 20GB storage
  - Ubuntu 18.04+ or similar Linux distribution

- **Software Requirements:**
  - Docker
  - Docker Compose
  - Domain name pointing to your server

## ⚙️ Configuration

### 1. Environment Variables

Copy `env.example` to `.env` and configure:

```bash
cp env.example .env
nano .env
```

**Required Settings:**
- `DISCOURSE_HOSTNAME`: Your domain name (e.g., `forum.yourcompany.com`)
- `DISCOURSE_DEVELOPER_EMAILS`: Admin email addresses
- `DISCOURSE_SMTP_*`: Email server configuration for notifications

**Security Settings:**
- `DISCOURSE_DB_PASSWORD`: PostgreSQL password
- `DISCOURSE_REDIS_PASSWORD`: Redis password
- `DISCOURSE_SECRET_KEY_BASE`: Secret key for sessions

### 2. SMTP Configuration

For Gmail:
```
DISCOURSE_SMTP_ADDRESS=smtp.gmail.com
DISCOURSE_SMTP_PORT=587
DISCOURSE_SMTP_USER_NAME=your-email@gmail.com
DISCOURSE_SMTP_PASSWORD=your-app-password
DISCOURSE_SMTP_ENABLE_START_TLS=true
```

**Note:** Use App Passwords for Gmail, not your regular password.

### 3. Domain Configuration

Ensure your domain points to your server's IP address:
```bash
# Check your server's IP
curl ifconfig.me
```

## 🐳 Docker Services

The setup includes three main services:

1. **Discourse**: Main application server
2. **PostgreSQL**: Database for posts, users, and settings
3. **Redis**: Caching and session storage

## 🚀 Deployment

### Start Services
```bash
docker-compose up -d
```

### Check Status
```bash
docker-compose ps
docker-compose logs -f
```

### Stop Services
```bash
docker-compose down
```

## 🔧 Initial Setup

1. **Access your forum** at `http://your-domain.com`
2. **Complete the setup wizard:**
   - Create admin account
   - Configure site settings
   - Set up categories
3. **Customize for your company:**
   - Upload company logo
   - Set company colors
   - Configure user groups

## 🎨 Company Customization

### Branding
- Company logo and favicon
- Custom color scheme
- Company-specific categories
- Welcome message

### User Management
- Department-based groups
- Role-based permissions
- SSO integration (optional)
- Invitation system

### Content Organization
- Knowledge base categories
- Project discussion areas
- Announcement channels
- FAQ sections

## 🔒 Security Features

- HTTPS/SSL encryption
- Secure password policies
- Rate limiting
- Spam protection
- User moderation tools

## 📊 Monitoring & Maintenance

### Health Checks
```bash
# Check service health
docker-compose ps
docker-compose logs discourse

# Monitor resource usage
docker stats
```

### Backups
```bash
# Database backup
docker-compose exec postgres pg_dump -U discourse discourse > backup.sql

# File uploads backup
docker cp discourse:/var/discourse/shared/standalone/uploads ./uploads_backup
```

### Updates
```bash
# Update Discourse
docker-compose pull
docker-compose up -d

# Update dependencies
docker-compose pull postgres redis
docker-compose up -d
```

## 🌐 Advanced Configuration

### S3 Storage
Configure S3 for file storage and backups:
```bash
DISCOURSE_S3_ACCESS_KEY_ID=your-access-key
DISCOURSE_S3_SECRET_ACCESS_KEY=your-secret-key
DISCOURSE_S3_BUCKET=your-bucket-name
DISCOURSE_S3_REGION=your-region
```

### CDN Setup
For better performance, configure a CDN:
```bash
DISCOURSE_CDN_URL=https://cdn.yourcompany.com
```

### SSL Certificate
For production, use Let's Encrypt:
```bash
# Install certbot
sudo apt install certbot

# Generate certificate
sudo certbot certonly --standalone -d your-domain.com
```

## 🆘 Troubleshooting

### Common Issues

**Service won't start:**
```bash
# Check logs
docker-compose logs

# Verify ports aren't in use
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443
```

**Database connection issues:**
```bash
# Check PostgreSQL logs
docker-compose logs postgres

# Test connection
docker-compose exec postgres psql -U discourse -d discourse
```

**Email not working:**
- Verify SMTP credentials
- Check firewall settings
- Test SMTP connection manually

### Getting Help

- [Discourse Documentation](https://docs.discourse.org/)
- [Discourse Community](https://meta.discourse.org/)
- [Docker Documentation](https://docs.docker.com/)

## 📈 Performance Optimization

### For High Traffic
- Increase server resources (4GB+ RAM, 4+ CPU cores)
- Configure S3 for file storage
- Set up CDN
- Enable Redis clustering

### Monitoring
- Set up logging aggregation
- Monitor database performance
- Track user engagement metrics
- Set up alerting

## 🔄 Backup & Recovery

### Automated Backups
Create a cron job for regular backups:
```bash
# Add to crontab
0 2 * * * /path/to/backup-script.sh
```

### Disaster Recovery
- Regular database backups
- Configuration backups
- Document recovery procedures
- Test restore procedures

## 📝 License

This setup is based on the open-source Discourse platform. See [Discourse License](https://github.com/discourse/discourse/blob/main/LICENSE.txt) for details.

---

**Need help?** Check the troubleshooting section or reach out to your DevOps team!

