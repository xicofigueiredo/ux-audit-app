# Beta Testing Resource Configuration

## Overview
This document outlines the resource adjustments made to support beta testing with multiple concurrent users.

## Changes Made

### Infrastructure Scaling (config/deploy.yml)

#### Web Server
- **Memory**: Increased from 1GB → 2GB
- **CPU**: Increased from 0.5 → 1.0 cores
- **Rationale**: Support 10-20 concurrent beta users with improved response times

#### Redis Cache
- **Memory**: Increased from 512MB → 1GB
- **CPU**: Increased from 0.25 → 0.5 cores
- **Rationale**: Handle increased session data and background job queuing

#### Background Workers
- **Memory**: Maintained at 2GB (adequate for current LLM processing loads)
- **CPU**: Maintained at 1.0 cores

### Application Configuration (config/puma.rb)

#### Thread Pool
- **Max Threads**: Increased from 5 → 8 threads
- **Environment Variable**: `RAILS_MAX_THREADS=8`

#### Worker Processes
- **Workers**: Increased from 1 → 2 workers in production
- **Environment Variable**: `WEB_CONCURRENCY=2`

## Environment Variables Set

```bash
RAILS_MAX_THREADS=8    # Increased thread pool for better concurrency
WEB_CONCURRENCY=2      # Multiple workers to leverage dual-core allocation
```

## Expected Performance Improvements

- **Concurrent Users**: Support for 10-20 simultaneous beta testers
- **Response Times**: Reduced latency under load
- **Resource Utilization**: Better CPU and memory efficiency
- **Stability**: Improved handling of video processing and LLM analysis jobs

## Deployment

To apply these changes:

```bash
kamal deploy
```

## Monitoring Recommendations

1. Monitor memory usage on web containers
2. Track response times during beta testing
3. Monitor Redis memory utilization
4. Watch for any worker timeout issues

## Rollback Plan

If issues arise, previous configuration values:
- Web: 1GB RAM, 0.5 CPU
- Redis: 512MB RAM, 0.25 CPU
- Puma: 5 max threads, 1 worker

Rollback command:
```bash
git revert [commit-hash]
kamal deploy
```