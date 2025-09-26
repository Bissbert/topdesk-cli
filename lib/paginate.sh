#!/bin/sh
set -eu

# Helper to merge newline-delimited key=value pairs into a query string.
paginate_apply_params() {
  _pa_base=${1-}
  _pa_params=${2-}
  query_apply_params "${_pa_base}" "${_pa_params}"
}

paginate_json() {
  call_bin=$1
  path=$2
  base_qs=${3-}
  page_param=$4
  offset_param=$5
  page_size=$6
  limit=${7-}

  jq_require "paginated json output"

  (
    total=0
    start=${TDX_OFFSET_START:-0}
    while :; do
      q=$(query_add "${base_qs}" "${page_param}" "${page_size}")
      q=$(query_add "$q" "${offset_param}" "$start")
      page_json=$("$call_bin" GET "$path" --query "$q" --raw)
      count=$(printf '%s' "$page_json" | jq 'length' 2>/dev/null || echo 0)
      [ "$count" -eq 0 ] && break
      if [ -n "$limit" ]; then
        remain=$((limit - total))
        [ "$remain" -le 0 ] && break
        if [ "$remain" -lt "$count" ]; then
          printf '%s' "$page_json" | jq -c --argjson limit "$remain" '.[:$limit][]'
          total=$((total + remain))
          break
        fi
      fi
      printf '%s' "$page_json" | jq -c '.[]'
      total=$((total + count))
      [ "$count" -lt "$page_size" ] && break
      if [ -n "$limit" ] && [ "$total" -ge "$limit" ]; then break; fi
      start=$((start + page_size))
    done
  ) | jq -s '.'
}

paginate_tabular() {
  call_bin=$1
  path=$2
  base_qs=${3-}
  fields=$4
  format=$5
  headers=$6
  page_param=$7
  offset_param=$8
  page_size=$9
  limit=${10-}

  jq_require "--format ${format}"

  printer='@tsv'
  [ "$format" = csv ] && printer='@csv'

  jq_fields=$(jq_field_extractor "$fields")
  if [ "$headers" = 1 ]; then
    jq_header=$(jq_header_array "$fields")
    printf '%s\n' "$jq_header" | jq -r "$printer"
  fi

  total=0
  start=${TDX_OFFSET_START:-0}
  while :; do
    q=$(query_add "${base_qs}" "${page_param}" "${page_size}")
    q=$(query_add "$q" "${offset_param}" "$start")
    page_json=$("$call_bin" GET "$path" --query "$q" --raw)
    count=$(printf '%s' "$page_json" | jq 'length' 2>/dev/null || echo 0)
    [ "$count" -eq 0 ] && break
    if [ -n "$limit" ]; then
      remain=$((limit - total))
      [ "$remain" -le 0 ] && break
      if [ "$remain" -lt "$count" ]; then
        jq_prog='.[:$limit] | .[] | ['"$jq_fields"'] | '"$printer"
        printf '%s' "$page_json" | jq -r --argjson limit "$remain" "$jq_prog"
        total=$((total + remain))
        break
      fi
    fi
    jq_prog='.[] | ['"$jq_fields"'] | '"$printer"
    printf '%s' "$page_json" | jq -r "$jq_prog"
    total=$((total + count))
    [ "$count" -lt "$page_size" ] && break
    if [ -n "$limit" ] && [ "$total" -ge "$limit" ]; then break; fi
    start=$((start + page_size))
  done
}

