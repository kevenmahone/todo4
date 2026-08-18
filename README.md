sudo grep -E "tunnel.0.name|tunnel.0.type|tunnel.0.listenPort|tunnel.0.startOnLoad" /var/lib/i2p/i2p-config/i2ptunnel.config





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



in about config


Recommended Firefox privacy settings
In the I2P Firefox profile, open:
about:config
Set:
media.peerconnection.enabled = false
(disables WebRTC)

network.trr.mode = 5
(disables Firefox DNS-over-HTTPS)

network.prefetch-next = false
(disables prefetching)





after


First verify I2P is running:
Open:
http://127.0.0.1:7657

Then try an I2P address:
http://example.i2p


or use the I2P address book/search from the I2P console.


