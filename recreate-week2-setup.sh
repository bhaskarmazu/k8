#!/usr/bin/env bash
# Recreates web + app-config + app-secret + PVC setup from Week 1 Day 4 / Week 2 Day 2.
# Run this after your kind cluster is back up (docker info working, cluster created).
 
set -e
 
echo "==> Creating ConfigMap app-config"
kubectl create configmap app-config \
  --from-literal=MODE=learning \
  --from-literal=LOG_LEVEL=debug \
  --dry-run=client -o yaml | kubectl apply -f -
 
echo "==> Creating Secret app-secret"
kubectl create secret generic app-secret \
  --from-literal=password=test123 \
  --dry-run=client -o yaml | kubectl apply -f -
 
echo "==> Creating PVC web-storage"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: web-storage
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
 
echo "==> Creating Deployment web (with envFrom + configmap volume + PVC volume)"
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  labels:
    app: web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx
        imagePullPolicy: Always
        envFrom:
        - configMapRef:
            name: app-config
        - secretRef:
            name: app-secret
        volumeMounts:
        - name: config-volume
          mountPath: /etc/app-config
        - name: data-volume
          mountPath: /usr/share/nginx/html/data
      volumes:
      - name: config-volume
        configMap:
          name: app-config
      - name: data-volume
        persistentVolumeClaim:
          claimName: web-storage
EOF
 
echo "==> Creating Service web (ClusterIP)"
kubectl expose deployment web --port=80 --type=ClusterIP --dry-run=client -o yaml | kubectl apply -f -
 
echo "==> Waiting for rollout"
kubectl rollout status deployment/web
 
echo "==> Done. Current state:"
kubectl get deployment,pods,svc,configmap,secret,pvc,pv -l app=web 2>/dev/null
kubectl get pods
kubectl get pvc web-storage
kubectl get pv