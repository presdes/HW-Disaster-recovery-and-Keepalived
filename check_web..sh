#!/bin/bash
# Check: port 80 is listening, and index.html exists
if ss -tln | grep -q ":80 " && [ -f /var/www/html/index.html ]; then
    exit 0
else
    exit 1
fi