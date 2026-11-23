#!/bin/bash
# Script de Detecção Dinâmica de Rede para o Conky (Wi-Fi e Ethernet)

# Detectar interface de rede padrão ativa
IFACE=$(ip route 2>/dev/null | awk '/^default/ {for(i=1;i<=NF;i++) if($i=="dev") print $(i+1); exit}')

if [ -z "$IFACE" ]; then
    echo "» Rede: Desconectado"
    echo "» Upload: 0 B/s"
    echo "» Download: 0 B/s"
    echo "» Total Enviado: 0 B / Total Recebido: 0 B"
    exit 0
fi

# Verificar se a interface é Wi-Fi
IS_WIFI=false
if [ -d "/sys/class/net/$IFACE/wireless" ] || [ -f "/sys/class/net/$IFACE/phy80211/name" ]; then
    IS_WIFI=true
elif command -v iw &>/dev/null && iw dev "$IFACE" info &>/dev/null; then
    IS_WIFI=true
fi

if [ "$IS_WIFI" = true ]; then
    SSID=""
    if command -v iwgetid &>/dev/null; then
        SSID=$(iwgetid -r 2>/dev/null)
    fi
    if [ -z "$SSID" ] && command -v nmcli &>/dev/null; then
        SSID=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F':' '$1=="sim" || $1=="yes" {print $2; exit}')
    fi
    if [ -z "$SSID" ] && command -v iw &>/dev/null; then
        SSID=$(iw dev "$IFACE" link 2>/dev/null | awk -F': ' '/SSID/ {print $2; exit}')
    fi
    [ -z "$SSID" ] && SSID="Conectado"
    echo "» Wi-Fi: $SSID"
else
    echo "» Ethernet: Conectado"
fi

echo "» Upload: \${upspeed $IFACE}"
echo "» Download: \${downspeed $IFACE}"
echo "» Total Enviado: \${totalup $IFACE} / Total Recebido: \${totaldown $IFACE}"
