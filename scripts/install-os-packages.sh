#!/usr/bin/env bash

set -e

packages="awslogs jq aws-cfn-bootstrap ntp"

sudo yum -y -x docker\* -x ecs\* update

echo "### Installing packages: $packages ###"
sudo yum -y install $packages
