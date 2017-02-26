#!/usr/bin/env bash
# vim: set tabstop=2 softtabstop=2 shiftwidth=2 noexpandtab fenc=utf-8 ff=unix ft=sh :
# #############################################################################
# FLISoL Post Install script
# Copyright (C) 2016 by HacKan (https://hackan.net)
# para FLISoL CABA (https://flisolcaba.usla.org.ar)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# #############################################################################
#
# Este script debe ejecutarse al termino de una instalacion para corregir
# los inconvenientes de PXE y otros detalles.
#
# #############################################################################

# Nota
# Todas las funciones devuelven: string, array o decimal
# En caso de devolver correcto/incorrecto, la convencion es
# 0=correcto, !0=incorrecto
# Generalmente, !0 es 1, pero al verificar se debe testear por -eq 0 y/o -ne 0
# <>

# Config
FLISOL_EVENT='CABA'
FLISOL_YEAR="$(date +'%Y')"
FLISOL_EDITION="$(( $(date +'%y') - 4 ))"

EVENTOL_URL_EVENT='caba'

VERSION_MAJOR='0'
VERSION_MINOR='1'
VERSION_REV='5dev-2016'
# <>

# Config interna
# NO MODIFICAR a menos que sepa lo que hace
VERSION="${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_REV}"

EVENTOL_URL_BASE='https://flisol.usla.org.ar'

SCRIPT_SIGNATURE_FILE="${HOME}/.flisol${EVENTOL_URL_EVENT}${FLISOL_YEAR}"

PACKAGE_MANAGER_BIN=""
PACKAGE_MANAGER_INSTALL_PARAMS=""
PACKAGE_MANAGER_UPDATE_PARAMS=""
PACKAGE_MANAGER_UPGRADE_PARAMS=""
IM_ROOT=
# <>

# Write here the functions name that will be executed in the main loop, in the
# corresponding order.
# These functions must terminate with 0 for success and !0 otherwise.
TASKS=( \
	"task_fix_interfaces" \
	"task_fix_sources" \
	"task_select_package_manager" \
	"task_system_update" \
	"task_open_eventol" \
	"task_change_wallpaper" \
)
# <>

# include hc_echoing
# https://git.linuxnoblog.net/hackan/funciones-bash/commit/756c4d34902bc2bcbc0c865548016e1c6f71bbe2
function hc_e() {
	if [ ! ${HC_ECHOING_QUIET} ]; then
		echo -en "$@"
	fi
}

function hc_e_msg() {
	hc_e "*** $@\n"
}

function hc_e_err() {
	hc_e "!!! "
	case ${LANG} in
	    es*) hc_e "Error:";;

	    de*) hc_e "Fehler:";;

	    en* | c | C | *) hc_e "Error:";;
	esac
	hc_e " $@\n"
}

function hc_e_warn() {
    hc_e "**! "
    case ${LANG} in
        es*) hc_e "Advertencia:";;

        de*) hc_e "Warnung:";;

        en* | c | C | *) hc_e "Warning:";;
    esac
    hc_e " $@\n"
}

function hc_e_notice() {
    hc_e "**? "
    case ${LANG} in
        es*) hc_e "Atencion:";;

        de*) hc_e "Achtung:";;

        en* | c | C | *) hc_e "Notice:";;
    esac
    hc_e " $@\n"
}

function hc_e_special() {
    hc_e "??? $@\n"
}

function hc_e_newline() {
    hc_e "\n"
}

function hc_e_debug() {
    if [ "${HC_ECHOING_DEBUG}" ]; then
        echo "DEBUG### $@"
    fi
}
# <>

# include hc_boolean
# https://git.linuxnoblog.net/hackan/funciones-bash/commit/feeff34b3c563fed3fca2d558fdf69dbc70ebf10
# Declaracion de variables booleanas
declare -r hc_true=1
declare -r HC_TRUE=1
declare -r hc_false=
declare -r HC_FALSE=
# <>

# Funciones

function elevate(){
	if [ ${IM_ROOT} ]; then
		$@
	else
		sudo $@
	fi
	return $?
}

function wait_any_key() {
	read -s -n 1 -p '**? Presione cualquier tecla para continuar...'
}

function print_line() {
	hc_e_msg "------------------------------------------------------------- ***"
}

# CTRL+C trap
function ctrl_c() {
    hc_e_newline
		hc_e_notice "Se ha presionado CTRL+C.  Saliendo forzadamente..."

		# cleanup?

		exit 130
}

# Executes a system command using the appropiate terminal, optionally elevating
# privs.
# Warning: no filter is applied! careful with user-passed data.
# Use:
# 	system 'command'
# 	system 'command' 1
function system() {
	# ToDo: search for a suitable terminal
	terminal='bash'
	params='-c'

	# execute
	$([ -n "$2" ] && printf "%s" "elevate") "$terminal" "$params" "$1"
}

# ToDo
# List every network interface, returning an array like ( "eth0" "eth1" "..." )
function list_interfaces() {
}
# <>

# Return the OS type as:
# 'linux'
# 'bsd'
# 'osx'
# 'solaris'
# 'unknown'
function os_type_m1() {
	# http://stackoverflow.com/questions/394230/detect-the-os-from-a-bash-script

	OS1=""
	case "${OSTYPE}" in
		solaris*) OS1="solaris" ;;
		darwin*)  OS1="osx" ;;
		linux*)   OS1="linux" ;;
		bsd*)     OS1="bsd" ;;
		*)        OS1="unknown" ;;
	esac

	printf "%s" "${OS1}"
}

# Return the OS type as:
# 'linux'
# 'bsd'
# 'osx'
# 'solaris'
# 'windows'
# 'aix'
# 'unknown'
function os_type_m2() {
	# http://stackoverflow.com/questions/394230/detect-the-os-from-a-bash-script

	OS2=""
	case "$(uname)" in
		'WindowsNT')	OS2='windows' ;;
		'FreeBSD')		OS2='bsd' ;;
		'Darwin')			OS2='osx' ;;
		'Linux')			OS2='linux' ;;
		'SunOS')			OS2='solaris' ;;
		'AIX')				OS2='aix';;
		*)						OS2="unknown" ;;
	esac

	printf "%s" "${OS2}"
}

# Return the OS type as:
# 'linux'
# 'bsd'
# 'osx'
# 'solaris'
# 'windows'
# 'aix'
# 'unknown'
function get_os_type() {
	OS="$(os_type_m1)"

	if [ "${OS}" == "unknown" ]; then
		OS="$(os_type_m2)"
	fi

	echo "${OS}"
}

# Return the OS name as:
# 'debian'
# 'arch'
# 'fedora'
# ...
function get_os() {
	# Awesome python oneliner :)
	# for any version
	# http://unix.stackexchange.com/a/92271
	python --version > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		name="$(python -c "import platform;print(platform.linux_distribution()[0])")"
		name="${name,,}"
	else
		name="$(uname -a)"
		name="${name,,}"

		if [[ "$(name)" =~ "debian" ]]; then
			name="debian"
		elif [[ "$(name)" =~ "arch" ]]; then
			name="arch"
		elif [[ "$(name)" =~ "ubuntu" ]]; then
			name="ubuntu"
		elif [[ "$(name)" =~ "mint" ]]; then
			name="mint"
		elif [[ "$(name)" =~ "fedora" ]]; then
			name="fedora"
		else
			name=""
		fi
	fi

	printf "%s" "${name}"
}

# Return the package manager binary as:
# 'apt'
# 'apt-get'
# 'pacman'
# ...
function get_package_manager() {
	pm=( "apt" "apt-get" "yum" "pacman" "emerge" "zypper" "unknown" )
	for p in ${pm[*]}; do
		if [ -x "$(which ${p})" ]; then
			printf "%s" "${p}"
			return
		fi
	done
}

# Returns the install parameters as:
# 'install'
# 'install'
# '-S'
# ...
function get_package_manager_install_params() {
	pm="$1"
	params=""
	case "${pm}" in
		'apt-get')	params="install"
		'pacman')		params="-S"
		'emerge')		params="-s"
		'zypper')		params="in"
		'apt')			params="install"
		'yum')			params="install"
		*)					params=""
	esac

	printf "%s" "${params}"
}

# Returns the update parameters as:
# 'update'
# 'update'
# '-Syy'
# ...
function get_package_manager_update_params() {
	pm="$1"
	params=""
	case "${pm}" in
		'apt-get')	params="update"
		'pacman')		params="-Syy"
		'emerge')		params="--sync"
		'zypper')		params="refresh"
		'apt')			params="update"
		'yum')			params="update"
		*)					params=""
	esac

	printf "%s" "${params}"
}

# Returns the upgrade parameters as:
# 'upgrade'
# 'upgrade'
# '-Su'
# ...
function get_package_manager_upgrade_params() {
	pm="$1"
	params=""
	case "${pm}" in
		'apt-get')	params="upgrade"
		'pacman')		params="-Su"
		'emerge')		params="--sync"
		'zypper')		params="update"
		'apt')			params="upgrade"
		'yum')			params="upgrade"
		*)					params=""
	esac

	printf "%s" "${params}"
}

# Installs packages or tells the user to do it
function packages_install() {
	packages=( $@ )
	if [ -z "${PACKAGE_MANAGER_BIN}" ]; then
		hc_e_msg "Instale los siguientes paquetes: ${packages[*]}"
		wait_any_key
	else
		hc_e_msg "Instalando paquetes..."
		hc_e_notice "${PACKAGE_MANAGER_BIN} ${PACKAGE_MANAGER_INSTALL_PARAMS} ${packages[*]}"
		elevate $PACKAGE_MANAGER_BIN $PACKAGE_MANAGER_INSTALL_PARAMS ${packages[*]}
		if [ $? -ne 0 ]; then
			hc_e_err "La instalacion no termino satisfactoriamente.\n\
								Revise el registro de ejecucion y corrija los problemas"
			hc_e_notice "Presione CTRL+C para salir"
			wait_any_key
		fi
	fi
	hc_e_msg "Terminado."
}

# Updates packages list/db or tells the user to do it
function packages_update() {
	if [ -z "${PACKAGE_MANAGER_BIN}" ]; then
		hc_e_msg "Actualice la lista de paquetes"
		wait_any_key
	else
		hc_e_msg "Actualizando lista de paquetes..."
		hc_e_notice "${PACKAGE_MANAGER_BIN} ${PACKAGE_MANAGER_UPDATE_PARAMS}"
		elevate ${PACKAGE_MANAGER_BIN} ${PACKAGE_MANAGER_UPDATE_PARAMS}
		return $?
	fi

	return 1
}

# Upgrades packages list/db or tells the user to do it
function packages_upgrade() {
	if [ -z "${PACKAGE_MANAGER_BIN}" ]; then
		hc_e_msg "Actualice los paquetes del sistema"
		wait_any_key
	else
		hc_e_msg "Actualizando paquetes del sistema..."
		hc_e_notice "${PACKAGE_MANAGER_BIN} ${PACKAGE_MANAGER_UPGRADE_PARAMS}"
		elevate ${PACKAGE_MANAGER_BIN} ${PACKAGE_MANAGER_UPGRADE_PARAMS}
		return $?
	fi

	return 1
}

function get_sources_debian() {
	echo <<EOF
deb http://ftp.ccc.uba.ar/pub/linux/debian/debian stable main contrib non-free
#deb-src http://ftp.ccc.uba.ar/pub/linux/debian/debian stable main contrib non-free

deb http://mirrors.dcarsat.com.ar/debian/ stable-updates main contrib non-free
#deb-src http://mirrors.dcarsat.com.ar/debian/ stable-updates main contrib non-free

deb http://mirrors.dcarsat.com.ar/debian/ stable main contrib non-free
#deb-src http://mirrors.dcarsat.com.ar/debian/ stable main contrib non-free

deb http://mirrors.dcarsat.com.ar/debian/ stable-updates main contrib non-free
#deb-src http://mirrors.dcarsat.com.ar/debian/ stable-updates main contrib non-free

deb http://security.debian.org/ jessie/updates main contrib non-free
#deb-src http://security.debian.org/ jessie/updates main contrib non-free
EOF
}

# Opens a URL in the system web browser, and returns the exit value
function open_webbrowser() {
	url="$1"

	xopen="$(which $BROWSER || which xdg-open || which gnome-open)"
	[[ -x "$xopen" ]] && exec "$xopen" "$url" && return $?

	return 1
}

# Sets global to determinate wheter we have elevated privs or not
function am_i_root() {
	if [ "$(whoami)" == "root" ]; then
		IM_ROOT=hc_true
	fi
}

# Checks prerequisites for the script
function prereq() {
	am_i_root
	[ ! ${IM_ROOT} ] && [ ! -x "$(which sudo)" ] \
		&& bail_out "No se puede elevar privilegios!\n\
								Instale sudo o ejecute este script como root"

	if [ -f "${SCRIPT_SIGNATURE_FILE}" ]; then
		hc_e_notice "Este script ya fue ejecutado y finalizo exitosamente"
		read -n 1 -p 'Esta seguro que desea ejecutarlo nuevamente? [s/N]' answer
		[ "${answer}" != "s" ] && exit 0
	fi
}

# Exits with error, showing a message
function bail_out() {
	hc_e_notice "$@"
	exit 1
}

# Writes a file to prove that the script has finished successfully
function drop_signature_file() {
	cat > "${SCRIPT_SIGNATURE_FILE}" <<EOF
Liberado el $(date) en el FLISoL ${FLISOL_EVENT} ${FLISOL_YEAR} #${FLISOL_EDITION}
Que disfrutes!

Un abrazo grande,
- El equipo de FLISoL ${FLISOL_EVENT}
EOF
}

function welcome() {
	hc_e_special <<EOF
Hola! Bienvenido al FLISoL ${FLISOL_EVENT} ${FLISOL_YEAR} #${FLISOL_EDITION}!
Esperamos que este disfrutando este dia, y que haya aprendido mucho con esta instalacion y las charlas.

A continuacion vamos a guiarle para terminar de configurar el sistema, y sin duda tendra un instalador cerca suyo que le estara ayudando.

Para detener la ejecucion de este escript en cualquier momento, presione CTRL+C.
EOF
}

function goodbye() {
	hc_e_special <<EOF
Hemos terminado :)
No fue tan dificil, no?

Ahora si, te dejamos con tu sistema para que lo disfrutes, cualquier duda que tengas acercate a uno de los instaladores o revisa las opciones de contacto en nuestra web: ${EVENTOL_URL_BASE}/event/${EVENTOL_URL_EVENT}

Un abrazo grande,
- El equipo de FLISoL ${FLISOL_EVENT}
EOF
}

function finish() {
	goodbye

	drop_signature_file

	exit 0
}
# <>

# Tasks for the main loop

# ToDo: change wallpaper on every distro
# https://forum.xfce.org/viewtopic.php?id=3335
# http://unix.stackexchange.com/questions/116539/how-to-detect-the-desktop-environment-in-a-bash-script
# http://askubuntu.com/questions/72549/how-to-determine-which-window-manager-is-running
function task_change_wallpaper() {
	return 0
}
# <>

# Attempts to fix /etc/network/interfaces: after booting with PXE, a static
# IP is probably configured, which might cause issues with Network-Manager
function task_fix_interfaces() {
	hc_e_msg "Corrigiendo /etc/network/interfaces..."
	mv /etc/network/interfaces /etc/network/interfaces.bak
	# I prefer not to use tee, I don't know if it's everywhere
	# Otherwise, this line could be:
	# echo -e "auto lo\niface lo inet loopback\n" | elevate tee /etc/network/interfaces
	system 'echo -e "auto lo\niface lo inet loopback\n" > /etc/network/interfaces' 1

	# ToDo: list_interfaces...
	# read -n 1 -p 'Quiere configurar automaticamente las interfaces o dejar que \
	# 							lo haga Network-Manager? [s/N]: ' answer
	# if [ "${answer,,}" == "s" ]; then
	# 	interfaces=$(list_interfaces)
	# 	for interface in interfaces; do
	# 		system 'echo -e "auto ${interface}\niface ${interface} inet dhcp\n" >> /etc/network/interfaces' 1
	# 		sync
	# 		elevate ifdown ${interface}
	# 		elevate ifup ${interface}
	# 	done
	# fi

	hc_e_msg "Listo."
	hc_e_msg ": cat /etc/network/interfaces"
	cat /etc/network/interfaces

	return 0
}

function task_fix_sources() {
	hc_e_msg "Se corregiran las fuentes de paquetes de su sistema"

	osname="$(get_os)"
	hc_e_msg "Se detecto que su sistema es ${osname}"

	if [ -z "${PACKAGE_MANAGER_BIN}" ]; then
		hc_e_msg "Actualice las fuentes de su sistema"
		wait_any_key
	else
		case "${PACKAGE_MANAGER_BIN}" in
			'apt'*)
				mv /etc/apt/sources.list /etc/apt/sources.list.bak

				case "${osname}" in
					'debian')
						cat > /etc/apt/sources.list <<"$(get_sources_debian)"
					;;

			esac
				;;

			*)
				;;
		esac
	fi
}

# Opens eventoL or displays url if fails, plus instructions
function task_open_eventol() {
	hc_e_msg <<EOF
Vamos a registrar la instalacion en eventol.  A continuacion se abrira el navegador con la pagina del evento.
Para registrar la instalacion, siga estos pasos:
 1- Pidale al instalador que inicie sesion con su usuario
 2- Registre la instalacion en Colaboradores > Cargar una instalacion
 3- Complete los campos indicados
 4- Recuerdele al instalador que aplica para el desafio:
		http://wiki.cafelug.org.ar/index.php/Flisol/2016/Instaladores/Instalaciones

Si no se encuentra registrado, debe crear una cuenta en la seccion Iniciar sesion y luego en Registrarme

Al terminar, podra continuar la ejecucion de este script

EOF

	url="${EVENTOL_URL_BASE}/event/${EVENTOL_URL_EVENT}"
	open_webbrowser "$url"
	if [ $? -ne 0 ]; then
		hc_e_err "No se ha podido abrir un navegador, por favor dirijase a esta \
							URL:\n\t${url}"
	fi

	hc_e_msg "Registre la instalacion, lo espero..."
	wait_any_key

	return 0
}

# Select the package manager, let the user choose
function task_select_package_manager() {
	PACKAGE_MANAGER_BIN="$(get_package_manager)"
	PACKAGE_MANAGER_INSTALL_PARAMS="$(get_package_manager_install_params ${PACKAGE_MANAGER_BIN})"
	PACKAGE_MANAGER_UPDATE_PARAMS="$(get_package_manager_update_params ${PACKAGE_MANAGER_BIN})"
	PACKAGE_MANAGER_UPGRADE_PARAMS="$(get_package_manager_upgrade_params ${PACKAGE_MANAGER_BIN})"

	hc_e_msg "Se ha detectado el siguiente gestor de paquetes: ${PACKAGE_MANAGER_BIN}"
	hc_e_msg "Cuyos parametros son: "
	hc_e_msg " - Para instalar:\t\t\t\t\t${PACKAGE_MANAGER_INSTALL_PARAMS}"
	hc_e_msg " - Para actualizar repositorio:\t\t\t\t\t${PACKAGE_MANAGER_UPDATE_PARAMS}"
	hc_e_msg " - Para actualizar sistema:\t\t\t\t\t${PACKAGE_MANAGER_UPGRADE_PARAMS}"
	answer=""
	if [ "${PACKAGE_MANAGER_BIN}" == "unknown" ]; then
		hc_e_warn "El gestor es desconocido, debera indicar un gestor de \
								paquetes\nDe no hacerlo, el script le solicitara que instale \
								los paquetes necesarios manualmente"
		answer="s"
	else
		read -n 1 -p 'Desea utilizar otro gestor de paquetes o especificar otro/s \
									parametro/s? [s/N]: ' answer
	fi
	if [ "x${answer,,}" == "xs" ]; then
		read -p 'Escriba el nombre del binario del gestor de paquetes a utilizar: ' PACKAGE_MANAGER_BIN
		read -p 'Escriba los parametros que debe pasarsele al gestor para instalar un paquete: ' PACKAGE_MANAGER_INSTALL_PARAMS
	fi

	if [ -z "${PACKAGE_MANAGER_BIN}" ] || [ ! -x "$(which ${PACKAGE_MANAGER_BIN})" ]; then
		hc_e_err "No se tiene acceso o no se encuentra el gestor de paquetes"
		hc_e_warn "El script le solicitara que instale los paquetes necesarios \
							manualmente"

		PACKAGE_MANAGER_BIN=""

		unset \
			PACKAGE_MANAGER_INSTALL_PARAMS \
			PACKAGE_MANAGER_UPDATE_PARAMS \
			PACKAGE_MANAGER_UPGRADE_PARAMS

		return 1
	fi

	return 0
}

function task_system_update() {
	packages_update
	if [ $? -ne 0 ]; then
		hc_e_err "La actualizacion de lista de paquetes no termino \
							satisfactoriamente.\n\
							Revise el registro de ejecucion y corrija los problemas"
		#hc_e_notice "Presione CTRL+C para salir"
		#wait_any_key
		return 1
	fi

	packages_upgrade
	if [ $? -ne 0 ]; then
		hc_e_err "La actualizacion de paquetes no termino satisfactoriamente.\n\
							Revise el registro de ejecucion y corrija los problemas"
		#hc_e_notice "Presione CTRL+C para salir"
		#wait_any_key
		return 1
	fi

	return 0
}
# <>

# main()
trap ctrl_c INT

prereq

welcome

repeat=$hc_true
for t in ${TASKS[@]}; do
	while [ $repeat ]; do
		repeat=$hc_false

		print_line
		$t
		if [ $? -ne 0 ]; then
			print_line
			read -n 1 -p '!!! Error: La tarea ha finalizado con fallo, desea repetirla? [s/N]: ' answer
			repeat=[ "$answer" == "s" ]
		fi
	done
	repeat=$hc_true
done

finish
# <>
