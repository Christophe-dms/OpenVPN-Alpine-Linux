<font size="+2"><b> Objectif : faire d'un raspberry PI 1 / zero un veritable serveur VPN </b></font>

<font size="+1">Utilisation de <b>Alpine Linux, OpenVPN, Fail2ban</b></font>

Le tout en <b>< 150 Mo</b> (vous avez bien lu < 150 Mo)

Je considère que Alpine est installée

- Utiliser Script-Creation-ServeurOPENVPN.sh répondez aux question et le serveur sera prêt rapidement
- Parametrer la un chemin NAT sur la box (voir fichier lisezmoi.pdf)
  
  facultatif :
- Pour home assistant ajouter les lignes de codes yaml au fichier de configuration pour recevoir des notification en cas d'attaque

- Il ne reste plus qu'à récuperer le certificat pour le client dans /etc/openvpn/client1.opvn (le nom indiqué avec le script)

La securité est assurée par fail2ban qui peut communiquer avec votre broker Mqtt notamment home assistant.
En cas d'attaque et fail2ban banit l'ip attaquante et vous etes notifié sur votre telephone

Pour tenir compte des alertes de OPENVPN , il faudra gerer Home assistant précisions dans le fichier lisezmoi.pdf

<b>Remarque Importante : home assistant est capable de vous transmettre votre adresse IP exterieur si elle change par notification sur votre telephone</b>

Vous pouvez également le mettre en place pas à pas en le faisant manuellement à l'aide du tuto Creation-ServeurOPENVPN-Manuelle.pdf
 
