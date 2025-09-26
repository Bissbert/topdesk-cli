#!/bin/sh
set -eu

jq_require() {
  command_exists jq || { err "jq is required for %s" "${1:-this operation}"; exit 2; }
}

jq_trim_fields() {
  _jq_tf_input=${1-}
  _jq_tf_out=""
  OLDIFS=$IFS
  IFS=','
  for _jq_tf_field in $_jq_tf_input; do
    IFS=$OLDIFS
    _jq_tf_clean=$(printf '%s' "$_jq_tf_field" | sed 's/^ *//; s/ *$//')
    [ -z "$_jq_tf_clean" ] && { IFS=','; continue; }
    if [ -z "$_jq_tf_out" ]; then
      _jq_tf_out=$_jq_tf_clean
    else
      _jq_tf_out="$_jq_tf_out,$_jq_tf_clean"
    fi
    IFS=','
  done
  IFS=$OLDIFS
  printf '%s' "$_jq_tf_out"
}

jq_field_extractor() {
  _jq_fe_input=$(jq_trim_fields "${1-}")
  _jq_fe_prog=""
  OLDIFS=$IFS
  IFS=','
  for _jq_fe_field in $_jq_fe_input; do
    IFS=$OLDIFS
    [ -n "$_jq_fe_field" ] || { IFS=','; continue; }
    _jq_fe_piece="(.${_jq_fe_field}? // \"\")"
    if [ -z "$_jq_fe_prog" ]; then
      _jq_fe_prog=$_jq_fe_piece
    else
      _jq_fe_prog="$_jq_fe_prog, $_jq_fe_piece"
    fi
    IFS=','
  done
  IFS=$OLDIFS
  printf '%s' "$_jq_fe_prog"
}

jq_header_array() {
  _jq_ha_input=$(jq_trim_fields "${1-}")
  printf '['
  OLDIFS=$IFS
  IFS=','
  _jq_ha_first=1
  for _jq_ha_field in $_jq_ha_input; do
    IFS=$OLDIFS
    [ -n "$_jq_ha_field" ] || { IFS=','; continue; }
    [ $_jq_ha_first -eq 0 ] && printf ',' || _jq_ha_first=0
    printf '"%s"' "$_jq_ha_field"
    IFS=','
  done
  IFS=$OLDIFS
  printf ']'
}

