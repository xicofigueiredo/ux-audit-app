# UX Audit App - Kamal Deployment Guide

## Infrastructure Overview

- **Server**: DigitalOcean droplet (143.110.169.251)
- **Domain**: uxauditapp.zelusottomayor.com
- **Registry**: Docker Hub (zelusottomayor/uxauditapp)
- **Proxy**: Traefik with SSL termination
- **Background Jobs**: Sidekiq with Redis
- **Storage**: Persistent volumes for uploads and Redis data

## Container Architecture

### Web Containers
- **Memory**: 1GB
- **CPU**: 0.5 cores
- **Purpose**: Rails application serving web requests

### Worker Containers
- **Memory**: 2GB
- **CPU**: 1.0 cores
- **Purpose**: Background job processing (video analysis, LLM processing)

### Redis Container
- **Memory**: 512MB
- **CPU**: 0.25 cores
- **Purpose**: Job queue and caching
- **Storage**: /mnt/volume-lon1-01/uxauditapp-redis

## Required Environment Variables

Before deploying, ensure these environment variables are set:

```bash
export KAMAL_REGISTRY_PASSWORD="your_docker_hub_token"
export OPENAI_API_KEY="your_openai_api_key"
export DATABASE_URL="postgresql://user:password@host:port/database"
```

## Deployment Commands

### Initial Setup
```bash
# Install dependencies
bundle install

# Setup server and deploy accessories (Redis)
kamal setup

# Deploy application
kamal deploy
```

### Regular Deployments
```bash
# Deploy new version
kamal deploy

# Check status
kamal app logs
kamal accessory logs redis
```

### Maintenance Commands
```bash
# SSH into container
kamal app exec --interactive bash

# Run Rails console
kamal app exec --interactive "bundle exec rails console"

# Check health
curl https://uxauditapp.zelusottomayor.com/health

# Manual cleanup
kamal app exec "bundle exec rails uxauditapp:full_cleanup"
```

## Process Management & Monitoring

### FFmpeg Process Cleanup
The app includes automated cleanup for FFmpeg processes that may accumulate during video processing:

```bash
# Monitor processes
bundle exec rails uxauditapp:monitor_ffmpeg

# Manual cleanup
bundle exec rails uxauditapp:cleanup_ffmpeg
```

### Automated Cleanup
A cron job runs every 2 hours to clean up:
- Orphaned FFmpeg processes
- Old temporary files
- Failed video audits

Add to server crontab:
```bash
0 */2 * * * /app/bin/cleanup-cron
```

### Health Monitoring
The `/health` endpoint monitors:
- Database connectivity
- Redis connectivity
- FFmpeg process count
- Disk usage
- OpenAI API configuration

## Emergency Procedures

### High CPU Usage (FFmpeg processes)
```bash
# Kill all FFmpeg processes
pkill -f "ffmpeg"

# Force kill if needed
pkill -9 -f "ffmpeg"

# Restart workers
kamal app restart --role workers
```

### Container Issues
```bash
# Restart web containers
kamal app restart --role web

# Restart worker containers
kamal app restart --role workers

# Full restart
kamal app restart
```

### Rollback
```bash
# Rollback to previous version
kamal app rollback

# Check logs
kamal app logs --lines 100
```

## Storage Management

### Persistent Volumes
- `/mnt/volume-lon1-01/uxauditapp`: Application storage
- `/mnt/volume-lon1-01/uxauditapp-tmp`: Temporary files
- `/mnt/volume-lon1-01/uxauditapp-redis`: Redis data

### Cleanup Strategy
- Video files are automatically cleaned after analysis
- Frame extraction files are removed after processing
- Failed audits are cleaned up after 24 hours

## Security Notes

- SSL termination handled by Traefik
- Environment variables secured through Kamal secrets
- Container runs as non-root user
- Resource limits prevent runaway processes

## Troubleshooting

### Common Issues

1. **OpenAI API Rate Limits**
   - Monitor job queue: Check Sidekiq dashboard
   - Adjust retry strategy in jobs

2. **High Memory Usage**
   - Check container resource usage: `kamal app exec "free -h"`
   - Monitor FFmpeg process count

3. **Disk Space Issues**
   - Check temp directory usage: `df -h /app/tmp`
   - Run manual cleanup: `bundle exec rails uxauditapp:cleanup_temp_files`

### Log Locations
- Application logs: `kamal app logs`
- Redis logs: `kamal accessory logs redis`
- Cleanup logs: `log/cleanup.log` (in container)

## Performance Optimization

### Job Timeouts
- LLM Analysis: 5 minutes (configured in Sidekiq)
- Video Processing: 5 minutes
- Cleanup: 2 minutes

### Resource Monitoring
The health endpoint provides real-time metrics for:
- Process counts
- Memory usage
- Disk usage
- Service connectivity