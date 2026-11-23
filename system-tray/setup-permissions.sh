#!/bin/bash
# Script opcional para permitir ligar/desligar serviços sem pedir senha do sudo/polkit toda vez

echo "========================================================="
echo "Configuração de Permissões para o System Tray"
echo "========================================================="
echo "No Linux, alterar o status de serviços do sistema (como MariaDB/Docker)"
echo "pode solicitar autorização de administrador."
echo ""
echo "Deseja configurar uma regra do Polkit para gerenciar serviços sem pedir senha?"
echo "(Requer senha de sudo uma única vez para instalar a regra)"
echo ""
read -p "Deseja instalar a regra agora? [s/N]: " resp

if [[ "$resp" =~ ^[sS]$ ]]; then
    sudo tee /etc/polkit-1/rules.d/50-system-tray.rules > /dev/null << 'RULE'
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.systemd1.manage-units" && subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
RULE
    echo "✅ Regra do Polkit instalada com sucesso!"
else
    echo "Operação cancelada. O sistema continuará pedindo confirmação quando necessário."
fi
