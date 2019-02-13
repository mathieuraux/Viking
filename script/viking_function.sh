#!/bin/bash

#Fonction d'initialisation du menu
function initmenu() {
	whiptail --title "Viking" --separate-output --checklist "Selectionner les produits à installer" 15 60 4 \
		SAMBA_INSTALL "Samba" ON \
		OPENVPN_INSTALL "OpenVPN" ON \
		ZABBIX_INSTALL "Zabbix" OFF 2>todoo
	while read soft; do
		if [ $soft = "SAMBA_INSTALL" ]; then
			samba_installation
		fi
	done < todoo
}

function samba_installation() {
	yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
	echo -e "###########################################################\n
############### Installation de Samba 4 AD ################\n
###########################################################\n"
	yum install attr bind-utils docbook-style-xsl gcc gdb krb5-workstation \
	       libsemanage-python libxslt perl perl-ExtUtils-MakeMaker \
	       perl-Parse-Yapp perl-Test-Base pkgconfig policycoreutils-python \
	       python2-crypto gnutls-devel libattr-devel keyutils-libs-devel \
	       libacl-devel libaio-devel libblkid-devel libxml2-devel openldap-devel \
	       pam-devel popt-devel python-devel readline-devel zlib-devel systemd-devel \
	       lmdb-devel jansson-devel gpgme-devel pygpgme libarchive-devel
	if [ ! -d /tmp/samba ]; then
		mkdir /tmp/samba
	else
		rm -rf /tmp/samba
		mkdir /tmp/samba
	fi
	cd /tmp/samba
	wget https://download.samba.org/pub/samba/stable/samba-4.9.4.tar.gz
	tar xvf samba-4.9.4.tar.gz
	cd samba-4.9.4
	./configure
	if [ $? = 0 ]; then
		make
		make install
	else
		echo "ERREUR : La configuration de samba a échoué"
	fi
	if [ -d /usr/local/samba/bin ]; then
		echo "Réglage du pare-feu"
		firewall-cmd --permanent --add-port=53/udp
		firewall-cmd --permanent --add-port=53/tcp
		firewall-cmd 
		firewall-cmd --reload

		echo "Création du démon"
		systemctl mask smbd nmbd winbind
		systemctl disable smbd nmbd winbind

		echo '[Unit]
		Description=Samba Active Directory Domain Controller
		After=network.target remote-fs.target nss-lookup.target

		[Service]
		Type=forking
		ExecStart=/usr/local/samba/sbin/samba -D
		PIDFile=/usr/local/samba/var/run/samba.pid
		ExecReload=/bin/kill -HUP $MAINPID

		[Install]
		WantedBy=multi-user.target' > /etc/systemd/system/samba-ad-dc.service

		systemctl enable samba-ad-dc

		whiptail --title "Installation de Samba" --msgbox "L'installation de Samba est terminé" 10 60
	fi
}

#Fonctino de configuration de Samba
function samba_configuration() {
	#Récupération des paramètres si mode non interractif
	domain=$1
	netbios=$2
	domain_password=$3
	if (whiptail --title "Configuration de Samba" --yesno "Voulez-vous procéder à la configuration de Samba ?" 10 60); then
		if [ -z "$domain" ]; then
			domain=$(whiptail --title "Choix du domaine" --inputbox "Votre nom de domaine : " 10 60 "domain.tld" 3>&1 1>&2 2>&3)
		fi
		if [ -z "$netbios" ]; then
			netbios=$(whiptail --title "Choix du nom NetBios" --inputbox "Votre nom NetBios: " 10 60 "DOMAIN" 3>&1 1>&2 2>&3)
		fi
		if [ -z "$domain_password" ]; then
			domain_password=$(whiptail --title "Choix du mot de passe Administrator" --passwordbox "Votre mot de passe : " 10 60 3>&1 1>&2 2>&3)
		fi

		/usr/local/samba/bin/samba-tool domain provision  --use-rfc2307 --realm='''$domain''' --domain '''$netbios''' --server-role=dc --adminpass=$domain_password
		cp /usr/local/samba/private/krb5.conf /etc/krb5.conf
	fi
}
