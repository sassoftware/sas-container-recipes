#! /bin/bash -e

# This script will check to make sure the ESP server pubsub port is up and running
# If we get a response that contains "Connected" then return 0 (healthy)
# else return 1 (not healthy)

return_code=1
nc_test=$(echo "test" | nc -v localhost 31416 2>&1)
if [[ $nc_test == *"Connected"* ]]; then
    return_code=0
fi

exit $return_code