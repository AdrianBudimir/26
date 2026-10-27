#!/usr/bin/env bash
set -euo pipefail

# 1. Require root privileges
if [ "${EUID}" -ne 0 ]; then
  echo "[-] This script must be run as root. Try: sudo bash $0" >&2
  exit 1
fi

CERT_NAME="trimble-sc-ca"
CERT_DEST="/usr/local/share/ca-certificates/${CERT_NAME}.crt"

echo "[+] Writing CA certificate to ${CERT_DEST}..."
cat << 'EOF' > "${CERT_DEST}"
-----BEGIN CERTIFICATE-----
MIIDrTCCApWgAwIBAgIQW85sqk+s/oFHFUuoytc4wDANBgkqhkiG9w0BAQsFADBK
MRMwEQYKCZImiZPyLGQBGRYDbmV0MRswGQYKCZImiZPyLGQBGRYLdHJpbWJsZWNv
cnAxFjAUBgNVBAMTDVRyaW1ibGUtU0MtQ0EwIBcNMTQwNDI0MTYxMjAwWhgPMjA1
MTA0MjcxMDExNDJaMEoxEzARBgoJkiaJk/IsZAEZFgNuZXQxGzAZBgoJkiaJk/Is
ZAEZFgt0cmltYmxlY29ycDEWMBQGA1UEAxMNVHJpbWJsZS1TQy1DQTCCASIwDQYJ
KoZIhvcNAQEBBQADggEPADCCAQoCggEBANqL5NCE2dNry++sEailNG4RLbPzhUio
ptF+lkmIv1bPF0LZtWRuCjYqDpSzkAAMwn+d5vk4V0JFZBMgF8XCNEJ4tgAh6AOQ
Idb1/KVdtercOzzkzl6G9O9WAQOJjy5YSWAuSaDUwh+Tkj3yEfl67i6vlHY5SX3A
tJsW5sqQpOMSsA371yVqqFb6NRay6eQey/RvA44wkje2m+K4iOVSLiJ8lzzarrEj
+bGRVqCcdt+82u0hCXBZSg+6aUGkGNs7OfQC0F2OwUMZ8DNm2pbABcS6PThc5yab
LU7fOGuWFDitRA6DwenwbOUNiDFuIBlGmZW0XRNNUJPAZKuZf7bOTW8CAwEAAaOB
jDCBiTATBgkrBgEEAYI3FAIEBh4EAEMAQTALBgNVHQ8EBAMCAUYwDwYDVR0TAQH/
BAUwAwEB/zAdBgNVHQ4EFgQUhaPgolX7hzqqza4gfZptMjlM0UowEAYJKwYBBAGC
NxUBBAMCAQEwIwYJKwYBBAGCNxUCBBYEFMQcrIwDkCWe/XJKtY5A+mIl9+/DMA0G
CSqGSIb3DQEBCwUAA4IBAQCtvL97FXC8v/U6XF2iZN+xyzuy7JP5aaJEbC7NMLJM
W4AUtw8fPPLgmHeYlx9nmT62oEu487rU/Ny2FS91+U9gXzxFvg9MAaV+voUNhqdU
0nNntJTP5aT5oK7Vet10yNcRC6Gc5Tyx5ipZZbBxmxnCaZfvU65Mfoj4e19XHJ9D
x9Cxs7HaRnFz1rZ5u3e6VGUbXFYza/BUnBiXPj68O78ddsWzqU93EGxgCRlKUCyy
iI2600RNLzaLHTNsS9iLvj9d+g6kNHpPVg62vbmbofrRH35AEs3NVF+wrKjhinws
5stJJvq4YZKrNSCnJ+z5WwnBcYMAvcpjvZolbrkOMIjR
-----END CERTIFICATE-----
EOF

chmod 644 "${CERT_DEST}"

# 2. Update system-wide certificate store
echo "[+] Updating system CA store..."
update-ca-certificates

# 3. Configure Firefox Enterprise Policies
# Enables Firefox to automatically trust system certificates (ImportEnterpriseRoots) 
# and explicitly registers the certificate file.
echo "[+] Configuring Firefox enterprise policies..."

POLICY_JSON='{
  "policies": {
    "ImportEnterpriseRoots": true,
    "Certificates": {
      "Install": [
        "'"${CERT_DEST}"'"
      ]
    }
  }
}'

# Native / APT Firefox policy location
mkdir -p /etc/firefox/policies
echo "${POLICY_JSON}" > /etc/firefox/policies/policies.json

# Snap Firefox policy location (Ubuntu 24.04 default)
if [ -d "/var/snap/firefox" ]; then
  mkdir -p /var/snap/firefox/common/policies
  echo "${POLICY_JSON}" > /var/snap/firefox/common/policies/policies.json
fi

# 4. Optional: Directly inject into existing user Firefox NSS databases via certutil
if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq && apt-get install -y -qq libnss3-tools >/dev/null 2>&1 || true
fi

if command -v certutil >/dev/null 2>&1; then
  echo "[+] Injecting certificate into user Firefox NSS profiles..."
  FIND_PATHS=(
    "/home/*/.mozilla/firefox/*.default*"
    "/home/*/snap/firefox/common/.mozilla/firefox/*.default*"
    "/root/.mozilla/firefox/*.default*"
    "/root/snap/firefox/common/.mozilla/firefox/*.default*"
  )

  for pattern in "${FIND_PATHS[@]}"; do
    for profile in $pattern; do
      if [ -d "${profile}" ]; then
        certutil -A -n "Trimble-SC-CA" -t "TCu,Cu,Tu" -i "${CERT_DEST}" -d "sql:${profile}" 2>/dev/null || true
      fi
    done
  done
fi

echo "[✓] Certificate registration complete."