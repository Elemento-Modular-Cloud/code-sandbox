# 🚀 Local Discourse - Quick Start

Get Discourse running locally in 3 simple steps!

## ⚡ 3-Step Setup

### Step 1: Check Docker
```bash
# Make sure Docker is running
docker --version
docker compose --version
```

### Step 2: Run Local Setup
```bash
cd discourse-forum
./setup-local.sh
```

### Step 3: Access Your Forum
- **Open**: http://localhost:3000
- **Wait**: 5-10 minutes for first startup
- **Enjoy**: Your local Discourse forum!

## 🔧 What Happens

The setup script will:
- ✅ Check Docker requirements
- ✅ Create local configuration
- ✅ Start Discourse, PostgreSQL, and Redis
- ✅ Configure everything for local testing
- ✅ Give you access URLs

## 🌐 Access URLs

| Service | URL | Purpose |
|---------|-----|---------|
| **Discourse** | http://localhost:3000 | Main forum |
| **Admin** | http://localhost:3000/admin | Admin panel |
| **Database** | localhost:5433 | PostgreSQL |
| **Cache** | localhost:6380 | Redis |

## 🚨 Common Issues & Fixes

### Migration Errors (Most Common)
If you see database migration errors:
```bash
# Run the migration fix script
./fix-migrations.sh
```

This script will:
- 🧹 Clean up existing containers
- 🔧 Restart with proper configuration
- ✅ Fix pgvector extension issues
- ⏳ Wait for proper startup

### "Port already in use"
```bash
# Check what's using port 3000
lsof -i :3000
# Kill if needed: kill -9 <PID>
```

### "Docker not running"
- Start Docker Desktop
- Wait for it to fully load

### "Services won't start"
```bash
# Check logs
docker compose -f docker-compose.local.yml logs
```

## 🛑 Stop When Done

```bash
# Stop all services
docker compose -f docker-compose.local.yml down

# Stop and remove all data
docker compose -f docker-compose.local.yml down -v
```

## 📱 Test Everything

- ✅ Create user account
- ✅ Post topics and replies
- ✅ Test mobile view (F12 → mobile icon)
- ✅ Try admin features
- ✅ Customize categories

## 🔍 Troubleshooting

### Still Having Issues?
1. **Run the fix script**: `./fix-migrations.sh`
2. **Check logs**: `docker compose -f docker-compose.local.yml logs -f discourse`
3. **Wait longer**: First startup can take 15+ minutes
4. **Check resources**: Ensure Docker has enough RAM (4GB+)

### Database Issues?
```bash
# Check database status
docker compose -f docker-compose.local.yml exec postgres pg_isready -U discourse

# Check vector extension
docker compose -f docker-compose.local.yml exec postgres psql -U discourse -d discourse -c "SELECT * FROM pg_extension WHERE extname = 'vector';"
```

---

**That's it!** Your local Discourse is ready for testing and development. 🎉

**Pro tip**: If you encounter migration errors, just run `./fix-migrations.sh` - it's designed to solve the most common startup issues!

Need more details? Check `README-LOCAL.md` for comprehensive information.
