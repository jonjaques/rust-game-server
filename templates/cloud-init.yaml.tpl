#cloud-config
runcmd:
  - yum update -y
  - echo "/usr/bin/yum update --security -y" > /etc/cron.weekly/yumsecurity.cron
  - sleep 5
  - yum install -y docker jq amazon-efs-utils
  - sleep 5
  - usermod -a -G docker ec2-user
  - curl -L https://github.com/docker/compose/releases/download/1.25.4/docker-compose-Linux-x86_64 -o /usr/bin/docker-compose
  - chmod +x /usr/bin/docker-compose
  - systemctl enable docker
  - systemctl start docker
  - echo "docker system prune --force" > /etc/cron.hourly/docker-cleanup.cron
  - bash /etc/rust-admin/mount-volume.sh
  - docker-compose -f /app/docker-compose.yml up -d

write_files:
  - path: /app/docker-compose.yml
    content: |
      version: '3.4'

      volumes:
        prometheus_data:
        grafana_data:

      services:
        rustserver:
          env_file: /app/envs/rust.env
          image: didstopia/rust-server
          volumes:
            - /rust:/steamcmd/rust
          ports:
            - 28015:28015
            - 28015:28015/udp
            - 28016:28016
            - 28017:8080
          labels:
            org.label-schema.group: "rust"

        grafana:
          env_file: /app/envs/grafana.env
          image: grafana/grafana
          volumes:
            - grafana_data:/var/lib/grafana
          restart: unless-stopped
          expose:
            - 3000
          ports:
            - 28018:3000
          labels:
            org.label-schema.group: "monitoring"

        prometheus:
          image: prom/prometheus
          expose:
            - 9090
          volumes:
            - ./prometheus:/etc/prometheus
            - prometheus_data:/prometheus
          labels:
            org.label-schema.group: "monitoring"

        cadvisor:
          image: gcr.io/google-containers/cadvisor:v0.36.0
          volumes:
            - /:/rootfs:ro
            - /var/run:/var/run:rw
            - /sys:/sys:ro
            - /var/lib/docker:/var/lib/docker:ro
            - /cgroup:/cgroup:ro
          restart: unless-stopped
          expose:
            - 8080
          labels:
            org.label-schema.group: "monitoring"

        alertmanager:
          image: prom/alertmanager
          volumes:
            - ./alertmanager:/etc/alertmanager
          command:
            - '--config.file=/etc/alertmanager/config.yml'
            - '--storage.path=/alertmanager'
          restart: unless-stopped
          expose:
            - 9093
          labels:
            org.label-schema.group: "monitoring"

        pushgateway:
          image: prom/pushgateway
          restart: unless-stopped
          expose:
            - 9091
          labels:
            org.label-schema.group: "monitoring"

        nodeexporter:
          image: prom/node-exporter
          volumes:
            - /proc:/host/proc:ro
            - /sys:/host/sys:ro
            - /:/rootfs:ro
          command:
            - '--path.procfs=/host/proc'
            - '--path.rootfs=/rootfs'
            - '--path.sysfs=/host/sys'
            - '--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)($$|/)'
          restart: unless-stopped
          expose:
            - 9100
          labels:
            org.label-schema.group: "monitoring"

  - path: /app/envs/grafana.env
    content: |
      GF_SECURITY_ADMIN_USER=${GRAFANA_USER}
      GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
      GF_USERS_ALLOW_SIGN_UP=false

  - path: /app/envs/rust.env
    content: |
      RUST_SERVER_STARTUP_ARGUMENTS=${RUST_SERVER_STARTUP_ARGUMENTS}
      RUST_SERVER_IDENTITY=${RUST_SERVER_IDENTITY}
      RUST_SERVER_SEED=${RUST_SERVER_SEED}
      RUST_SERVER_NAME=${RUST_SERVER_NAME}
      RUST_SERVER_DESCRIPTION=${RUST_SERVER_DESCRIPTION}
      RUST_SERVER_URL=${RUST_SERVER_URL}
      RUST_SERVER_BANNER_URL=${RUST_SERVER_BANNER_URL}
      RUST_RCON_WEB=${RUST_RCON_WEB}
      RUST_RCON_PORT=${RUST_RCON_PORT}
      RUST_RCON_PASSWORD=${RUST_RCON_PASSWORD}
      RUST_UPDATE_CHECKING=${RUST_UPDATE_CHECKING}
      RUST_UPDATE_BRANCH=${RUST_UPDATE_BRANCH}
      RUST_START_MODE=${RUST_START_MODE}
      RUST_OXIDE_ENABLED=${RUST_OXIDE_ENABLED}
      RUST_OXIDE_UPDATE_ON_BOOT=${RUST_OXIDE_UPDATE_ON_BOOT}
      RUST_SERVER_WORLDSIZE=${RUST_SERVER_WORLDSIZE}
      RUST_SERVER_MAXPLAYERS=${RUST_SERVER_MAXPLAYERS}
      RUST_SERVER_SAVE_INTERVAL=${RUST_SERVER_SAVE_INTERVAL}


  - path: /etc/rust-admin/mount-volume.sh
    content: |
      #!/bin/bash
      set -e
      set -x

      # umask 022
      DIRECTORY=/rust

      # wait for EBS volume to attach
      DATA_STATE="unknown"
      until [ $DATA_STATE == "attached" ]; do
        DATA_STATE=$(aws ec2 describe-volumes \
            --region ${AWS_REGION} \
            --filters \
                Name=tag:Name,Values=${RUST_SERVER_IDENTITY}-persistent-volume \
                Name=attachment.device,Values=/dev/sdh \
            --query Volumes[].Attachments[].State \
            --output text)
        echo 'waiting for volume...'
        sleep 5
      done
      echo 'EBS volume attached!'

      # Format /dev/nvme1n1 if it does not contain a partition yet
      if [ "$(file -b -s /dev/nvme1n1)" == "data" ]; then
        mkfs -t ext4 /dev/nvme1n1
      fi

      # Create the Rust directory on our EC2 instance if it doesn't exist
      if [ ! -d "$DIRECTORY" ]; then
        mkdir -p $DIRECTORY
      fi


      # mount up the persistent filesystem
      if grep -qs "$DIRECTORY" /proc/mounts; then
        echo "Persistent filesystem already mounted."
      else
        echo "Persistent filesystem not mounted."
        mount /dev/nvme1n1 "$DIRECTORY"
        if [ $? -eq 0 ]; then
        echo "Mount success!"
        else
        echo "Something went wrong with the mount..."
        fi
      fi

  - path: /etc/docker/daemon.json
    content: |
      {
        "experimental": true,
        "log-driver": "awslogs",
        "log-opts": {
          "awslogs-group": "${RUST_SERVER_IDENTITY}",
          "tag": "{{.Name}}-{{.ID}}"
        }
      }

  - path: /app/alertmanager/config.yml
    content: |
      route:
        receiver: 'slack'

      receivers:
        - name: 'slack'
          slack_configs:
            - send_resolved: true
              text: "{{ .CommonAnnotations.description }}"
              username: 'Prometheus'
              channel: '${ALERTMANAGER_SLACK_CHANNEL}'
              api_url: '${ALERTMANAGER_SLACK_URL}'
  - path: /app/prometheus/prometheus.yml
    content: |
      global:
        scrape_interval:     10s
        evaluation_interval: 10s

        # Attach these labels to any time series or alerts when communicating with
        # external systems (federation, remote storage, Alertmanager).
        external_labels:
          monitor: '${RUST_SERVER_IDENTITY}'

      # Load and evaluate rules in this file every 'evaluation_interval' seconds.
      rule_files:
        - "alert.rules"

      # A scrape configuration containing exactly one endpoint to scrape.
      scrape_configs:
        - job_name: 'nodeexporter'
          scrape_interval: 10s
          static_configs:
            - targets: ['nodeexporter:9100']

        - job_name: 'cadvisor'
          scrape_interval: 10s
          static_configs:
            - targets: ['cadvisor:8080']

        - job_name: 'prometheus'
          scrape_interval: 10s
          static_configs:
            - targets: ['localhost:9090']

        - job_name: 'pushgateway'
          scrape_interval: 10s
          honor_labels: true
          static_configs:
            - targets: ['pushgateway:9091']

      alerting:
        alertmanagers:
        - scheme: http
          static_configs:
          - targets:
            - 'alertmanager:9093'

  - path: /app/prometheus/alert.rules
    content: |
      groups:
      - name: targets
        rules:
        - alert: monitor_service_down
          expr: up == 0
          for: 30s
          labels:
            severity: critical
          annotations:
            summary: "Monitor service non-operational"
            description: "Service {{ $labels.instance }} is down."

      - name: host
        rules:
        - alert: high_cpu_load
          expr: node_load1 > 1.5
          for: 30s
          labels:
            severity: warning
          annotations:
            summary: "Server under high load"
            description: "Docker host is under high load, the avg load 1m is at {{ $value}}. Reported by instance {{ $labels.instance }} of job {{ $labels.job }}."

        - alert: high_memory_load
          expr: (sum(node_memory_MemTotal_bytes) - sum(node_memory_MemFree_bytes + node_memory_Buffers_bytes + node_memory_Cached_bytes) ) / sum(node_memory_MemTotal_bytes) * 100 > 85
          for: 30s
          labels:
            severity: warning
          annotations:
            summary: "Server memory is almost full"
            description: "Docker host memory usage is {{ humanize $value}}%. Reported by instance {{ $labels.instance }} of job {{ $labels.job }}."

        - alert: high_storage_load
          expr: (node_filesystem_size_bytes{fstype="aufs"} - node_filesystem_free_bytes{fstype="aufs"}) / node_filesystem_size_bytes{fstype="aufs"}  * 100 > 85
          for: 30s
          labels:
            severity: warning
          annotations:
            summary: "Server storage is almost full"
            description: "Docker host storage usage is {{ humanize $value}}%. Reported by instance {{ $labels.instance }} of job {{ $labels.job }}."

