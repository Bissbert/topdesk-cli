#!/bin/sh
set -eu

json_escape_stream() {
  awk 'BEGIN { ORS=""; printf "\"" }
       {
         gsub(/\\/, "\\\\");
         gsub(/"/, "\\\"");
         gsub(/\r/, "\\r");
         gsub(/\t/, "\\t");
         if (NR > 1) { printf "\\n"; }
         printf "%s", $0
       }
       END { printf "\"" }'
}
