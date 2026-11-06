#!/bin/sh

if [ ! -f /etc/ocserv/certs/server-key.pem ] || [ ! -f /etc/ocserv/certs/server-cert.pem ]; then
	# Check environment variables
	if [ -z "$CA_CN" ]; then
		CA_CN="VPN CA"
	fi

	if [ -z "$CA_ORG" ]; then
		CA_ORG="Big Corp"
	fi

	if [ -z "$CA_DAYS" ]; then
		CA_DAYS=9999
	fi

	if [ -z "$SRV_CN" ]; then
		SRV_CN="www.example.com"
	fi

	if [ -z "$SRV_ORG" ]; then
		SRV_ORG="MyCompany"
	fi

	if [ -z "$SRV_DAYS" ]; then
		SRV_DAYS=9999
	fi

	# No certification found, generate one
	mkdir /etc/ocserv/certs
	cd /etc/ocserv/certs
	certtool --generate-privkey --outfile ca-key.pem
	cat > ca.tmpl <<-EOCA
	cn = "$CA_CN"
	organization = "$CA_ORG"
	serial = 1
	expiration_days = $CA_DAYS
	ca
	signing_key
	cert_signing_key
	crl_signing_key
	EOCA
	certtool --generate-self-signed --load-privkey ca-key.pem --template ca.tmpl --outfile ca.pem
	certtool --generate-privkey --outfile server-key.pem 
	cat > server.tmpl <<-EOSRV
	cn = "$SRV_CN"
	organization = "$SRV_ORG"
	expiration_days = $SRV_DAYS
	signing_key
	encryption_key
	tls_www_server
	EOSRV
	certtool --generate-certificate --load-privkey server-key.pem --load-ca-certificate ca.pem --load-ca-privkey ca-key.pem --template server.tmpl --outfile server-cert.pem
fi

# Create or update the VPN user from environment variables
if [ -n "$VPN_USER" ] || [ -n "$VPN_PASSWORD" ]; then
	if [ -z "$VPN_USER" ] || [ -z "$VPN_PASSWORD" ]; then
		echo "Error: VPN_USER and VPN_PASSWORD must be set together" >&2
		exit 1
	fi
	printf '%s\n%s\n' "$VPN_PASSWORD" "$VPN_PASSWORD" \
		| ocpasswd -c /etc/ocserv/ocpasswd "$VPN_USER" \
		|| exit 1
	echo "VPN user '$VPN_USER' configured"
fi

if [ ! -s /etc/ocserv/ocpasswd ]; then
	echo "Error: no VPN users found. Set VPN_USER and VPN_PASSWORD, or mount an ocpasswd file at /etc/ocserv/ocpasswd" >&2
	exit 1
fi

# Parse a boolean environment variable: is_enabled NAME DEFAULT
is_enabled() {
	eval "val=\${$1:-$2}"
	case "$(printf '%s' "$val" | tr 'A-Z' 'a-z')" in
		1|true|yes|on) return 0 ;;
		0|false|no|off) return 1 ;;
		*)
			echo "Error: $1 must be true or false, got '$val'" >&2
			exit 1
			;;
	esac
}

# DTLS (UDP transport); disabled means TCP/TLS only
if is_enabled DTLS true; then
	sed -i 's/^#\{0,1\}udp-port = .*/udp-port = 443/' /etc/ocserv/ocserv.conf
	echo "DTLS enabled"
else
	sed -i 's/^udp-port = /#udp-port = /' /etc/ocserv/ocserv.conf
	echo "DTLS disabled"
fi

# Compression (LZS / LZ4)
if is_enabled COMPRESSION true; then
	sed -i 's/^#\{0,1\}compression = .*/compression = true/' /etc/ocserv/ocserv.conf
	echo "Compression enabled"
else
	sed -i 's/^#\{0,1\}compression = .*/compression = false/' /etc/ocserv/ocserv.conf
	echo "Compression disabled"
fi

# Configure camouflage (server looks like a plain web server without the secret)
if [ -n "$CAMOUFLAGE_SECRET" ]; then
	case "$CAMOUFLAGE_SECRET" in
		*[!A-Za-z0-9._~-]*)
			echo "Error: CAMOUFLAGE_SECRET may only contain letters, digits and . _ ~ -" >&2
			exit 1
			;;
	esac
	sed -i \
		-e 's/^#\{0,1\}camouflage = .*/camouflage = true/' \
		-e "s/^#\{0,1\}camouflage_secret = .*/camouflage_secret = \"$CAMOUFLAGE_SECRET\"/" \
		/etc/ocserv/ocserv.conf
	if [ -n "$CAMOUFLAGE_REALM" ]; then
		REALM=$(printf '%s' "$CAMOUFLAGE_REALM" | tr -d '"\\' | sed -e 's/[/&]/\\&/g')
		sed -i "s/^#\{0,1\}camouflage_realm = .*/camouflage_realm = \"$REALM\"/" /etc/ocserv/ocserv.conf
	fi
	echo "Camouflage enabled, connect with https://<server>/?<CAMOUFLAGE_SECRET>"
else
	sed -i 's/^camouflage = .*/camouflage = false/' /etc/ocserv/ocserv.conf
fi

# Open ipv4 ip forward
sysctl -w net.ipv4.ip_forward=1

# Enable NAT forwarding
iptables -t nat -A POSTROUTING -j MASQUERADE
iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

# Enable TUN device
mkdir -p /dev/net
mknod /dev/net/tun c 10 200
chmod 600 /dev/net/tun

# Run OpennConnect Server
exec "$@"
