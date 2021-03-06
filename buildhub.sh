#!/bin/bash
# 2018-05-20
source .env
if [[ "$(docker images -q jupyterhub:latest)" == "" ]]; then
  echo "JupyterHub image does not exist."
else
  echo "Deleting Docker images..."
  docker rmi $(docker images -q jupyterhub:latest)
fi
echo "Creating network and volumes..."
make network volumes
if [[ ! -d secrets ]]; then
  if [ "$JUPYTERHUB_SSL" == "use_ssl_ss" ]; then
    ./create-certs.sh
  else
    if [ "$JUPYTERHUB_SSL" == "use_ssl_le" ]; then
      ./letsencrypt-certs.sh
    fi
  fi
fi
docker-compose build
# Get jupyterhub host IP address
echo "Obtaining JupyterHub host ip address..."
FILE1='secrets/jupyterhub_host_ip'
if [ -f $FILE1 ]; then
    rm $FILE1
else
    touch $FILE1
fi
unset JUPYTERHUB_SERVICE_HOST_IP
docker-compose up -d
echo "Saving data to $FILE1..."
echo "JUPYTERHUB_SERVICE_HOST_IP='`docker inspect --format '{{ .NetworkSettings.Networks.jupyterhubnet.IPAddress }}' jupyterhub`'" >> $FILE1
docker-compose down
echo 'Set Jupyterhub Host IP:'
cat $FILE1
source $FILE1
rm $FILE1
echo "JUPYTERHUB_SERVICE_HOST_IP is now set to:"
echo $JUPYTERHUB_SERVICE_HOST_IP
echo "..."
sed -i -e "s/REPLACE_IP/$JUPYTERHUB_SERVICE_HOST_IP/g" .env
docker rmi $(docker images -q jupyterhub:latest)
docker rmi $(docker images -q postgres-hub:latest)
docker rmi $(docker images -q jupyterhub-user:latest)
if [ ! -f singleuser/drive.jupyterlab-settings ]; then
    cp singleuser/drive.jupyterlab-settings-template singleuser/drive.jupyterlab-settings
fi
if [ ! -f userlist ]; then
    cp userlist-template userlist
fi
echo "Rebuilding images..."
docker-compose build
make notebook_image
if [ -f .env-e ]; then
    rm .env-e
fi
echo "Build complete!"
