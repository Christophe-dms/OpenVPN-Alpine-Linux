#!/bin/sh
# modification des depots pour extension
# Vérifie si sed est installé, sinon l'installe
if ! command -v sed &> /dev/null; then
    apk add --no-cache sed
fi
#modification du depot APK
sed -i '\|/media/cdrom/apks|!s/^#//' /etc/apk/repositories
apk update
clear
#Recuperationdesdonnees
read -p "Entrer l'adresse IP Exterieure de la box [a.b.c.d]: " ipbox
read -p "Entrer le port Exterieur de la box pour le VPN: " portext
read -p "Entrer le port d'écoute du vpn: " portint
echo
read -s -p "Entrer votre mode passe pour l autorité de certification (a bien garder pour faire les certificats): " passca
echo
read -s -p "Confirmation votre mode passe pour l autorité de certification (a bien garder pour faire les certificats): " passcabis
echo 
if [ "$passca" != "$passcabis" ]; then
echo "--------- les mots de passes sont différents ---------- ARRET DU SCRIPT -------- "
exit 1
fi
read -p  "Entrer le nom du certificat pour les clients [client1]: " certiname
read -p "Voulez vous etablir une surveillance vers un broker Mqtt (Home assistant)-(o/n): " repbroker
if [ "$repbroker" = "o" ]; then
read -p "Enter adresse IP Home Assistant ou Broker Mqtt [z.y.x.w]: " ipha
read -p "Entrer User mosquitto: " mosquitto
read -s -p "Entrer mot de passe mosquitto: " mdpmosq
echo
fi
read -p "Voulez vous creer un user spécifique pour la gestion (o/n): " repuser
if [ "$repuser" = "o" ]; then
read -p "Entrer le nom: " nom
adduser -D $nom
read -s -p "Entrer le mot de passe :" passnom
echo "$nom:$passnom" | chpasswd
adduser $nom wheel
apk add sudo
mkdir -p /etc/sudoers.d
if ! grep -q "%wheel" /etc/sudoers /etc/sudoers.d/* 2>/dev/null; then
    echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
    chmod 440 /etc/sudoers.d/wheel
fi
fi
# installation de openvpn et easy-rsa
apk add openvpn easy-rsa
mkdir -p /etc/easy-rsa
cp -r /usr/share/easy-rsa/* /etc/easy-rsa/
#generer les cles
cd /etc/easy-rsa
./easyrsa init-pki
printf "%s\n%s\n" "$passca" "$passca" | ./easyrsa --batch build-ca
printf "%s\n%s\n" "server" | ./easyrsa gen-req server nopass
echo "yes" | EASYRSA_PASSIN="pass:$passca" ./easyrsa sign-req server server
./easyrsa gen-dh
openvpn --genkey tls-crypt /etc/openvpn/ta.key
echo "yes"| ./easyrsa gen-req "$certiname" nopass
echo "yes" | ./easyrsa --passin="pass:$passca" sign-req client "$certiname"
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
#creation du fichier client openvpn
# Creation du fichier client OpenVPN
{
cat <<EOF
client
dev tun
proto udp
# IP exterieure de la box et port entre
remote ${ipbox} ${portext}
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
cat "/etc/easy-rsa/pki/issued/${certiname}.crt"
cat <<EOF
</cert>
<key>
EOF
cat "/etc/easy-rsa/pki/private/${certiname}.key"
cat <<EOF
</key>
<tls-crypt>
EOF
cat /etc/openvpn/ta.key
cat <<EOF
</tls-crypt>
EOF
} >"/etc/openvpn/${certiname}.ovpn"

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
if [ "$repbroker" = "o" ];then
sh -c '{
cat <<EOF
[openvpn]
enabled  = true
port     = '$portint'
protocol = udp
filter   = openvpn
logpath  = /var/log/messages
maxretry = 3
findtime = 600
bantime  = 3600
action  = iptables-multiport[name=OpenVPN, port='$portint', protocol=udp]
          mqtt-notify[name=openvpn]

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
else
sh -c '{
cat <<EOF
[openvpn]
enabled  = true
port     = '$portint'
protocol = udp
filter   = openvpn
logpath  = /var/log/messages
maxretry = 3
findtime = 600
bantime  = 3600
action  = iptables-multiport[name=OpenVPN, port='$portint', protocol=udp]

[sshd]
enabled = true
port    = ssh
logpath = /var/log/messages
backend = %(sshd_backend)s
# Ajout de l action MQTT :
action  = iptables-multiport[name=SSH, port="ssh", protocol=tcp]
EOF
} > /etc/fail2ban/jail.local'
fi
sh -c '{
cat <<EOF
[INCLUDES]
before = common.conf

[Definition]
failregex = ^%(__prefix_line)s.*<HOST>:?\d* (?:TLS Error: TLS handshake failed|TLS Error: Auth Username/Password Failed|VERIFY ERROR:.*|TLS Error: cannot locate HMAC checksum file.*|Connection reset, restarting.*)$
            ^%(__prefix_line)s.*tls-crypt unwrap error: packet authentication failed from \[AF_INET\]<HOST>:\d+
            ^%(__prefix_line)s.*TLS Error: tls-crypt unwrapping failed from \[AF_INET\]<HOST>:\d+
            ^%(__prefix_line)s.*TLS Error: incoming packet authentication failed from \[AF_INET\]<HOST>:\d+
            ^.* Peer Connection Initiated with \[AF_INET\]<HOST>:\d+

ignoreregex =
EOF
} > /etc/fail2ban/filter.d/openvpn.conf'
if [ "$repbroker" = "o" ];then 
apk add mosquitto-clients
cat << EOF > /etc/fail2ban/action.d/mqtt-notify.conf
[Definition]

actionban = mosquitto_pub -h '$ipha' -u '$mosquitto' -P '$mdpmosq' \
              -t "alpine/fail2ban/<name>" \
              -m '{"ip": "<ip>", "jail": "<name>", "failures": "<failures>", "status": "banned"}'

# Optionnel : notifier lors du débannissement
actionunban = mosquitto_pub -h '$ipha' -u '$mosquitto' -P '$mdpmosq' \
                -t "alpine/fail2ban/<name>" \
                -m '{"ip": "<ip>", "jail": "<name>", "status": "unbanned"}'
EOF
fi
rc-service fail2ban start
rc-update add fail2ban 
#ajustement FSTAB pour que les lectures/ecritures du fichier log se fasse en RAM pour economiser la carte SD
echo "tmpfs /var/log tmpfs defaults,noatime,nosuid,nodev,size=50M 0 0" >> /etc/fstab
#activation immediate du parametre tmpfs
mount /var/log
# utilisation de logrotate pour gerer le depassement de 50Mo
apk add logrotate
echo "# Safety limit: rotate immediately if a log reaches 10M " >> /etc/logrotate.conf
echo "size 10M" >> /etc/logrotate.conf
rc-service openvpn start
echo "***** IMPORTANT ****** recuperer votre certificat après le reboot dans ------>  /etc/openvpn"
echo "***** Redemarrage necessaire prenez bien connaissance de recuperer votre certificat dans /etc/openvpn avec le nom que vous avez indiqué"
read -n 1 -s -p "***** Appuyez sur une touche pour continuer... un reboot va commencer ..."
reboot




