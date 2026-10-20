#!/bin/sh
clear
afficher_menu() {
    clear
    echo "=============================="
    echo "       MENU PRINCIPAL         "
    echo "=============================="
    echo "1. Creation de certificat "
    echo "2. Revoquation de certificat "
    echo "3. liste des prisons "
    echo "4. Etat des prisons "
    echo "5. Port à l'écoute "
    }

# Boucle principale
while true; do
    afficher_menu
    read -p "Faites votre choix [1-5] : " choix

    case $choix in
        1)
            echo "Liste des certificats existants"
            cd /etc/openvpn
            ls *.ovpn
            echo "Creation d'un certificat"
            read -p "Donner un nom pour le certicat: " certifname
            read -p "Entrer l'adresse IP Exterieure de la box [a.b.c.d]: " ipbox
            read -p "Entrer le port Exterieur de la box pour le VPN: " portext
            #generation des clés pour le certificat dans /etc/easy-rsa/pki issued et private
            echo "yes"| ./easyrsa gen-req "$certifname" nopass
            echo "yes" | ./easyrsa --passin="pass:$passca" sign-req client "$certifname"
            #creation du profil dans cd /etc/openvpn
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
cat "/etc/easy-rsa/pki/issued/${certifname}.crt"
cat <<EOF
</cert>
<key>
EOF
cat "/etc/easy-rsa/pki/private/${certifname}.key"
cat <<EOF
</key>
<tls-crypt>
EOF 
cat /etc/openvpn/ta.key
cat <<EOF
</tls-crypt>
EOF
} >"/etc/openvpn/${certifname}.ovpn"
           ;;
        2)
            echo ""
            echo "-> Action B en cours..."
            ls -l
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        3)
            echo "Au revoir !"
            exit 0
            ;;
        *)
            echo ""
            echo "Erreur : Option invalide !"
            sleep 1
            ;;
    esac
done
