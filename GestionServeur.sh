#!/bin/sh
clear
afficher_menu() {
    clear
    echo "=============================="
    echo "       MENU PRINCIPAL         "
    echo "=============================="
    echo "0. Liste des certificats"
    echo "1. Creation de certificat "
    echo "2. Revoquation de certificat "
    echo "3. liste des prisons Fail2ban"
    echo "4. Etat des prisons "
    echo "5. Debannir une IP "
    echo "6. Port à l'écoute "
    echo "7. Quitter"
    }

# Boucle principale
while true; do
    afficher_menu
    read -p "Faites votre choix [1-7] : " choix

    case $choix in
        0)
            echo "Liste des certificats existants"
            cd /etc/openvpn
            ls *.ovpn  
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        1)
            echo "Liste des certificats existants"
            cd /etc/openvpn
            ls *.ovpn
            echo "Creation d'un certificat"
            read -p "Donner un nom pour le certicat (sans .ovpn): " certifname
            read -s -p "Donner le mot de passe de l authorite de certification: " authcertif
            echo
            if openssl rsa -in /etc/easy-rsa/pki/private/ca.key -passin "pass:$authcertif" -noout 2>/dev/null; then
            echo "-> Mot de passe de la CA correct !"
            else
            echo "-> Erreur : Mot de passe de l'autorité de certification incorrect !"
            read -p "Appuyez sur Entrée ..."
            exit 0
            fi
            read -p "Entrer l'adresse IP Exterieure de la box [a.b.c.d]: " ipbox
            read -p "Entrer le port Exterieur de la box pour le VPN: " portext
            #generation des clés pour le certificat dans /etc/easy-rsa/pki issued et private
            cd /etc/easy-rsa
            echo "yes"| ./easyrsa gen-req "$certifname" nopass
            echo "yes" | ./easyrsa --passin="pass:$authcertif" sign-req client "$certifname"
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
echo "Recuperer votre certificat dans : /etc/openvpn"
read -p "Appuyer sur Entrée pour continuer ..."
exit 0
           ;;
        2)
            echo "Liste des certificats existants"
            cd /etc/openvpn
            ls *.ovpn
            read -p "Donner un nom (sans .ovpn) pour le certicat à revoquer: " certifname
            read -s -p "Donner le mot de passe de l authorite de certification: " authcertif
            echo
            if openssl rsa -in /etc/easy-rsa/pki/private/ca.key -passin "pass:$authcertif" -noout 2>/dev/null; then
            echo "-> Mot de passe de la CA correct !"
            else
            echo "-> Erreur : Mot de passe de l'autorité de certification incorrect !"
            read -p "Appuyez sur Entrée ..."
            exit 0
            fi
            cd /etc/easy-rsa
            ./easyrsa --batch --passin="pass:$authcertif" revoke "$certifname"
            ./easyrsa --batch --passin="pass:$authcertif" gen-crl
            rm /etc/openvpn/"$certifname".ovpn
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        3)
            echo "Liste des prisons de Fail2ban"
            fail2ban-client status
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        4)
            echo "Liste des prisons de Fail2ban"
            fail2ban-client status
            read -p "Indiquez la prison à consulter :" prison
            fail2ban-client status $prison
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
         5)
            echo "liste des adresses IP bannies par Fail2ban"
            fail2ban-client status | grep "Jail list" | sed -E 's/^[^:]*:[ \t]*//' | tr ',' '\n' | while read jail; do
            echo "=== Prison : $jail ==="
            sudo fail2ban-client status "$jail" | grep "Banned IP list"
            done
            read -p "entrer l'adresse IP à liberer" ipaddress
            fail2ban-client uban $ipaddress
            read -p "Appuyer sur la touche entrée ... "
            ;;
         6)
            netstat - an
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
         7)
            exit 0
            ;;
    esac
done
