---
title: Install & Configure Grafana Promtail
description: How to ship logs from multiple servers and use a nice interface to query access logs? Promtail is the right tool in order to use the powerful Grafana platform. 
date: '2021-12-21'
pic: '/img/blog/promtail_squer.jpg'
tags: ['Logs', 'Grafana', 'DevOps', 'Monitoring']
---

# Install & Configure Promtail for Grafana Loki
---
This post will demonstrate a reliable and easy way to install Promtail to your server in order to collect all system logs in a central place for proper monitoring.  
*NOTE:* This post will only cover the install and setup for Linux based systems

![pic](/img/blog/promtail.jpg)


## About Promtail
Promtail is part of the Grafana platform. The Grafana platform is increasing in popularity due to its open-source nature, easy usability and ability to plug into existing infrastructure. Grafana allows to visualize and query data from multiple sources. The data can be stored in [InfluxDB](https://grafana.com/docs/grafana/latest/datasources/influxdb/), [ELK](https://grafana.com/docs/grafana/latest/datasources/elasticsearch/), [Prometheus](https://grafana.com/docs/grafana/latest/datasources/prometheus/) or the in-house [Loki](https://grafana.com/docs/loki/latest/) data store. Loki is often called the Prometheus version of logs. But to query log-data in Loki over Grafana, the logs have to be shipped first. For Docker, this can easily be done with the [Docker Loki Log-Driver](https://grafana.com/docs/loki/latest/), but what about logs of none dockerized applications or logs of the host system? This is where Promtail comes in! It constantly reads log-files (e.g. in `/var/log`) and sends them to a Loki instance.

## Installing Promtail
Promtail is available as a static binary on the official [Grafana Loki GitHub](https://github.com/grafana/loki/releases) page. We could download it by hand, *or* we could use the terminal like a real programmer:

```bash
# Download latest:
curl -s https://api.github.com/repos/grafana/loki/releases/latest | \
    grep browser_download_url | \
    cut -d '"' -f 4 | grep promtail-linux-amd64.zip | \
    wget -i -
# Unzip and
unzip promtail-linux-amd64.zip
mv promtail-linux-amd64 /usr/local/bin/promtail
# Verify
promtail --version

```
We are using the GitHub API to get the latest release of Promtail and are filtering for the `linux-and64` binary with `grep`. The result gets piped to `wget` in order to download the zip file. Subsequently, we unzip the archive and move it to a place that is in our `PATH`. Now we can test if Promtail is working.

Now we need a Promtail config:

```ymal
# Promtail config
server:
  disable: true

positions:
  filename: /tmp/promtail-positions.yaml

clients:
  - url: http://<SERVER>:3100/loki/api/v1/push

scrape_configs:
- job_name: authlog
  static_configs:
  - targets:
      - localhost
    labels:
      job: authlog
      shipper: promtail
      __path__: /var/log/auth.log

- job_name: daemonlog
  static_configs:
  - targets:
      - localhost
    labels:
      job: syslog
      shipper: promtail
      __path__: /var/log/daemon.log
```

Our Promtail do not need to receive any logs we are just querying local files, so we can disable the server. The positions-file is a marker file for Promtail to remember where it stopped reading a log file, and the client is the destination of our logs. The `scrape_configs` specifies what logs Promtail should send to Loki. In this example, we are using `daemon.log` and `auth.log`. There are tones of other possibilities, like access logs from ´nginx´ and alike, but this would be too much for this post.

We could start Promtail with `promtail -config.file promtail-config.yml`, but we would have little control over the process, and it would not start again if the process fails or the host is restarted. So let's create separate user for Promtail (optional) and a service:

```bash
# Create promtail user
useradd -r promtail
usermod -a -G adm promtail
# Create a service
tee /etc/systemd/system/promtail.service<<EOF > /dev/null
[Unit]
Description=Promtail service
After=network.target

[Service]
Type=simple
User=promtail
ExecStart=/usr/local/bin/promtail -config.file /path/to/promtail-config.yml
Restart=always

[Install]
WantedBy=multi-user.target
EOF
```

Now we can simply run the following and have a reliable and good Promtail setup that can easily be automated with tools like Ansible or Puppet.
```bash
# Start the service
sudo systemctl daemon-reload
sudo systemctl enable promtail.service
sudo systemctl start promtail.service
# Verify status
sudo systemctl status promtail.service
```

**See you!**
