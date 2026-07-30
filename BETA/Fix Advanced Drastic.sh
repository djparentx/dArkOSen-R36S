#!/bin/bash

echo "==================================="
echo " Fix for Advanced Drastic"
echo "==================================="
echo ""
echo "fixing file ownership..."

sudo chown -R ark:ark /opt/advanceddrastic
sleep 1

echo ""
echo "fixed."
sleep 2