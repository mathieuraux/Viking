#!/bin/bash
OPEN_VPN_SACLI=/usr/local/openvpn_as/scripts/sacli
SAMBA_CONF_FILE="/usr/local/samba/etc/smb.conf"
SAMBA_TOOL=/usr/local/samba/bin/samba-tool

#Fonction d'initialisation du menu
function installmenu() {
	whiptail --title "Viking" --separate-output --checklist "Selectionner les services à installer" 15 60 4 \
		SAMBA_INSTALL "Samba" ON \
		OPENVPN_INSTALL "OpenVPN" ON \
		URBACKUP_INSTALL "UrBackup" OFF 2>/tmp/todoo
	while read soft; do
		if [ $soft = "SAMBA_INSTALL" ]; then
			samba_installation
		elif [ $soft = "OPENVPN_INSTALL" ]; then
			openvpn_installation
		elif [ $soft = "URBACKUP_INSTALL" ]; then
			urbackup_installation
		fi
	done < /tmp/todoo
}
function configmenu() {
	CONFMENU=$(whiptail --title "Viking" --menu "Configurer un service" 15 60 4 \
		"Samba" "Définir une nouvelle configuration de Samba" \
		"OpenVPN" "Relier l'AD et OpenVPN" 3>&1 1>&2 2>&3)

	case $CONFMENU in
		"Samba")
			samba_configuration
		;;
		"OpenVPN")
			openvpn_configuration
		;;
		esac
}
function samba_installation() {
	if [ ! -e /usr/local/samba/sbin/samba ]; then
		echo -e "\n###########################################################\n
############### Installation de Samba 4 AD ################\n
###########################################################\n"
		echo "Installation des packets nécessaires"
		yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
		yum install -y attr bind-utils docbook-style-xsl gcc gdb krb5-workstation \
		       libsemanage-python libxslt perl perl-ExtUtils-MakeMaker \
		       perl-Parse-Yapp perl-Test-Base pkgconfig policycoreutils-python \
		       python2-crypto gnutls-devel libattr-devel keyutils-libs-devel \
		       libacl-devel libaio-devel libblkid-devel libxml2-devel openldap-devel \
		       pam-devel popt-devel python-devel readline-devel zlib-devel systemd-devel \
		       lmdb-devel jansson-devel gpgme-devel pygpgme libarchive-devel winbind wget lmdb-devel pwgen
		if [ ! -d /tmp/samba ]; then
			mkdir /tmp/samba
		else
			rm -rf /tmp/samba
			mkdir /tmp/samba
		fi
		cd /tmp/samba
		echo "Téléchargement de Samba"
		wget https://download.samba.org/pub/samba/stable/samba-4.9.4.tar.gz
		echo "Extraction..."
		tar xvf samba-4.9.4.tar.gz
		cd samba-4.9.4
		echo "Test de la configuration avant installation"
		./configure
		if [ $? = 0 ]; then
			echo "Installation de Samba"
			make
			make install
		else
			echo "ERREUR : L'installation de samba a échoué"
		fi
		if [ -d /usr/local/samba/bin ]; then
			echo "Réglage du pare-feu"
			firewall-cmd --permanent --add-port=53/udp
			firewall-cmd --permanent --add-port=53/tcp
			firewall-cmd --permanent --add-service=samba
			firewall-cmd --reload

			sed '/\[global\]/a\\ttls verify peer = no_check' $SAMBA_CONF_FILE > $SAMBA_CONF_FILE
			sed '/\[global\]/a\\tldap server require strong auth = no' $SAMBA_CONF_FILE > $SAMBA_CONF_FILE

			echo "Création du démon"
			systemctl mask smbd nmbd winbind
			systemctl disable smbd nmbd winbind

			if [ ! -e /etc/systemd/system/samba-ad-dc.service ]; then
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
			fi

			systemctl enable samba-ad-dc

			whiptail --title "Installation de Samba" --msgbox "L'installation de Samba est terminé" 10 60
			samba_configuration
		fi
	else
		whiptail --title "Installation de Samba" --msgbox "Samba est déjà installé sur ce serveur" 10 60
		initmenu
	fi
}

#Fonctino de configuration de Samba
function samba_configuration() {
	#Récupération des paramètres si mode non interractif
	domain=$1
	netbios=$2
	domain_password=$3
	if (whiptail --title "Configuration de Samba" --yesno "Voulez-vous procéder à la configuration de Samba ?" 10 60); then
		echo "Arrêt du service Samba"
		systemctl stop samba-ad-dc

		echo "Test présence ancien fichier conf"
		if [ -e /usr/local/samba/etc/smb.conf ]; then
			rm /usr/local/samba/etc/smb.conf
		fi

		if [ -z "$domain" ]; then
			domain=$(whiptail --title "Choix du domaine" --inputbox "Votre nom de domaine : " 10 60 "domain.tld" 3>&1 1>&2 2>&3)
		fi
		if [ -z "$netbios" ]; then
			netbios=$(whiptail --title "Choix du nom NetBios" --inputbox "Votre nom NetBios: " 10 60 "DOMAIN" 3>&1 1>&2 2>&3)
		fi
		if [ -z "$domain_password" ]; then
			domain_password=$(whiptail --title "Choix du mot de passe Administrator" --passwordbox "Votre mot de passe : " 10 60 3>&1 1>&2 2>&3)
		fi

		$SAMBA_TOOL domain provision  --use-rfc2307 --realm='''$domain''' --domain '''$netbios''' --server-role=dc --adminpass=$domain_password
		cp /usr/local/samba/private/krb5.conf /etc/krb5.conf
	fi
}
function openvpn_installation() {
	if [ ! -d /usr/local/openvpn_as/ ]; then
		echo "Installation d'OpenVPN"
		echo "Configuration du pare-feu"
		firewall-cmd --permanent --add-services openvpn

		rpm --install https://openvpn.net/downloads/openvpn-as-latest-CentOS7.x86_64.rpm
		if [ $? = 0 ]; then
			whiptail --title "Installation d'OpenVPN" --msgbox "L'installation d'OpenVPN est terminé" 10 60
		fi
	else
		whiptail --title "Installation d'OpenVPN" --msgbox "OpenVPN est déjà installé sur ce serveur" 10 60
		installmenu
	fi
}
function openvpn_configuration() {
	ad_user="openvpn"
	ad_user_password=`pwgen 16`
	ldap_ip="127.0.0.1"

	isOpenVPNAlive=`$SAMBA_TOOL user list`
	if echo $isOpenVPNAlive | grep --quiet $ad_user ; then
		$SAMBA_TOOL user delete openvpn	
	fi

	echo "Creation de l'utilisateur openvpn"
	$SAMBA_TOOL user create openvpn "$ad_user_password"

	echo "Configuration Web"
	$OPEN_VPN_SACLI --key "cs.https.port" --value "444" ConfigPut

	echo "Liaison à l'AD"
	$OPEN_VPN_SACLI --key "auth.module.type" --value "ldap" ConfigPut
	$OPEN_VPN_SACLI --key "auth.ldap.0.server.0.host" --value $ldap_ip ConfigPut
	$OPEN_VPN_SACLI --key "auth.ldap.0.bind_dn" --value "CN=$ad_user, CN=Users, DC=swap, DC=dev" ConfigPut
	$OPEN_VPN_SACLI --key "auth.ldap.0.bind_pw" --value $ad_user_password ConfigPut
	$OPEN_VPN_SACLI --key "auth.ldap.0.users_base_dn" --value "CN=Users, DC=swap, DC=dev" ConfigPut

	echo "Elevation des privilèges du compte administrateur du domaine"
	$OPEN_VPN_SACLI --user Administrator --key "prop_superuser" --value "true" UserPropPut

	$OPEN_VPN_SACLI start
}
function urbackup_installation() {
	cd /etc/yum.repos.d/
	wget https://download.opensuse.org/repositories/home:uroni/CentOS_7/home:uroni.repo
	yum install urbackup-server
}
