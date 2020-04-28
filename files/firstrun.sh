#!/usr/bin/env bash
set -e

echo "ECS_CLUSTER=${ECS_CLUSTER}" > /etc/ecs/ecs.config

if [ -n $PROXY_URL ]
then
  echo export HTTPS_PROXY=$PROXY_URL >> /etc/sysconfig/docker
  echo HTTP_PROXY=$PROXY_URL >> /etc/ecs/ecs.config
  echo NO_PROXY=169.254.169.254,169.254.170.2,/var/run/docker.sock >> /etc/ecs/ecs.config
  echo HTTP_PROXY=$PROXY_URL >> /etc/awslogs/proxy.conf
  echo HTTPS_PROXY=$PROXY_URL >> /etc/awslogs/proxy.conf
  echo NO_PROXY=169.254.169.254 >> /etc/awslogs/proxy.conf
fi

if [ $DOCKER_NETWORK_MODE = "host" ]
then
  sudo sed -i -e "s|^\(OPTIONS=\".*\)\"$|\1 --bridge=none --ip-forward=false --ip-masq=false --iptables=false\"|" \
    /etc/sysconfig/docker
fi

sudo tee /etc/awslogs/awscli.conf << EOF > /dev/null
[plugins]
cwlogs = cwlogs
[default]
region=${AWS_DEFAULT_REGION:-us-east-2}
timezone=${TIME_ZONE:-America/Los_Angeles}
EOF

sudo tee /etc/awslogs/awslogs.conf << EOF > /dev/null
[general]
state_file=/var/lib/awslogs/agent-state

[/var/log/demsg]
file=/var/log/demsg
log_group_name=${STACK_NAME}/ec2/${AUTOSCALING_GROUP}/var/log/demsg
log_stream_name={instance_id}

[/var/log/messages]
file=/var/log/messages
log_group_name=${STACK_NAME}/ec2/${AUTOSCALING_GROUP}/var/log/messages
log_stream_name={instance_id}
datetime_format=%Y-%m-%dT%H:%M:%S

[/var/log/docker]
file=/var/log/docker
log_group_name=${STACK_NAME}/ec2/${AUTOSCALING_GROUP}/var/log/docker
log_stream_name={instance_id}
datetime_format=%Y-%m-%dT%H:%M:%S.%f

[/var/log/ecs/ecs-init.log]
file=/var/log/ecs/ecs-init.log*
log_group_name=${STACK_NAME}/ec2/${AUTOSCALING_GROUP}/var/log/ecs/ecs-init
log_stream_name={instance_id}
datetime_format=%Y-%m-%dT%H:%M:%SZ
time_zone=UTC

[/var/log/ecs/ecs-agent.log]
file=/var/log/ecs/ecs-agent.log*
log_group_name=${STACK_NAME}/ec2/${AUTOSCALING_GROUP}/var/log/ecs/ecs-agent
log_stream_name={instance_id}
datetime_format=%Y-%m-%dT%H:%M:%SZ
time_zone=UTC
EOF

sudo service ecs stop

sudo cp /usr/lib/systemd/system/ecs.service /etc/systemd/system/ecs.service
sudo sed -i '/After=cloud-final.service/d' /etc/systemd/system/ecs.service
sudo systemctl daemon-reload

sudo service awslogsd start
sudo chkconfig docker on
sudo service docker start
sudo service ecs start

if [ -z ${ECS_CLUSTER} ]
then
  echo "Skipping ECS agent check as ECS_CLUSTER variable is not defined"
fi

echo "Checking ECS agent joined to ${ECS_CLUSTER}"
until [[ "$(curl --fail --silent http://localhost:51678/v1/metadata | jq '.Cluster // empty' -r -e)" == ${ECS_CLUSTER} ]]
do
  printf '.'
  sleep 5
done
echo "ECS agent successfully joined to ${ECS_CLUSTER}" 
