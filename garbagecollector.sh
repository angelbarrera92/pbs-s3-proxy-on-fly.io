#!/bin/sh

echo "Starting garbage collector script..."

# Source environment variables
if [ -f /etc/environment ]; then
    # Use set -a to automatically export all variables
    set -a

    # Source the file which now contains properly escaped variables
    source /etc/environment 2>/dev/null || {
        echo "Warning: Could not source /etc/environment, some variables may not be available"
    }
    
    set +a
fi

# Ensure the environment variables are set
if [ -z "$PBS_GC_ACCESS_KEY" ] || [ -z "$PBS_GC_SECRET_KEY" ] || [ -z "$PBS_GC_ENDPOINT" ] || [ -z "$PBS_GC_BUCKET" ] || [ -z "$PBS_GC_RETENTION" ]; then
    echo "Error: Required environment variables are not set."
    echo "PBS_GC_ACCESS_KEY: $PBS_GC_ACCESS_KEY"
    echo "PBS_GC_SECRET_KEY: ${PBS_GC_SECRET_KEY:0:3}***${PBS_GC_SECRET_KEY: -3}"
    echo "PBS_GC_ENDPOINT: $PBS_GC_ENDPOINT"
    echo "PBS_GC_BUCKET: $PBS_GC_BUCKET"
    echo "PBS_GC_RETENTION: $PBS_GC_RETENTION"
    echo "Please set the required environment variables."
    exit 1
fi

/garbagecollector -accesskey $PBS_GC_ACCESS_KEY -secretkey $PBS_GC_SECRET_KEY -endpoint $PBS_GC_ENDPOINT -bucket $PBS_GC_BUCKET -retention $PBS_GC_RETENTION -usessl
echo "Garbage collector script completed."
