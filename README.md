crer un fichier

nano secure_debian_live_i2pd.sh


et colle le script que jai partager dans ce repo todo4

sauvegarde le script


pour l'exécuter :
chmod +x secure_debian_live_i2pd.sh



Puis :
sudo ./secure_debian_live_i2pd.sh








Configurer le proxy I2P
Dans Firefox :
Menu ☰
→ Settings (Paramètres)
→ Network Settings (Paramètres réseau)
→ Settings...
Choisis :
Manual proxy configuration
Mets :
HTTP Proxy:
127.0.0.1

Port:
4444
Coche :
[x] Also use this proxy for HTTPS

Laisse vide :
SOCKS Host
Puis valide.




Tester que i2pd fonctionne
Dans Firefox ouvre :
http://127.0.0.1:7070
Tu devrais voir la console web i2pd.
Elle montre :
état du routeur I2P ;
tunnels actifs ;
connexions ;
bande passante.



