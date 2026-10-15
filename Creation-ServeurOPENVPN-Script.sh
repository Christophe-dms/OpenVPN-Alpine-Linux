#Recuperationdesdonnees
read -p "Entrer l'adresse IP Exterieure de la box [a.b.c.d]: " ipbox
read -p "Entrer le port Exterieur de la box pour le VPN: " portext
read -p "Entrer le port d'écoute du vpn: " portint
read -p "Enter adresse IP Home Assistant ou Broker Mqtt [z.y.x.w]: " ipha
read -p "Entrer User mosquitto: " mosquitto
read -s -p "Entrer mot de passe mosquitto: " mdpmosq
#modification du depot APK
sudo sed -i '!\/media/cdrom/apks!! s/^#//' /etc/apk/repositories
apk update
# installation de openvpn et easy-rsa
apk add openvpn easy-rsa
mkdir -p /etc/easy-rsa
cp -r /usr/share/easy-rsa/* /etc/easy-rsa/
#generer les cles
cd /etc/easy-rsa
./easyrsa init-pki
./easyrsa build-ca
./easyrsa gen-req server nopass
./easyrsa sign-req server server
./easyrsa gen-dh
openvpn --genkey tls-crypt /etc/openvpn/ta.key
./easyrsa gen-req client1 nopass
./easyrsa sign-req client client1
mkdir -p /etc/openvpn/server
cp /etc/easy-rsa/pki/ca.crt /etc/openvpn/server/
cp /etc/easy-rsa/pki/issued/server.crt /etc/openvpn/server/
cp /etc/easy-rsa/pki/private/server.key /etc/openvpn/server/
cp /etc/easy-rsa/pki/dh.pem /etc/openvpn/server/
cp /etc/openvpn/ta.key /etc/openvpn/server/
modprobe tun
sh -c '{
cat << EOF
port '$portint'
proto udp
dev tun
server 10.8.0.0 255.255.255.0
ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/server.crt
key /etc/openvpn/server/server.key
dh /etc/openvpn/server/dh.pem
tls-crypt /etc/openvpn/server/ta.key
topology subnet
push "route 192.168.1.0 255.255.255.0"
keepalive 10 120
user nobody
group nogroup
persist-key
persist-tun
verb 3
data-ciphers AES-256-GCM:AES-128-GCM
EOF
} > /etc/openvpn/server/server.conf'
#creation du fichier client1.openvpn
sh -c '{
cat <<EOF
client
dev tun
proto udp
#Remplacer 1.2.3.4 par IP exterieure Box
remote '$ipbox' '$portext'
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth-nocache
data-ciphers AES-256-GCM:AES-128-GCM
verb 3
      
<ca>
EOF
cat /etc/easy-rsa/pki/ca.crt
cat <<EOF
</ca>
      
<cert>
EOF
cat /etc/easy-rsa/pki/issued/client1.crt
cat <<EOF
</cert>
      
<key>
EOF
cat /etc/easy-rsa/pki/private/client1.key
cat <<EOF
</key>
      
<tls-crypt>
EOF
cat /etc/openvpn/ta.key
cat <<EOF
</tls-crypt>
EOF
} > /etc/openvpn/client1.ovpn'
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -w net.ipv4.ip_forward=1
apk add iptables
mkdir -p /etc/iptables
sh -c '{
cat <<EOF
#!/bin/sh
# Nettoyage des règles précédentes
iptables -F
iptables -t nat -F

# NAT du réseau VPN vers eth0
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE

# Autoriser le trafic VPN -> réseau local
iptables -A FORWARD -i tun0 -o eth0 -s 10.8.0.0/24 -d 192.168.1.0/24 -j ACCEPT

# Autoriser les réponses réseau local -> VPN
iptables -A FORWARD -i eth0 -o tun0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
EOF
} > /etc/iptables/rules.sh'
chmod +x /etc/iptables/rules.sh
sh -c '{
cat <<EOF
#!/sbin/openrc-run

name="iptables-vpn"
description="iptables rules for OpenVPN"

depend() {
    need net
    after firewall
}

start() {
    ebegin "Loading OpenVPN iptables rules"
    /etc/iptables/rules.sh
    eend $?
}
EOF
} > /etc/init.d/iptables-vpn' 
chmod +x /etc/init.d/iptables-vpn
rc-update add iptables-vpn default
ln -s /etc/openvpn/server/server.conf /etc/openvpn/openvpn.conf
rc-update add openvpn default
apk add fail2ban
sh -c '{
cat <<EOF
[openvpn]
enabled  = true
port     = '$portext'
protocol = udp
filter   = openvpn
logpath  = /var/log/messages
maxretry = 3
findtime = 600
bantime  = 3600

[sshd]
enabled = true
port    = ssh
logpath = /var/log/messages
backend = %(sshd_backend)s
# Ajout de l action MQTT :
action  = iptables-multiport[name=SSH, port="ssh", protocol=tcp]
          mqtt-notify[name=ssh]
EOF
} > /etc/fail2ban/jail.local'

sh -c '{
cat <<EOF
[INCLUDES]
before = common.conf

[Definition]
failregex = ^%(__prefix_line)s.*<HOST>:?\d* (?:TLS Error: TLS handshake failed|TLS Error: Auth Username/Password Failed|VERIFY ERROR:.*|TLS Error: cannot locate HMAC checksum file.*|Connection reset, restarting.*)$
            ^%(__prefix_line)s.*tls-crypt unwrap error: packet authentication failed from \[AF_INET\]<HOST>:\d+
            ^%(__prefix_line)s.*TLS Error: tls-crypt unwrapping failed from \[AF_INET\]<HOST>:\d+
            ^%(__prefix_line)s.*TLS Error: incoming packet authentication failed from \[AF_INET\]<HOST>:\d+

ignoreregex =
EOF
} > /etc/fail2ban/filter.d/openvpn.conf'

cat << 'EOF' > /etc/fail2ban/action.d/mqtt-notify.conf
[Definition]

actionban = mosquitto_pub -h 'ipha' -u 'mosquitto' -P 'mdpmosq' \
              -t "alpine/fail2ban/<name>" \
              -m '{"ip": "<ip>", "jail": "<name>", "failures": "<failures>", "status": "banned"}'

# Optionnel : notifier lors du débannissement
actionunban = mosquitto_pub -h IP_BROKER -u USER -P PASS \
                -t "alpine/fail2ban/<name>" \
                -m '{"ip": "<ip>", "jail": "<name>", "status": "unbanned"}'
EOF

rc-service fail2ban start
rc-update add fail2ban 

apk add mosquitto-clients

rc-service openvpn start
