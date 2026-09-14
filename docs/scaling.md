# Scaling Bazel Remote Cache

> **Note**: This is a reference guide for future scaling. The current POC demonstrates Phase 1 (single machine with Docker). Phases 2-4 describe reference architectures to be implemented in future versions.

Strategies for scaling bazel-remote cache infrastructure as your organization grows.

## Scaling Phases

### Phase 1: Single Developer (0-5 developers)
- Docker-based bazel-remote on local machine
- Local execution with caching
- Cache size: 10GB
- **Cost**: Free (self-hosted on existing hardware)

### Phase 2: Small Team (5-20 developers)
- Single bazel-remote instance on shared server
- 2-4 build machines connecting to cache
- Cache size: 50-100GB
- Local NFS or USB storage
- **Cost**: $200-500/month (server hosting)

### Phase 3: Growing Team (20-100 developers)
- Kubernetes-based bazel-remote cluster with 2-3 replicas
- S3 or GCS backend storage for cache
- Load balancer for HA
- 100GB-1TB cache
- **Cost**: $1,000-3,000/month (K8s + cloud storage)

### Phase 4: Enterprise (100+ developers)
- High-availability bazel-remote cluster (3-5 replicas)
- Multiple regions for faster access
- Hybrid storage (local + cloud)
- Advanced monitoring and alerting
- Dedicated infrastructure team
- **Cost**: $5,000-20,000+/month

## Scaling Cache Size

### Vertical Scaling (Single Instance)

```bash
# Update docker-compose.yml
# Change max_size parameter (in GB)
bazel-remote --max_size=100  # 100GB cache
```

### Horizontal Scaling (Multiple Instances with Load Balancer)

```bash
# Deploy multiple bazel-remote instances behind a load balancer
# Each instance can have its own storage or shared backend
```

Use case: Distribute cache load across multiple servers

```
┌─────────────────┐
│  Load Balancer  │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
┌───▼──┐   ┌──▼───┐
│BR-1  │   │BR-2  │
│8085  │   │8085  │
└───┬──┘   └──┬───┘
    │         │
    └────┬────┘
         │
    ┌────▼─────┐
    │  Shared  │
    │ Storage  │
    │(S3/NFS)  │
    └──────────┘
```

## Scaling with Cloud Storage Backend

### S3 Backend Configuration

```bash
# Update bazel-remote command to use S3
bazel-remote \
  --dir=/var/bazel-remote/cache \
  --http_address=0.0.0.0:8085 \
  --max_size=1000 \
  --s3_bucket=my-bazel-cache \
  --s3_region=us-west-2 \
  --s3_auth=aws_credentials
```

### GCS Backend Configuration

```bash
# Update bazel-remote command to use GCS
bazel-remote \
  --dir=/var/bazel-remote/cache \
  --http_address=0.0.0.0:8085 \
  --max_size=1000 \
  --gcs_bucket=my-bazel-cache \
  --gcs_auth=application_default
```

## Kubernetes Auto-Scaling

### Horizontal Pod Autoscaler

Monitor cache size and scale based on load:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: bazel-remote-hpa
  namespace: bazel-remote
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: StatefulSet
    name: bazel-remote
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 15
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 50
          periodSeconds: 15
```

Apply HPA:

```bash
kubectl apply -f bazel-remote-hpa.yaml
```

### Scale Replicas Manually

```bash
# Scale to 5 replicas
kubectl scale statefulset bazel-remote \
  --replicas=5 \
  -n bazel-remote

# Verify scaling
kubectl get statefulset bazel-remote -n bazel-remote
```

## Scaling Strategy by Use Case

### Development Teams (Cache Hit-Focused)

- **Goal**: Maximize cache hits for faster local builds
- **Config**: Single region, 100-500GB cache
- **Monitoring**: Cache hit rate, miss analysis
- **Action**: Add larger cache size before adding replicas

```bash
# Invest in cache size first
config:remote-cache \
    --remote_cache=http://bazel-cache.internal \
    --remote_timeout=3600s \
    --remote_upload_local_results=true
```

### CI/CD Pipelines (Throughput-Focused)

- **Goal**: Handle high concurrent build load
- **Config**: Multiple replicas, distributed load
- **Monitoring**: Request throughput, latency
- **Action**: Add replicas for concurrent capacity

```bash
# Load balancer round-robin across replicas
# Clients auto-retry on timeout
--remote_cache=http://bazel-cache-lb.internal:8085
```

### Multi-Region Deployments (Latency-Focused)

- **Goal**: Minimize latency from any region
- **Config**: Regional bazel-remote instances
- **Monitoring**: Per-region latency, cross-region replication
- **Action**: Deploy in each region, replicate cache

```bash
# Use regional endpoints
config:remote-cache-us \
    --remote_cache=http://bazel-cache-us.example.com

config:remote-cache-eu \
    --remote_cache=http://bazel-cache-eu.example.com
```

## Performance Tuning

### Optimize for Your Workload

```bash
# For high throughput (CI/CD)
bazel-remote \
  --http_address=0.0.0.0:8085 \
  --max_size=500 \
  --dir=/var/cache/bazel-remote \
  --slow_upload_threshold=1s

# For low latency (developers)
bazel-remote \
  --http_address=0.0.0.0:8085 \
  --max_size=100 \
  --dir=/var/cache/bazel-remote \
  --enable_s3=false
```

## Monitoring Scaling Effectiveness

### Key Metrics

Track these metrics to know when to scale:

1. **Cache Hit Rate**: Target > 80% for mature projects
   ```bash
   curl http://bazel-cache/status | jq .cache_stats.hits_per_miss
   ```

2. **Request Latency**: Target < 500ms P99
   ```bash
   curl http://bazel-cache/metrics | grep http_request_duration
   ```

3. **Storage Utilization**: Alert when > 85%
   ```bash
   curl http://bazel-cache/status | jq .cache_size_bytes
   ```

4. **Concurrent Requests**: Scale replicas if consistently high
   ```bash
   curl http://bazel-cache/metrics | grep http_requests_in_flight
   ```

## Scaling Checklist

- [ ] Monitor cache hit rate weekly
- [ ] Track storage usage growth
- [ ] Measure request latency by region
- [ ] Set up alerting for resource limits
- [ ] Test failover procedures quarterly
- [ ] Document runbooks for scaling operations
- [ ] Plan for 2x growth in the next 12 months

## Next Steps

- Implement monitoring with Prometheus/Grafana
- Set up alerting for critical metrics
- Create runbooks for common scaling scenarios
- Test disaster recovery procedures
- Plan capacity for growth

## Additional Resources

- [bazel-remote GitHub](https://github.com/buchgr/bazel-remote)
- [Kubernetes Horizontal Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Bazel Performance Tuning](https://bazel.build/docs/user-manual#performance)
- [Production Setup Guide](production-setup.md)
