





cree un fichier

nano secure_debian_live_i2p_verified.sh


et colle le script que jai partager dans ce repo todo4 named secure_debian_live_i2p_verified.sh

sauvegarde le script


pour l'exécuter :
chmod +x secure_debian_live_i2p_verified.sh



Puis :
sudo ./secure_debian_live_i2p_verified.sh




After it finishes:
Start I2P:

i2prouter start

Open:
http://127.0.0.1:7657

Open I2PSnark:
http://127.0.0.1:7657/i2psnark/

Configure I2PSnark manually:

disable automatic torrent start;

stop completed torrents;

set upload limit low;

download to:
~/I2P-Downloads




whem is done in firefox go in setting

manual proxy configuration


HTTP Proxy:
127.0.0.1

Port:
4444
Enable:
[x] Use this proxy for HTTPS


Leave these empty:
SOCKS Host:
SOCKS Port:
Click OK.







after


First verify I2P is running:
Open:
http://127.0.0.1:7657

Then try an I2P address:
http://example.i2p


or use the I2P address book/search from the I2P console.





if is not working be sure in 
http://127.0.0.1:7657/configclients


be sure everything is started in section control

application tunel need to be started !

