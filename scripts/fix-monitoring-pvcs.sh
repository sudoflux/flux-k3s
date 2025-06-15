#!/bin/bash
# Script to fix monitoring stack PVC references after k3s1 upgrade

echo "=== Fixing Monitoring Stack PVCs ==="

# Update Grafana deployment to use new Longhorn PVC
echo "Updating Grafana deployment..."
kubectl patch deployment kube-prometheus-stack-grafana -n monitoring --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/volumes/8/persistentVolumeClaim/claimName", "value": "grafana-storage-longhorn"}]'

# Delete old StatefulSets to recreate with new PVCs
echo "Recreating Prometheus StatefulSet..."
kubectl delete statefulset prometheus-kube-prometheus-stack-prometheus -n monitoring --cascade=orphan
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: prometheus-kube-prometheus-stack-prometheus
  namespace: monitoring
spec:
  replicas: 1
  serviceName: prometheus-operated
  selector:
    matchLabels:
      app.kubernetes.io/name: prometheus
      prometheus: kube-prometheus-stack-prometheus
  template:
    metadata:
      labels:
        app.kubernetes.io/name: prometheus
        prometheus: kube-prometheus-stack-prometheus
    spec:
      serviceAccountName: kube-prometheus-stack-prometheus
      containers:
      - name: prometheus
        image: quay.io/prometheus/prometheus:v2.54.1
        args:
        - --web.console.templates=/etc/prometheus/consoles
        - --web.console.libraries=/etc/prometheus/console_libraries
        - --config.file=/etc/prometheus/config_out/prometheus.env.yaml
        - --storage.tsdb.path=/prometheus
        - --storage.tsdb.retention.time=7d
        - --web.enable-lifecycle
        - --web.external-url=http://prometheus.k3s.local
        - --web.route-prefix=/
        - --web.config.file=/etc/prometheus/web_config/web-config.yaml
        volumeMounts:
        - mountPath: /prometheus
          name: prometheus-storage
      volumes:
      - name: prometheus-storage
        persistentVolumeClaim:
          claimName: prometheus-storage-longhorn-0
EOF

echo "Recreating Loki StatefulSet..."
kubectl delete statefulset loki -n monitoring --cascade=orphan
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: loki
  namespace: monitoring
spec:
  replicas: 1
  serviceName: loki-headless
  selector:
    matchLabels:
      app.kubernetes.io/name: loki
      app.kubernetes.io/instance: loki
  template:
    metadata:
      labels:
        app.kubernetes.io/name: loki
        app.kubernetes.io/instance: loki
    spec:
      serviceAccountName: loki
      containers:
      - name: loki
        image: grafana/loki:3.0.0
        args:
        - -config.file=/etc/loki/config/config.yaml
        - -target=all
        volumeMounts:
        - mountPath: /var/loki
          name: storage
      volumes:
      - name: storage
        persistentVolumeClaim:
          claimName: loki-storage-longhorn-0
EOF

echo "Recreating Alertmanager StatefulSet..."
kubectl delete statefulset alertmanager-kube-prometheus-stack-alertmanager -n monitoring --cascade=orphan
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: alertmanager-kube-prometheus-stack-alertmanager
  namespace: monitoring
spec:
  replicas: 1
  serviceName: alertmanager-operated
  selector:
    matchLabels:
      app.kubernetes.io/name: alertmanager
      alertmanager: kube-prometheus-stack-alertmanager
  template:
    metadata:
      labels:
        app.kubernetes.io/name: alertmanager
        alertmanager: kube-prometheus-stack-alertmanager
    spec:
      serviceAccountName: kube-prometheus-stack-alertmanager
      containers:
      - name: alertmanager
        image: quay.io/prometheus/alertmanager:v0.27.0
        args:
        - --config.file=/etc/alertmanager/config_out/alertmanager.env.yaml
        - --storage.path=/alertmanager
        - --data.retention=120h
        - --cluster.listen-address=
        - --web.listen-address=:9093
        - --web.external-url=http://alertmanager.k3s.local
        - --web.route-prefix=/
        - --cluster.peer-timeout=15s
        volumeMounts:
        - mountPath: /alertmanager
          name: alertmanager-storage
      volumes:
      - name: alertmanager-storage
        persistentVolumeClaim:
          claimName: alertmanager-storage-longhorn-0
EOF

echo "Monitoring stack PVC fix complete!"
echo "Check pod status with: kubectl get pods -n monitoring"