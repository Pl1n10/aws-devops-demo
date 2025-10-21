#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log) 2>&1

APP_NAME="${app_name}"
AWS_REGION="${aws_region}"
BACKUP_BUCKET="${backup_bucket}"
ARTIFACTS_BUCKET="${artifacts_bucket}"
IMAGE_REPO="${image_repo}"
IMAGE_TAG="${image_tag}"
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

apt-get update
apt-get upgrade -y
apt-get install -y docker.io awscli htop vim curl jq python3-pip unzip cron logrotate nginx

systemctl enable docker && systemctl start docker
systemctl enable cron && systemctl start cron
usermod -aG docker ubuntu

mkdir -p /var/log/app /opt/app /etc/app
chown -R ubuntu:ubuntu /var/log/app /opt/app

cat > /etc/app/environment <<EOC
APP_NAME=${APP_NAME}
AWS_REGION=${AWS_REGION}
BACKUP_BUCKET=${BACKUP_BUCKET}
ARTIFACTS_BUCKET=${ARTIFACTS_BUCKET}
IMAGE_REPO=${IMAGE_REPO}
IMAGE_TAG=${IMAGE_TAG}
INSTANCE_ID=${INSTANCE_ID}
EOC

# CloudWatch Agent
wget -q https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb && rm amazon-cloudwatch-agent.deb

mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<EOC
{
  "agent": { "metrics_collection_interval": 60, "run_as_user": "root", "region": "${AWS_REGION}" },
  "logs": {
    "logs_collected": {
      "files": { "collect_list": [
        { "file_path": "/var/log/app/app.log", "log_group_name": "/aws/ec2/${APP_NAME}", "log_stream_name": "{instance_id}/app", "timestamp_format": "%Y-%m-%d %H:%M:%S", "timezone": "UTC" },
        { "file_path": "/var/log/docker/*.log", "log_group_name": "/aws/ec2/${APP_NAME}", "log_stream_name": "{instance_id}/docker", "timestamp_format": "%Y-%m-%dT%H:%M:%S" },
        { "file_path": "/var/log/syslog", "log_group_name": "/aws/ec2/${APP_NAME}", "log_stream_name": "{instance_id}/syslog" }
      ] }
    }
  },
  "metrics": {
    "namespace": "CWAgent",
    "append_dimensions": { "InstanceId": "${INSTANCE_ID}", "InstanceType": "${INSTANCE_TYPE}" },
    "metrics_collected": {
      "cpu": { "measurement": ["cpu_usage_user","cpu_usage_system",{ "name":"cpu_usage_idle","rename":"CPU_IDLE","unit":"Percent"},{ "name":"cpu_usage_iowait","unit":"Percent"}], "metrics_collection_interval": 60, "resources": ["*"], "totalcpu": false },
      "disk": { "measurement": [{ "name":"used_percent","rename":"DISK_USED","unit":"Percent" },"disk_free"], "metrics_collection_interval": 60, "resources": ["/"], "ignore_file_system_types": ["sysfs","devtmpfs","tmpfs"] },
      "mem": { "measurement": [{ "name":"mem_used_percent","rename":"MEM_USED","unit":"Percent" },"mem_available"], "metrics_collection_interval": 60 },
      "net": { "measurement": ["net_bytes_sent","net_bytes_recv"], "metrics_collection_interval": 60, "resources": ["eth0"] }
    }
  }
}
EOC

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Placeholder app on 8080
cat > /opt/app/placeholder.py <<'EOC'
from http.server import HTTPServer, BaseHTTPRequestHandler
import json, datetime
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/healthz':
            self.send_response(200); self.send_header('Content-type','application/json'); self.end_headers()
            self.wfile.write(json.dumps({"status":"healthy","type":"placeholder","timestamp":str(datetime.datetime.now())}).encode())
        elif self.path == '/version':
            self.send_response(200); self.send_header('Content-type','application/json'); self.end_headers()
            self.wfile.write(json.dumps({"version":"placeholder","message":"Waiting for deployment"}).encode())
        else:
            self.send_response(200); self.send_header('Content-type','text/plain'); self.end_headers()
            self.wfile.write(b"DevOps Demo API - Placeholder on 8080")
httpd = HTTPServer(('',8080), H)
httpd.serve_forever()
EOC
nohup python3 /opt/app/placeholder.py > /var/log/app/placeholder.log 2>&1 &

# Nginx proxy 80->8080
cat > /etc/nginx/sites-available/default <<'EOC'
server {
  listen 80 default_server;
  location / { proxy_pass http://127.0.0.1:8080; proxy_set_header Host $host; }
}
EOC
systemctl restart nginx

# systemd service for Docker app
cat > /etc/systemd/system/app.service <<'EOC'
[Unit]
Description=DevOps Demo Application
After=docker.service network-online.target
Requires=docker.service
Wants=network-online.target

[Service]
Type=simple
Restart=always
RestartSec=10
User=ubuntu
Group=docker
EnvironmentFile=/etc/app/environment
WorkingDirectory=/opt/app
ExecStartPre=-/usr/bin/docker stop ${APP_NAME}
ExecStartPre=-/usr/bin/docker rm ${APP_NAME}
ExecStartPre=/usr/bin/docker pull ${IMAGE_REPO}:${IMAGE_TAG}
ExecStart=/usr/bin/docker run --rm --name ${APP_NAME} -p 80:80 \
  -v /var/log/app:/var/log/app \
  -e AWS_REGION=${AWS_REGION} -e BACKUP_BUCKET=${BACKUP_BUCKET} \
  -e APP_VERSION=${IMAGE_TAG} -e INSTANCE_ID=${INSTANCE_ID} \
  ${IMAGE_REPO}:${IMAGE_TAG}
ExecStop=/usr/bin/docker stop ${APP_NAME}

[Install]
WantedBy=multi-user.target
EOC

# health-check cron
cat > /opt/app/health-check.sh <<'EOC'
#!/bin/bash
URL="http://localhost/healthz"
CODE=$(curl -s -o /dev/null -w "%{http_code}" $URL)
if [ "$CODE" != "200" ]; then
  echo "$(date) - Health check failed: $CODE" >> /var/log/app/health-check.log
  systemctl restart app.service
else
  echo "$(date) - OK" >> /var/log/app/health-check.log
fi
EOC
chmod +x /opt/app/health-check.sh
(crontab -u ubuntu -l 2>/dev/null; echo "*/2 * * * * /opt/app/health-check.sh") | crontab -u ubuntu -

echo "User data completed."
