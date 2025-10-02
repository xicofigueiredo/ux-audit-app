# Redis Configuration for Production

## Required Redis Configuration

### Memory Management
```redis
# Set appropriate memory limit (adjust based on your server)
maxmemory 512mb
maxmemory-policy allkeys-lru

# Enable persistence
save 900 1
save 300 10
save 60 10000
```

### Performance Optimization
```redis
# Disable slow operations in production
rename-command FLUSHDB ""
rename-command FLUSHALL ""
rename-command DEBUG ""

# Set appropriate timeout
timeout 300
tcp-keepalive 60
```

### Environment Variables for Production

Add these to your production environment:

```bash
# Required
REDIS_URL=redis://your-redis-server:6379/0
REDIS_POOL_SIZE=10

# Optional (with defaults)
SIDEKIQ_WORKERS=2
SIDEKIQ_CONCURRENCY=10
SIDEKIQ_TIMEOUT=600
```

## Deployment Commands

### Start Background Workers
```bash
# For immediate fix (run in production)
bundle exec sidekiq -d -C config/sidekiq.yml -e production

# Or use the startup script
./bin/sidekiq_start
```

### Monitor Jobs
- Web UI: `/sidekiq` (development only)
- Production monitoring: Use Sidekiq Pro or external monitoring

### Health Checks
```bash
# Check if Sidekiq is processing
redis-cli LLEN queue:default

# Check worker status
ps aux | grep sidekiq
```