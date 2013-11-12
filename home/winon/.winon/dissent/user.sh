#!/bin/bash
chromium-browser http://5.1.0.1:8080/dir?file=index.html \
  http://www.cnn.com \
  http://www.youtube.com &
xterm &
exit 0
