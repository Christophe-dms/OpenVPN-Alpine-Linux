# OpenVPN-Alpine-Linux Fonctionnel sur Raspberry PI 1 / zero
OpenVPN sur Alpine Linux &lt;150 Mo
Pour installer OPENVPN sur alpine linux :
- telecharger le script AutoVPNScript.sh
- passer le script en executable avec la commande chmod +x AutoVPNScript.sh
- Bien repondre aux questions :
    Un mot de passe pour l'autorité de certification sera demandé (2fois)
    par la suite les certificats seront créés et ce mot de passe sera demandé
    Bien répondre 'yes' quand cela est demandé
- lorsque le script est terminé il aura mis le profil client (client1.ovpn) dans /etc/openvpn : il faudra le recuperer et le presenter au client openvpn de l'ordinateur qui communiquer avec le serveur
- fail2ban sera installé et prêt à communiquer avec votre broker MQTT notamment de home assistant avec mosquitto_pub
-Dans home assistant il faudra ajouter dans le fichier /homeassistant/configuration.yaml:
mqtt:
  - sensor:
      name: "AlpineOpenVpnAlert"
      state_topic: "alpine/fail2ban/+"
      value_template: "{{ value_json.ip }}"
      json_attributes_topic: "alpine/fail2ban/+"
      icon: mdi:shield-alert
-> on pourra alors gerer l'entité AlpineOpenVpnAlert en voici un exemple en yaml :

- alias: Alerte Intrusion OpenVPN sur raspberry PI 1
description: ''
triggers:
  - trigger: state
    entity_id: sensor.alpineopenvpnalert
conditions: []
actions:
  - action: notify.mobile_votreID
    metadata: {}
    data:
      message: Alerte Intrusion OpenVpn {{ now().strftime('%d/%m/%Y à %H:%M') }}
      title: Alerte Intrusion OpenVpn
mode: single

Home assistant est capable de vous fournir l'adresse IP exterieure de votre box :
- Ajouter dans /homeassistant/configuration.yaml
sensor:
  - platform: rest
    name: "External_IP"
    resource: "https://api.ipify.org/?format=json"
    value_template: "{{ value_json.ip }}"

->reboot
    -> on peut maintenant gerer l'entité External_IP et si elle change on pourra la recuperer par notification sur le telephone voici l'automation en yaml :

    alias: NotifierChangementIP_LiveBox
description: ''
triggers:
  - trigger: state
    entity_id: sensor.external_ip
conditions: []
actions:
  - action: notify.mobile_votreID
    metadata: {}
    data:
      message: 'message: "Nouvelle IP publique : {{ states(''sensor.external_ip'') }}"'
      title: LiveBox Changement IP
mode: single

