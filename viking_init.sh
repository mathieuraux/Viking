#!/bin/bash

#Présentation et menu
whiptail --title "Hello, Vicking !" --msgbox "Bienvenue dans le script d'installation de Vicking. Avant de procéder, nous allons définir quelques paramètres ensemble !" 10 60

function initmenu() {
	OPTION=$(whiptail --title "Viking" --menu "Selectionner une option" 15 60 4 \
		"1" "Installation de Samba" \
		"2" "Installation d'OpenVPN" 3>&1 1>&2 2>&3)
	case $OPTION in
		1)
			if (whiptail --title "Installation de Samba" --yesno "Voulez-vous procéder à l'installation de Samba ?" 10 60) then	
				domain=$(whiptail --title "Choix du domaine" --inputbox "Votre nom de domaine : " 10 60 "domain.tld" 3>&1 1>&2 2>&3)
				netbios=$(whiptail --title "Choix du nom NetBios" --inputbox "Votre nom NetBios: " 10 60 "DOMAIN" 3>&1 1>&2 2>&3)
				domain_password=$(whiptail --title "Choix du mot de passe Administrator" --passwordbox "Votre mot de passe : " 10 60 3>&1 1>&2 2>&3)
			else
				initmenu
			fi
		;;
		2)
			if (whiptail --title "Installation d'OpenVPN" --yesno "Voulez-vous procéder à l'installationd d'OpenVPN ?" 10 60) then	
				echo "ok"
			else
				initmenu
			fi
		;;
	esac
}
initmenu
