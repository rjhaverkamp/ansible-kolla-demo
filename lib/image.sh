#!/usr/bin/env bash
# Cloud-image fetch + integrity verification. Source me; do not execute.

# verify_checksum FILE EXPECTED_SHA256: succeed only if FILE matches EXPECTED_SHA256.
verify_checksum() {
  local file=$1 expected=$2 actual
  [[ -f $file ]] || {
    log_error "image not found: $file"
    return 1
  }
  actual=$(sha256sum "$file" | awk '{print $1}')
  if [[ $actual != "$expected" ]]; then
    log_error "checksum mismatch for $file"
    log_error "  expected: $expected"
    log_error "  actual:   $actual"
    return 1
  fi
  return 0
}

# fetch_image: download IMAGE_URL to IMAGE_PATH (cached) and verify when IMAGE_SHA256 is set.
fetch_image() {
  mkdir -p "$CACHE_DIR"

  if [[ -f $IMAGE_PATH ]]; then
    if [[ -n $IMAGE_SHA256 ]]; then
      if verify_checksum "$IMAGE_PATH" "$IMAGE_SHA256"; then
        log_info "cached image verified: $IMAGE_PATH"
        return 0
      fi
      log_warn "cached image failed checksum; re-downloading"
      rm -f "$IMAGE_PATH"
    else
      log_info "using cached image (no IMAGE_SHA256 set, not verified): $IMAGE_PATH"
      return 0
    fi
  fi

  log_info "downloading image: $IMAGE_URL"
  local tmp="${IMAGE_PATH}.part"
  if command -v wget >/dev/null 2>&1; then
    wget -q -O "$tmp" "$IMAGE_URL" || die "image download failed: $IMAGE_URL"
  else
    curl -fsSL -o "$tmp" "$IMAGE_URL" || die "image download failed: $IMAGE_URL"
  fi

  if [[ -n $IMAGE_SHA256 ]]; then
    verify_checksum "$tmp" "$IMAGE_SHA256" || {
      rm -f "$tmp"
      die "downloaded image failed checksum verification"
    }
  else
    log_warn "IMAGE_SHA256 not set; image integrity is NOT verified"
  fi

  mv "$tmp" "$IMAGE_PATH"
  log_info "image ready: $IMAGE_PATH"
}
