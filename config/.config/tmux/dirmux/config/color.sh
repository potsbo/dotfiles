#!/usr/bin/env bash
# Output the host-specific main color.
#
# Usage: color.sh
#
# Examples:
#   color.sh  → "#fd971f"  (on tigerlake)
#   color.sh  → "#797979"  (on unknown host)
set -eu

case $(hostname) in
"tigerlake")    echo "#fd971f" ;;  # yellow
"raptorlake")   echo "#f8f8f2" ;;  # white
"avalanche.local") echo "#ae81ff" ;;  # purple
"phoenix")         echo "#d7875f" ;;  # orange
"staten-nix")      echo "#f92672" ;;  # red
"blizzard.local")  echo "#55bed2" ;;  # cyan
*)              echo "#797979" ;;  # gray
esac
