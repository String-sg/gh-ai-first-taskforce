detect_language() {
  local root="$1"
  if [ -f "$root/package.json" ] && [ -f "$root/go.mod" ]; then
    echo "mixed"
  elif [ -f "$root/package.json" ]; then
    echo "js"
  else
    echo "unsupported"
  fi
}
