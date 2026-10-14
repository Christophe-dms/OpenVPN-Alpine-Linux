# OpenVPN-Alpine-Linux Fonctionnel sur Raspberry PI 1 / zero

Une fois le script effectué vous récuperez le certificat pour le client dans /etc/openvpn/client1.opvn

Le serveur est opérationnel

La securité est paramétrée et assurée avec fail2ban et communique avec votre broker Mqtt notamment home assistant en cas d'attaque et banit l'ip attaquante

 il faudra parametrer un chemin NAT dans la box (voir fichier lisezmoi.pdf)

Il faudra également gerer home assistant pour tenir compte des alertes de OPENVPN
 nota : home assistant est capable de vous fournir l'adresse IP extérieur de votre box et de la transmettre par notrification notamment si elle change

 Nota vous pouvez tout mieux comprendre en le faisant manuellement à l'aide du tuto RedactionServeurVPN.pdf
 
