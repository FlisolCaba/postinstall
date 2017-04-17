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
declare -r FLISOL_EVENT='CABA'
declare -r FLISOL_YEAR="$(date +'%Y')"
declare -r FLISOL_EDITION="$(( $(date +'%y') - 4 ))"

declare -r EVENTOL_URL_EVENT='caba'

declare -r VERSION_MAJOR='0'
declare -r VERSION_MINOR='6'
declare -r VERSION_REV='16rev-2016'

declare -r POSTINSTALL_URL="http://postinstall.flisolcaba.net"
declare -r PREINSTALL_URL="http://preinstall.flisolcaba.net"
# <>

# Config interna
# NO MODIFICAR a menos que sepa lo que hace
declare -r VERSION="${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_REV}"

declare -r EVENTOL_URL_BASE='https://flisol.usla.org.ar'

declare -r SCRIPT_SIGNATURE_FILE="${HOME}/.flisol${EVENTOL_URL_EVENT}${FLISOL_YEAR}"

# Listado de nombres de distros soportadas por este script
declare -r SUPPORTED_DIST=( "huayra" "debian" "ubuntu" "mint" "fedora" "lite" )

# Listado de OS soportados por este script
declare -r SUPPORTED_OS=( "linux" )
# <>

# Write here the functions name that will be executed in the main loop, in the
# corresponding order.
# These functions must terminate with 0 for success and !0 otherwise.
# Be careful with the order! One task might depend on other.
TASKS=( \
	"task_verify_os" \
	"task_verify_distro" \
	"task_fix_interfaces" \
	"task_select_package_manager" \
	"task_fix_sources" \
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

function press_any_key() {
	read -s -n 1 -p '**? Presione cualquier tecla para continuar...'
	hc_e_newline
}

# Read a line from the user input
function cin() {
	local data=""
	read -e -p "${1}" data
	printf "%s" "${data}"
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
#     system 'command'
#     system 'command' 1
function system() {
	# ToDo: search for a suitable terminal
	local terminal='bash'
	local params='-c'

	# execute
	$([ -n "$2" ] && printf "%s" "elevate") "$terminal" "$params" "'${1}'"
}

# Returns 0 if the given function exists, 1 otherwise
function function_exists() {
	if [[ "$(type -t ${1})" == "function" ]]; then
		return 0
	fi

	return 1
}

# ToDo
# List every network interface, returning an array like ( "eth0" "eth1" "..." )
function list_interfaces() {
	return 0
}
# <>

# Return the OS type as:
# 'linux'
# 'bsd'
# 'osx'
# 'solaris'
# ''
function os_type_m1() {
	# http://stackoverflow.com/questions/394230/detect-the-os-from-a-bash-script

	printf "%s" "${OSTYPE}"
}

# Return the OS type as:
# 'linux'
# 'bsd'
# 'osx'
# 'solaris'
# 'windows'
# 'aix'
# ''
function os_type_m2() {
	# http://stackoverflow.com/questions/394230/detect-the-os-from-a-bash-script

	uname -a
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
	local os=""
	local method=""
	local GETOSTYPEMETHODS=( "os_type_m1" "os_type_m2" )

	for method in ${GETOSTYPEMETHODS[*]}; do
		os="$($method)"
		os="${os,,}"

		if [ -n "${os}" ]; then
			if [[ "${os}" =~ "linux" ]]; then
				os="linux"
			elif [[ "${os}" =~ "bsd" ]]; then
				os="bsd"
			elif [[ "${os}" =~ "osx" ]] || [[ "${os}" =~ "darwin" ]]; then
				os="osx"
			elif [[ "${os}" =~ "sun" ]]; then
				os="solaris"
			elif [[ "${os}" =~ "aix" ]]; then
				os="aix"
			elif [[ "${os}" =~ "windows" ]] || [[ "${os}" =~ "nt" ]]; then
				os="windows"
			else
				os=""
			fi

			if [ -n "${os}" ]; then
				break
			fi
		fi
	done

	printf "%s" "${os}"
}

# Method one to get distro name
function distro_name_m1() {
	# Awesome python oneliner :)
	# for any version
	# http://unix.stackexchange.com/a/92271
	if python --version > /dev/null 2>&1; then
		python -c "import platform;print(platform.linux_distribution()[0])"
	fi
}

# Method two to get distro name
function distro_name_m2() {
	if lsb_release > /dev/null 2>&1; then
		lsb_release -a
	fi
}

# Method three to get distro name
function distro_name_m3() {
	uname -a
}

# Return the OS name as:
# 'debian'
# 'arch'
# 'fedora'
# ...
# Or empty string if not found
function get_distro() {
	local name=""
	local method=""
	local GETOSNAMEMETHODS=( "distro_name_m1" "distro_name_m2" "distro_name_m3" )

	for method in ${GETOSNAMEMETHODS[*]}; do
		name="$($method)"
		name="${name,,}"

		if [ -n "${name}" ]; then
			if [[ "${name}" =~ "debian" ]]; then
				name="debian"
			elif [[ "${name}" =~ "arch" ]]; then
				name="arch"
			elif [[ "${name}" =~ "ubuntu" ]]; then
				name="ubuntu"
			elif [[ "${name}" =~ "mint" ]]; then
				name="mint"
			elif [[ "${name}" =~ "fedora" ]]; then
				name="fedora"
			elif [[ "${name}" =~ "huayra" ]]; then
				name="huayra"
			elif [[ "${name}" =~ "lite" ]]; then
				name="lite"
			else
				name=""
			fi

			if [ -n "${name}" ]; then
				break
			fi
		fi
	done

	printf "%s" "${name}"
}

# Return the package manager binary as:
# 'apt'
# 'apt-get'
# 'pacman'
# ...
function get_package_manager() {
	local pm=( "apt" "apt-get" "yum" "pacman" "emerge" "zypper" )
	local p=""

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
	local pm="$1"
	local params=""

	case "${pm}" in
		'apt-get')	params="install";;
		'pacman')		params="-S";;
		'emerge')		params="-s";;
		'zypper')		params="in";;
		'apt')			params="install";;
		'yum')			params="install";;
		*)					params="";;
	esac

	printf "%s" "${params}"
}

# Returns the update parameters as:
# 'update'
# 'update'
# '-Syy'
# ...
function get_package_manager_update_params() {
	local pm="$1"
	local params=""

	case "${pm}" in
		'apt-get')	params="update";;
		'pacman')		params="-Syy";;
		'emerge')		params="--sync";;
		'zypper')		params="refresh";;
		'apt')			params="update";;
		'yum')			params="update";;
		*)					params="";;
	esac

	printf "%s" "${params}"
}

# Returns the upgrade parameters as:
# 'upgrade'
# 'upgrade'
# '-Su'
# ...
function get_package_manager_upgrade_params() {
	local pm="$1"
	local params=""

	case "${pm}" in
		'apt-get')	params="upgrade";;
		'zypper')		params="update";;
		'emerge')		params="--sync";;
		'pacman')		params="-Su";;
		'apt')			params="upgrade";;
		'yum')			params="upgrade";;
		*)					params=""
	esac

	printf "%s" "${params}"
}

# Installs packages or tells the user to do it
function packages_install() {
	local packages=( $@ )

	if [ -z "${PACKAGE_MANAGER_BIN}" ]; then
		hc_e_msg "Instale los siguientes paquetes: ${packages[*]}"
		press_any_key
	else
		hc_e_msg "Instalando paquetes..."
		hc_e_notice "${PACKAGE_MANAGER_BIN} ${PACKAGE_MANAGER_INSTALL_PARAMS} ${packages[*]}"
		elevate $PACKAGE_MANAGER_BIN $PACKAGE_MANAGER_INSTALL_PARAMS ${packages[*]}
		if [ $? -ne 0 ]; then
			hc_e_err "La instalacion no termino satisfactoriamente.\n\
								Revise el registro de ejecucion y corrija los problemas"
			hc_e_notice "Presione CTRL+C para salir"
			press_any_key
		fi
	fi
	hc_e_msg "Terminado."
}

# Updates packages list/db or tells the user to do it
function packages_update() {
	if [ -z "${PACKAGE_MANAGER_BIN}" ]; then
		hc_e_msg "Actualice la lista de paquetes"
		press_any_key
	else
		hc_e_msg "Actualizando lista de paquetes..."
		hc_e_notice "${PACKAGE_MANAGER_BIN} ${PACKAGE_MANAGER_UPDATE_PARAMS}"
		elevate ${PACKAGE_MANAGER_BIN} ${PACKAGE_MANAGER_UPDATE_PARAMS}
		return $?
	fi

	return 0
}

# Upgrades packages list/db or tells the user to do it
function packages_upgrade() {
	if [ -z "${PACKAGE_MANAGER_BIN}" ]; then
		hc_e_msg "Actualice los paquetes del sistema"
		press_any_key
	else
		hc_e_msg "Actualizando paquetes del sistema..."
		hc_e_notice "${PACKAGE_MANAGER_BIN} ${PACKAGE_MANAGER_UPGRADE_PARAMS}"
		elevate ${PACKAGE_MANAGER_BIN} ${PACKAGE_MANAGER_UPGRADE_PARAMS}
		return $?
	fi

	return 0
}

# To specify the content of a source file for a distro, create a function
# named like
# get_sources_DISTRO_PACKAGEMAN
# And populate it with the array SOURCES_CONTENTS=( "source1" ... "sourceN" )
# With a content matching each source file defined in the functions
# get_sources_filepath_PACKAGEMAN and get_sources_filepath_PACKAGEMAN_DISTRO

function get_sources_huayra_apt-get() {
	get_sources_huayra_apt
}

function get_sources_huayra_apt() {
	SOURCES_CONTENTS=( \
		"deb http://http.debian.net/debian/ jessie main contrib non-free
deb-src http://http.debian.net/debian/ jessie main contrib non-free
deb http://security.debian.org/ jessie/updates main contrib non-free
deb-src http://security.debian.org/ jessie/updates main contrib non-free
deb http://http.debian.net/debian/ jessie-updates main contrib non-free
deb-src http://http.debian.net/debian/ jessie-updates main contrib non-free
" \
		"# Repositorio de Huayra GNU/Linux
deb http://repo.huayra.conectarigualdad.gob.ar/huayra sud main contrib non-free
deb-src http://repo.huayra.conectarigualdad.gob.ar/huayra sud main contrib non-free

# Repositorio de Huayra GNU/Linux (actualizaciones)
deb http://repo.huayra.conectarigualdad.gob.ar/huayra sud-updates main contrib non-free
deb-src http://repo.huayra.conectarigualdad.gob.ar/huayra sud-updates main contrib non-free
" \
	)
}

function get_sources_debian_apt-get() {
	get_sources_debian_apt
}

function get_sources_debian_apt() {
	SOURCES_CONTENTS=( \
	"deb http://ftp.ccc.uba.ar/pub/linux/debian/debian stable main contrib non-free
#deb-src http://ftp.ccc.uba.ar/pub/linux/debian/debian stable main contrib non-free

deb http://mirrors.dcarsat.com.ar/debian/ stable-updates main contrib non-free
#deb-src http://mirrors.dcarsat.com.ar/debian/ stable-updates main contrib non-free

deb http://mirrors.dcarsat.com.ar/debian/ stable main contrib non-free
#deb-src http://mirrors.dcarsat.com.ar/debian/ stable main contrib non-free

deb http://mirrors.dcarsat.com.ar/debian/ stable-updates main contrib non-free
#deb-src http://mirrors.dcarsat.com.ar/debian/ stable-updates main contrib non-free

deb http://security.debian.org/ jessie/updates main contrib non-free
#deb-src http://security.debian.org/ jessie/updates main contrib non-free
" \
	)
}

function get_sources_ubuntu_apt-get() {
	get_sources_ubuntu_apt
}

function get_sources_ubuntu_apt() {
	SOURCES_CONTENTS=( \
"###### Ubuntu Main Repos
deb http://ar.archive.ubuntu.com/ubuntu/ xenial main restricted universe multiverse
#deb-src http://ar.archive.ubuntu.com/ubuntu/ xenial main restricted universe multiverse

###### Ubuntu Update Repos
deb http://ar.archive.ubuntu.com/ubuntu/ xenial-security main restricted universe multiverse
deb http://ar.archive.ubuntu.com/ubuntu/ xenial-updates main restricted universe multiverse
#deb-src http://ar.archive.ubuntu.com/ubuntu/ xenial-security main restricted universe multiverse
#deb-src http://ar.archive.ubuntu.com/ubuntu/ xenial-updates main restricted universe multiverse
" \
	)
}

# To specify a source file for a package manager, create a function named like
# get_sources_filepath_PACKAGEMAN
# Populating it with the array SOURCES_FILEPATHS=( "/full/path/to/source" )
# If you need to specify more files for a specific distro, create a function
# named like
# get_sources_filepath_PACKAGEMAN_DISTRO
# Appending to the array like
# SOURCES_FILEPATHS=( ${SOURCES_FILEPATHS[*]} "/other/source" )
function get_sources_filepath_apt-get() {
	get_sources_filepath_apt
}

function get_sources_filepath_apt() {
	SOURCES_FILEPATHS=( "/etc/apt/sources.list" )
}

function get_sources_filepath_apt-get_huayra() {
	get_sources_filepath_apt_huayra
}

function get_sources_filepath_apt_huayra() {
	SOURCES_FILEPATHS=( ${SOURCES_FILEPATHS[*]} \
											"/etc/apt/sources.list.d/huayra.list" )
}

# Replace the sources file for the given distro
# 1: distro
# 2: packet manager
function replace_sources() {
	local distro="${1}"
	local pm="${2}"
	local f=""
	local i=0
	local sources_filepath=""
	local sources_cont=""

	local sources_filepath_functions=( \
		"get_sources_filepath_${pm}" \
		"get_sources_filepath_${pm}_${distro}" \
	)

	SOURCES_FILEPATHS=( )
	for f in ${sources_filepath_functions[*]}; do
		if function_exists "${f}"; then
			"${f}"
		fi
	done

	if [[ ${#SOURCES_FILEPATHS[*]} -eq 0 ]]; then
		hc_e_err "No hay ruta a las fuentes definida para su manejador de paquetes"
		return 1
	fi

	if function_exists "get_sources_${distro}_${pm}"; then

		get_sources_${distro}_${pm}

		if [[ ${#SOURCES_CONTENTS[*]} -eq 0 ]]; then
			hc_e_err "No hay fuentes definidas para su distro y manejador de paquetes"
			return 1
		fi

		if [[ ${#SOURCES_CONTENTS[*]} -ne ${#SOURCES_FILEPATHS[*]} ]]; then
			hc_e_err "Hay un error en este script: se ha definido erroneamente las \
rutas a fuentes y los contenidos de las mismas. Por favor, reportelo al \
Coordinador de Instaladores"
			return 1
		fi

		for ((i = 0 ; i < ${#SOURCES_CONTENTS[*]} ; i++)); do
			sources_filepath="${SOURCES_FILEPATHS[$i]}"
			sources_cont="${SOURCES_CONTENTS[$i]}"

			hc_e_newline
			hc_e_notice "Su lista actual de paquetes en ${sources_filepath}:"
			cat ${sources_filepath}
			hc_e_newline
			hc_e_msg "Se propone reemplazar el contenido del mismo por:"
			hc_e "${sources_cont}\n"

			read -n 1 -p "Esta de acuerdo? [s/N]: " answer
			hc_e_newline

			if [ "x${answer,,}" == "xs" ]; then
				elevate mv "${sources_filepath}" "${sources_filepath}.bak"
				# ToDo: use system()
				printf "%s" "${sources_cont}" | elevate tee "${sources_filepath}" > /dev/null 2>&1
				if [ $? -eq 0 ]; then
					hc_e_msg "Lista reemplazada"
				else
					hc_e_err "Ocurrio algun error al tratar de reemplazar la lista"
					return 1
				fi
			fi
		done

		return 0
	fi

	return 1
}

# Opens a URL in the system web browser, and returns the exit value
function open_webbrowser() {
	local url="$1"

	xopen="$(which xdg-open || which gnome-open || which firefox || which chrome || which chromium)"
	[[ -x "$xopen" ]] && "$xopen" "$url"& > /dev/null 2>&1 && return $?

	return 1
}

# Sets global to determinate wheter we have elevated privs or not
function am_i_root() {
	if [ "$(whoami)" == "root" ]; then
		IM_ROOT=$hc_true
	fi
}

# Checks prerequisites for the script
function prereq() {
	am_i_root
	[ ! ${IM_ROOT} ] \
		&& [ ! -x "$(which sudo)" ] \
		&& bail_out "No se puede elevar privilegios!\n\
Instale 'sudo' o ejecute este script como root"

	if [ -f "${SCRIPT_SIGNATURE_FILE}" ]; then
		hc_e_notice "Este script ya fue ejecutado y finalizo exitosamente"
		read -n 1 -p 'Esta seguro que desea ejecutarlo nuevamente? [s/N]' answer
		hc_e_newline

		[ "${answer,,}" != "s" ] && exit 0

		rm "${SCRIPT_SIGNATURE_FILE}" > /dev/null 2>&1
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
	cat <<EOF
Hola! Bienvenido al FLISoL ${FLISOL_EVENT} ${FLISOL_YEAR} #${FLISOL_EDITION}!
Esperamos que este disfrutando este dia, y que haya aprendido mucho con esta instalacion y las charlas.

A continuacion vamos a guiarle para terminar de configurar el sistema, y sin duda tendra un instalador cerca suyo que le estara ayudando.

Para detener la ejecucion de este escript en cualquier momento, presione CTRL+C.
EOF
}

function goodbye() {
	cat <<EOF
Hemos terminado :)
No fue tan dificil, no?

Ahora si, lo dejamos con su sistema para que lo disfrute, cualquier duda que tenga acerquese a uno de los instaladores o revise las opciones de contacto en nuestra web: ${EVENTOL_URL_BASE}/event/${EVENTOL_URL_EVENT}

Un abrazo grande,
- El equipo de FLISoL ${FLISOL_EVENT}
EOF
}

function finish() {
	goodbye

	drop_signature_file

	exit 0
}

# Returns 0 if OS is supported by this script, 1 otherwise
function is_os_supported() {
	local this_os="$1"
	local os=""

	for os in ${SUPPORTED_OS[*]}; do
		if [ "${os}" == "${this_os}" ]; then
			return 0
		fi
	done

	return 1
}

# Returns 0 if OS is supported by this script, 1 otherwise
function is_distro_supported() {
	local this_distro="$1"
	local distro=""

	for distro in ${SUPPORTED_DIST[*]}; do
		if [ "${distro}" == "${this_distro}" ]; then
			return 0
		fi
	done

	return 1
}
# <>

# Tasks for the main loop

# Verify that the OS is supported by this script
function task_verify_os() {
	local os=""
	local answer=""

	hc_e_msg "Verificando sistema operativo..."

	os="$(get_os_type)"
	hc_e_msg "Se detecto que su sistema operativo es ${os}"

	if [ -z "${os}" ]; then
		hc_e_warn "Debe especificar su sistema operativo manualmente para \
continuar con esta tarea"
		answer="s"
	else
		read -n 1 -p "Desea especificar manualmente su sistema operativo? [s/N]: " answer
		hc_e_newline
	fi

	if [ "x${answer,,}" == "xs" ]; then
		hc_e_msg "Especifique el sistema operativo. Puede ayudarse eligiendo de \
las siguientes: ${SUPPORTED_OS[*]}"
		os="$(cin 'OS: ')"
	fi

	if is_os_supported "$os"; then
		hc_e_msg "Este script es compatible con su sistema ${os}"
		return 0
	else
		hc_e_err "Este script no es compatible con su sistema ${os}"
		hc_e_msg "Sistemas compatibles: ${SUPPORTED_OS[*]}"
	fi

	return 1
}

# Verify that the distro is supported by this script
function task_verify_distro() {
	local distro=""
	local answer=""

	hc_e_msg "Verificando distro..."

	distro="$(get_distro)"
	hc_e_msg "Se detecto que su distro es ${distro}"

	if [ -z "${distro}" ]; then
		hc_e_warn "Debe especificar la distro manualmente para continuar con \
esta tarea"
		answer="s"
	else
		read -n 1 -p "Desea especificar manualmente su distro? [s/N]: " answer
		hc_e_newline
	fi

	if [ "x${answer,,}" == "xs" ]; then
		hc_e_msg "Especifique el nombre de su distro. Puede ayudarse eligiendo de \
las siguientes: ${SUPPORTED_DIST[*]}"
		distro="$(cin 'Distro: ')"
	fi

	if is_distro_supported "$distro"; then
		hc_e_msg "Este script es compatible con su distro ${distro}"
		DISTRO="${distro}"
		return 0
	else
		hc_e_err "Este script no es compatible con su distro ${distro}"
		hc_e_msg "Distros compatibles: ${SUPPORTED_DIST[*]}"
	fi

	return 1
}

# ToDo: change wallpaper on every distro
# https://forum.xfce.org/viewtopic.php?id=3335
# http://unix.stackexchange.com/questions/116539/how-to-detect-the-desktop-environment-in-a-bash-script
# http://askubuntu.com/questions/72549/how-to-determine-which-window-manager-is-running
function task_change_wallpaper() {
	hc_e_msg "Le ofrecemos fondos de pantalla para su sistema.\n\
Si desea descargarlos y/o ver los disponibles, dirijase a\n\
${POSTINSTALL_URL}/wallpaper"
	open_webbrowser "${POSTINSTALL_URL}/wallpapers.html"
	if [ $? -ne 0 ]; then
		hc_e_err "No se ha podido abrir un navegador, por favor dirijase a la \
URL indicada"
	fi
	press_any_key
	return 0
}

# Attempts to fix /etc/network/interfaces: after booting with PXE, a static
# IP is probably configured, which might cause issues with Network-Manager
function task_fix_interfaces() {
	hc_e_msg "Corrijamos la configuracion de red"

	hc_e_msg "La configuracion actual es: cat /etc/network/interfaces"
	cat /etc/network/interfaces

	read -n 1 -p "Desea corregir automaticamente el archivo? [S/n]: " answer
	hc_e_newline

	[ "x${answer,,}" == "xn" ] && return 0

	elevate mv /etc/network/interfaces /etc/network/interfaces.bak
	# I prefer not to use tee, I don't know if it's everywhere
	# Otherwise, this line could be:
	# echo -e "auto lo\niface lo inet loopback\n" | elevate tee /etc/network/interfaces
	# NOT WORKING! COULDN'T FIND OUT WHY
	#system 'echo -e "auto lo\niface lo inet loopback\n" > /etc/network/interfaces' 1
	echo -e "auto lo\niface lo inet loopback\n" | elevate tee /etc/network/interfaces > /dev/null 2>&1

	if [ $? -eq 0 ]; then
		hc_e_msg "Listo"
	else
		hc_e_err "Ocurrio algun error al tratar de escribir el archivo"
		return 1
	fi

	# ToDo: list_interfaces...
	# read -n 1 -p 'Quiere configurar automaticamente las interfaces o dejar que \
	#                             lo haga Network-Manager? [s/N]: ' answer
	# if [ "${answer,,}" == "s" ]; then
	#     interfaces=$(list_interfaces)
	#     for interface in interfaces; do
	#         system 'echo -e "auto ${interface}\niface ${interface} inet dhcp\n" >> /etc/network/interfaces' 1
	#         sync
	#         elevate ifdown ${interface}
	#         elevate ifup ${interface}
	#     done
	# fi

	hc_e_msg "Ha quedado asi: cat /etc/network/interfaces"
	cat /etc/network/interfaces

	return 0
}

function task_fix_sources() {
	hc_e_msg "Se corregiran las listas de fuentes de paquetes de su distro"

	if [ -z "${PACKAGE_MANAGER_BIN}" ] || [ -z "${DISTRO}" ]; then
		hc_e_msg "No se ha especificado gestor de paquetes y/o distro, por lo \
que este script no puede determinar fehacientemente cual es su lista de \
paquetes. Debera realizar los cambios manualmente como considere mas apropiado"
		press_any_key
		return 1
	fi

	replace_sources "${DISTRO}" "${PACKAGE_MANAGER_BIN}"
	return $?
	}

# Opens eventoL or displays url if fails, plus instructions
function task_open_eventol() {
	local url="${EVENTOL_URL_BASE}/event/${EVENTOL_URL_EVENT}"

	cat <<EOF
Vamos a registrar la instalacion en eventoL, que es nuestro sistema libre para administracion de eventos (disponible en https://github.com/GNUtn/eventoL). A continuacion se abrira el navegador con la pagina del evento.
Para registrar la instalacion, siga estos pasos:
 1- Pidale al instalador que inicie sesion con su usuario
 2- Registre la instalacion en Colaboradores > Cargar una instalacion
 3- Complete los campos indicados
 4- Recuerdele al instalador que aplica para el desafio:
    http://wiki.cafelug.org.ar/index.php/Flisol/2016/Instaladores/Instalaciones

Si no se encuentra registrado, debe crear una cuenta en la seccion Iniciar sesion y luego en Registrarme

Al terminar, podra continuar la ejecucion de este script

EOF

	open_webbrowser "$url"
	if [ $? -ne 0 ]; then
		hc_e_err "No se ha podido abrir un navegador, por favor dirijase a esta \
URL:\n\t${url}"
	fi

	hc_e_msg "Registre la instalacion, lo espero..."
	press_any_key

	return 0
}

# Select the package manager, let the user choose
function task_select_package_manager() {
	local answer=""

	PACKAGE_MANAGER_BIN="$(get_package_manager)"
	PACKAGE_MANAGER_INSTALL_PARAMS="$(get_package_manager_install_params ${PACKAGE_MANAGER_BIN})"
	PACKAGE_MANAGER_UPDATE_PARAMS="$(get_package_manager_update_params ${PACKAGE_MANAGER_BIN})"
	PACKAGE_MANAGER_UPGRADE_PARAMS="$(get_package_manager_upgrade_params ${PACKAGE_MANAGER_BIN})"

	hc_e_msg "Se ha detectado el siguiente gestor de paquetes: ${PACKAGE_MANAGER_BIN}"
	hc_e_msg "Cuyos parametros son: "
	hc_e_msg " - Para instalar:              \t${PACKAGE_MANAGER_INSTALL_PARAMS}"
	hc_e_msg " - Para actualizar repositorio:\t${PACKAGE_MANAGER_UPDATE_PARAMS}"
	hc_e_msg " - Para actualizar sistema:    \t${PACKAGE_MANAGER_UPGRADE_PARAMS}"

	if [ -z "${PACKAGE_MANAGER_BIN}" ]; then
		hc_e_warn "El gestor es desconocido, debera indicar un gestor de \
paquetes\nDe no hacerlo, el script le solicitara que instale los paquetes \
necesarios manualmente"
		answer="s"
	else
		read -n 1 -p 'Desea utilizar otro gestor de paquetes o especificar otro/s parametro/s? [s/N]: ' answer
		hc_e_newline
	fi

	if [ "x${answer,,}" == "xs" ]; then
		PACKAGE_MANAGER_BIN="$(cin 'Escriba el nombre del binario del gestor de paquetes a utilizar: ')"
		PACKAGE_MANAGER_INSTALL_PARAMS="$(cin 'Escriba los parametros que debe pasarsele al gestor para instalar un paquete: ')"
		PACKAGE_MANAGER_UPDATE_PARAMS="$(cin 'Escriba los parametros que debe pasarsele al gestor para actualizar la lista de paquetes: ')"
		PACKAGE_MANAGER_UPGRADE_PARAMS="$(cin 'Escriba los parametros que debe pasarsele al gestor para actualizar todos los paquetes: ')"
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
		press_any_key
		return 1
	fi

	packages_upgrade
	if [ $? -ne 0 ]; then
		hc_e_err "La actualizacion de paquetes no termino satisfactoriamente.\n\
Revise el registro de ejecucion y corrija los problemas"
		press_any_key
		return 1
	fi

	return 0
}
# <>

# main()
trap ctrl_c INT

prereq

welcome

# Globals
PACKAGE_MANAGER_BIN=""
PACKAGE_MANAGER_INSTALL_PARAMS=""
PACKAGE_MANAGER_UPDATE_PARAMS=""
PACKAGE_MANAGER_UPGRADE_PARAMS=""
DISTRO=""

IM_ROOT=$hc_false

SOURCES_FILEPATHS=( )
SOURCES_CONTENTS=( )
# <>

repeat_main_loop=$hc_true
for t in ${TASKS[@]}; do
	while [ $repeat_main_loop ]; do
		repeat_main_loop=$hc_false

		print_line
		$t
		if [ $? -ne 0 ]; then
			print_line
			hc_e_err "La tarea ha finalizado con fallo. Qué desea hacer?"
			hc_e "\t1- Repetir tarea (por defecto)\n\
\t2- Continuar sin repetir tarea\n\
\t3- Salir del script\n"
			read -n 1 -p "Seleccione una opcion para continuar: " answer
			hc_e_newline

			case "${answer}" in
				"2")
					repeat_main_loop=$hc_false
					;;

				"3")
					bail_out "Saliendo con error..."
					;;

				*)
					repeat_main_loop=$hc_true
					;;
			esac
		fi
	done
	repeat_main_loop=$hc_true
done

finish
# <>
