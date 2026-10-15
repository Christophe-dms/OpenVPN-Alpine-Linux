<font size="+2"><b> Objectif : faire d'un raspberry PI 1 / zero un veritable serveur VPN </b></font>

Utilisation de Alpine Linux, OpenVPN, Fail2ban

Le tout en < 150 Mo (vous avez bien lu < 150 Mo)

Je considère que Alpine est installée

Une fois le script effectué le serveur est opérationnel 

vous récuperez le certificat pour le client dans /etc/openvpn/client1.opvn (ou le nom indiqué avec le script)

La securité est assurée par fail2ban qui communique avec votre broker Mqtt notamment home assistant.
En cas d'attaque et fail2ban banit l'ip attaquante et vous etes notifié sur votre telephone

Il faudra parametrer un chemin NAT dans la box (voir fichier lisezmoi.pdf)

Pour tenir compte des alertes de OPENVPN , il faudra gerer Home assistant précisions dans le fichier lisezmoi.pdf

 nota : home assistant est capable de vous fournir l'adresse IP extérieur de votre box et de la transmettre par notrification notamment si elle change

Vous pouvez également apprendre pas à pas en le faisant manuellement à l'aide du tuto RedactionServeurVPN.pdf
 
