#!/bin/bash

echo "Restoring updates..."
sudo mv /usr/local/bin/Update.sh.bak /usr/local/bin/Update.sh

echo "Done."
sudo rm -f "$0"