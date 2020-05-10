#cloud-config
runcmd:
  - yum update -y
  - echo "/usr/bin/yum update --security -y" > /etc/cron.weekly/yumsecurity.cron
  - sleep 5
  - yum install -y docker jq amazon-efs-utils https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
  - sleep 5
  - usermod -a -G docker ec2-user
  - curl -L https://github.com/docker/compose/releases/download/1.25.4/docker-compose-Linux-x86_64 -o /usr/bin/docker-compose
  - chmod +x /usr/bin/docker-compose
  - systemctl enable docker
  - systemctl start docker
  - echo "docker system prune --force" > /etc/cron.hourly/docker-cleanup.cron
  - amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/etc/cloudwatch/config.json -s
  - bash /etc/rust-admin/mount-volume.sh
  - docker-compose -f /rust.docker-compose up -d

write_files:
  - path: /rust.docker-compose
    content: |
      version: '3.4'

      services:
        rust_server:
          container_name: rust-server
          image: didstopia/rust-server
          ports:
            - 28015:28015
            - 28015:28015/udp
            - 28016:28016
            - 8080:8080
          restart: always
          volumes:
            - /rust:/steamcmd/rust
          env_file: /rust.env

  - path: /rust.env
    content: |
      # (DEFAULT: "-batchmode -load -nographics +server.secure 1")
      # RUST_SERVER_STARTUP_ARGUMENTS="-batchmode -load -nographics +server.secure 1"

      # (DEFAULT: "docker" - Mainly used for the name of the save directory)
      # RUST_SERVER_IDENTITY="docker"

      # (DEFAULT: "" - Rust server port 28015 if left blank or numeric value)
      # RUST_SERVER_PORT=""

      # (DEFAULT: "12345" - The server map seed, must be an integer)
      RUST_SERVER_SEED="${server_seed}"

      # (DEFAULT: "3500" - The map size, must be an integer)
      RUST_SERVER_WORLDSIZE="${server_world_size}"

      # (DEFAULT: "Rust Server [DOCKER]" - The publicly visible server name)
      RUST_SERVER_NAME="${server_name}"

      # (DEFAULT: "500" - Maximum players on the server, must be an integer)
      RUST_SERVER_MAXPLAYERS="${server_max_players}"

      # (DEFAULT: "This is a Rust server running inside a Docker container!" - The publicly visible server description)
      RUST_SERVER_DESCRIPTION="${server_description}"

      # (DEFAULT: "https://hub.docker.com/r/didstopia/rust-server/" - The publicly visible server website)
      # RUST_SERVER_URL="https://hub.docker.com/r/didstopia/rust-server/"

      # (DEFAULT: "" - The publicly visible server banner image URL)
      # RUST_SERVER_BANNER_URL=""

      # (DEFAULT: "600" - Amount of seconds between automatic saves.)
      RUST_SERVER_SAVE_INTERVAL="600"

      # (DEFAULT "1" - Set to 1 or 0 to enable or disable the web-based RCON server)
      RUST_RCON_WEB="1"

      # (DEFAULT: "28016" - RCON server port)
      RUST_RCON_PORT="28016"

      # (DEFAULT: "docker" - RCON server password, please change this!)
      RUST_RCON_PASSWORD="${password}"

      # (DEFAULT: Not set - Sets the branch argument to use, eg. set to "-beta prerelease" for the prerelease branch)
      # RUST_BRANCH="-beta prerelease"

      # (DEFAULT: "0" - Set to 1 to enable fully automatic update checking, notifying players and restarting to install updates)
      RUST_UPDATE_CHECKING="0"

      # (DEFAULT: "public" - Set to match the branch that you want to use for updating, ie. "prerelease" or "public", but do not specify arguments like "-beta")
      RUST_UPDATE_BRANCH="public"

      # (DEFAULT: "0" - Determines if the server should update and then start (0), only update (1) or only start (2))
      RUST_START_MODE="0"

      # (DEFAULT: "0" - Set to 1 to automatically install the latest version of Oxide)
      RUST_OXIDE_ENABLED="1"

      # (DEFAULT: "1" - Set to 0 to disable automatic update of Oxide on boot)
      RUST_OXIDE_UPDATE_ON_BOOT="1"


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
            --region ${region} \
            --filters \
                Name=tag:Name,Values=${server_name}-persistent-volume \
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
          "awslogs-group": "${server_name}",
          "tag": "{{.Name}}-{{.ID}}"
        }
      }

  - path: /etc/cloudwatch/config.json
    content: |
      {
        "metrics": {
          "aggregation_dimensions": [
            ["AutoScalingGroupName"],
            ["InstanceId"]
          ],
          "append_dimensions": {
            "AutoScalingGroupName": "$${aws:AutoScalingGroupName}",
            "InstanceId": "$${aws:InstanceId}"
          },
          "metrics_collected": {
            "cpu": {
              "measurement": [
                "cpu_usage_idle",
                "cpu_usage_iowait",
                "cpu_usage_user",
                "cpu_usage_system"
              ],
              "metrics_collection_interval": 60,
              "totalcpu": true
            },
            "mem": {
              "measurement": [
                "mem_used_percent"
              ],
              "metrics_collection_interval": 60
            },
            "swap": {
              "measurement": [
                "swap_used_percent"
              ],
              "metrics_collection_interval": 60
            },
            "disk": {
              "resources": [
                "/"
              ],
              "measurement": [
                "disk_used_percent"
              ],
              "metrics_collection_interval": 60
            }
          }
        }
      }
