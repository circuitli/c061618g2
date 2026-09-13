#!/bin/bash
# run_batch.sh (Run this directly on your host terminal)

#export PDK_ROOT="/absolute/path/to/your/host/pdk"
#export PDK_TARGET="ihp-sg13g2"
CONTAINER_NAME="librelane_worker"

# 1. Spin up ONE container in the background and keep it idling
echo "Starting background tool container..."
docker run -d --name $CONTAINER_NAME --rm \
  -v "$(pwd)":"$(pwd)" \
  -v "$PDK_ROOT":"$PDK_ROOT" \
  -e PDK_ROOT="$PDK_ROOT" \
  -w "$(pwd)" \
  --entrypoint /bin/sleep \
  ghcr.io/librelane/librelane:3.0.5 \
  infinity

# 2. Instantly pipe your multiple JSON files through it sequentially
#    (No container startup overhead!)
for config in macro_a.json macro_b.json config.json; do
    echo "--------------------------------------------------------"
    echo " Processing: $config"
    echo "--------------------------------------------------------"
    docker exec $CONTAINER_NAME \
      python3 -m librelane --manual-pdk --pdk $PDK_TARGET "$config"
done

# 3. Clean up when finished
echo "Stopping container..."
docker stop $CONTAINER_NAME
