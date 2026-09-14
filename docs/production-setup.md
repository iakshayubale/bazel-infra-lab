# Production Deployment: bazel-remote on Kubernetes

> **Note**: This is a reference architecture for future implementation. The current POC uses a simple Docker setup on a single machine. This guide covers production deployment patterns that will be tested and implemented in future versions.

This guide covers deploying bazel-remote to production with high availability, persistent storage, and monitoring.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│         External Clients (Bazel, CI/CD)                 │
└────────────────────┬────────────────────────────────────┘
                     │
        ┌────────────▼────────────┐
        │   Load Balancer (LB)    │
        │   (HTTPS, TLS)          │
        └────────────┬────────────┘
                     │
     ┌───────────────┼─────────────┐
     │               │             │
┌────▼──────┐  ┌────-▼─────┐  ┌────▼──────┐
│bazel-     │  │bazel-     │  │bazel-     │
│remote (1) │  │remote (2) │  │remote (3) │
└────┬──────┘  └────┬──────┘  └────┬──────┘
     │              │              │
     └──────────────┼──────────────┘
                    │
          ┌─────────▼──────────┐
          │  Shared Storage    │
          │  (S3/GCS/NFS)      │
          │  (Cache directory) │
          └────────────────────┘
```

## Prerequisites

- Kubernetes 1.20+ cluster
- kubectl configured
- Helm 3.0+ (optional, for templating)
- Persistent storage (S3, GCS, or NFS)
- Domain name and TLS certificate (optional but recommended)

## Deployment Steps

### 1. Create Kubernetes Namespace

```bash
kubectl create namespace bazel-remote
```

### 2. Create Storage Secrets (for S3 or GCS)

For S3:

```bash
kubectl create secret generic bazel-remote-s3 \
  --from-literal=access-key-id=YOUR_AWS_KEY \
  --from-literal=secret-access-key=YOUR_AWS_SECRET \
  -n bazel-remote
```

For GCS:

```bash
kubectl create secret generic bazel-remote-gcs \
  --from-file=key.json=/path/to/gcs-key.json \
  -n bazel-remote
```

### 3. Create ConfigMap for bazel-remote Configuration

```bash
cat > bazel-remote-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: bazel-remote-config
  namespace: bazel-remote
data:
  bazel-remote.conf: |
    # Cache directory
    dir = /var/bazel-remote/cache
    
    # Port
    http_address = 0.0.0.0:8085
    grpc_address = 0.0.0.0:8086
    
    # Maximum cache size (50GB for production)
    max_size = 50
    
    # S3 remote storage (optional)
    s3:
      auth: aws_credentials
      bucket: my-bazel-cache
      prefix: /
      region: us-west-2
EOF

kubectl apply -f bazel-remote-config.yaml
```

### 4. Create PersistentVolumeClaim for Local Cache

```bash
cat > bazel-remote-pvc.yaml << 'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: bazel-remote-cache
  namespace: bazel-remote
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
  storageClassName: fast-ssd  # Adjust to your cluster's storage class
EOF

kubectl apply -f bazel-remote-pvc.yaml
```

### 5. Deploy bazel-remote as StatefulSet

For high availability with multiple replicas:

```bash
cat > bazel-remote-statefulset.yaml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: bazel-remote
  namespace: bazel-remote
spec:
  serviceName: bazel-remote
  replicas: 3
  selector:
    matchLabels:
      app: bazel-remote
  template:
    metadata:
      labels:
        app: bazel-remote
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchExpressions:
                    - key: app
                      operator: In
                      values:
                        - bazel-remote
                topologyKey: kubernetes.io/hostname
      
      containers:
        - name: bazel-remote
          image: buchgr/bazel-remote:v2.4.1
          ports:
            - containerPort: 8085
              name: http
            - containerPort: 8086
              name: grpc
          args:
            - "--dir=/var/bazel-remote/cache"
            - "--http_address=0.0.0.0:8085"
            - "--grpc_address=0.0.0.0:8086"
            - "--max_size=50"
          
          resources:
            requests:
              cpu: 2
              memory: 4Gi
            limits:
              cpu: 4
              memory: 8Gi
          
          volumeMounts:
            - name: cache
              mountPath: /var/bazel-remote/cache
          
          livenessProbe:
            httpGet:
              path: /status
              port: 8085
            initialDelaySeconds: 30
            periodSeconds: 10
          
          readinessProbe:
            httpGet:
              path: /status
              port: 8085
            initialDelaySeconds: 10
            periodSeconds: 5
      
      volumes:
        - name: cache
          persistentVolumeClaim:
            claimName: bazel-remote-cache
  
  volumeClaimTemplates:
    - metadata:
        name: cache
      spec:
        accessModes: [ "ReadWriteOnce" ]
        storageClassName: fast-ssd
        resources:
          requests:
            storage: 100Gi
EOF

kubectl apply -f bazel-remote-statefulset.yaml
```

### 6. Create Service for Load Balancing

```bash
cat > bazel-remote-service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: bazel-remote
  namespace: bazel-remote
spec:
  type: LoadBalancer
  selector:
    app: bazel-remote
  ports:
    - port: 8085
      targetPort: 8085
      name: http
    - port: 8086
      targetPort: 8086
      name: grpc
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800
EOF

kubectl apply -f bazel-remote-service.yaml
```

### 7. Create Ingress for HTTPS (Optional)

```bash
cat > bazel-remote-ingress.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: bazel-remote
  namespace: bazel-remote
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - bazel-cache.example.com
      secretName: bazel-remote-tls
  rules:
    - host: bazel-cache.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: bazel-remote
                port:
                  number: 8085
EOF

kubectl apply -f bazel-remote-ingress.yaml
```

## Verification

```bash
# Check StatefulSet status
kubectl get statefulset -n bazel-remote

# Check Pods
kubectl get pods -n bazel-remote -w

# Check Service (get external IP/hostname)
kubectl get service -n bazel-remote

# Test cache server
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://bazel-remote.bazel-remote.svc.cluster.local:8085/status
```

## Configure Bazel to Use Production Cache

Update `.bazelrc` to point to production:

```bash
config:remote-cache-prod \
    --remote_cache=https://bazel-cache.example.com \
    --remote_timeout=3600s \
    --remote_upload_local_results=true
```

## Monitoring

### Prometheus Metrics

bazel-remote exposes metrics at `/metrics`:

```bash
# Get metrics
kubectl port-forward -n bazel-remote svc/bazel-remote 8085:8085
curl http://localhost:8085/metrics
```

Key metrics to monitor:
- `bazel_remote_cas_directory_size_bytes` - Cache size
- `bazel_remote_http_requests_total` - Request count
- `bazel_remote_http_request_duration_seconds` - Request latency

### Health Checks

```bash
# Health check endpoint
curl http://bazel-cache.example.com/status
```

## Troubleshooting

### Pod stuck in Pending

```bash
kubectl describe pod -n bazel-remote <pod-name>
# Check PVC status and storage class availability
```

### High memory usage

```bash
# Reduce max_size in deployment
# Or increase pod memory limits
# Current: 100Gi cache, 8Gi memory limit
```

### Cache corruption

```bash
# Delete PVC and re-deploy
kubectl delete pvc -n bazel-remote cache-bazel-remote-0
kubectl delete pod -n bazel-remote bazel-remote-0
```

## Next Steps

- **Backup**: Set up automated backups for the cache volume
- **Scaling**: Adjust replicas and resources based on load
- **Disaster Recovery**: Test failover procedures
- **Security**: Configure network policies and RBAC

## Additional Resources

- [bazel-remote GitHub](https://github.com/buchgr/bazel-remote)
- [Kubernetes Documentation](https://kubernetes.io/docs)
- [Remote Build Execution Protocol](https://github.com/bazelbuild/remote-apis)
- [Scaling Guide](scaling.md)
- [Best Practices](best-practices.md)

