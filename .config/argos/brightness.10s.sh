#!/bin/bash

BRIGHTNESS=$(brightnessctl get)
MAX=$(brightnessctl max)
PERCENT=$((100 * BRIGHTNESS / MAX))

echo "💡 $PERCENT% | scroll=brightnessctl set +5% scrollup=brightnessctl set +5% scrolldown=brightnessctl set 5%-"
