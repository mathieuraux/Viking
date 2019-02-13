#!/bin/bash

#Include des fonctions
source ./viking_function.sh

#Présentation et menu
while getopts ":h" option; do
	case "${option}" in
		h)
			echo "help"
		;;
	esac
done

if [ -z $@ ]; then
	whiptail --title "Hello, Vicking !" --msgbox "Bienvenue dans le script d'installation de Vicking." 10 60
	MAIN=$(whiptail --title "Que souhaitez vous faire ?" --menu "Choisir une option" 25 78 16 \
	"Installation" "Donner moi quelques informations, et je m'occupe du reste" \
	"Configuration" "Pour configurer ou reconfigurer un service" \
	"Quitter" "Ferme ce menu" 3>&1 1>&2 2>&3)

	case $MAIN in
		"Installation")
			installmenu
		;;
		"Quitter")
			exit
		;;
		esac
fi
