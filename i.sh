#!/bin/bash
# Айра: первый запуск на чистом сервере Ubuntu (выполняется один раз от root).
# Создаёт пользователя aira, ключ доступа к закрытому репозиторию с кодом,
# спрашивает пароль для дашборда и ждёт, пока ключ добавят в GitHub.
set -euo pipefail
REPO=git@github.com:Murzali1/aira-cloud.git
[ "$(id -u)" = 0 ] || { echo "Запустите от root"; exit 1; }
echo "== Айра: подготовка сервера =="
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq git curl openssh-client sudo >/dev/null
id aira >/dev/null 2>&1 || useradd -m -s /bin/bash aira
install -d -m 700 -o aira -g aira /home/aira/.ssh
[ -f /home/aira/.ssh/id_ed25519 ] || sudo -u aira ssh-keygen -q -t ed25519 -N '' -C aira-server -f /home/aira/.ssh/id_ed25519
ssh-keyscan -t ed25519 github.com 2>/dev/null > /home/aira/.ssh/known_hosts
chown aira:aira /home/aira/.ssh/known_hosts
install -d -m 700 /etc/aira
if [ ! -s /etc/aira/dashboard.pass ]; then
  while true; do
    read -rsp "Придумайте пароль для дашборда Айры (не меньше 8 символов): " P </dev/tty; echo
    read -rsp "Повторите пароль: " P2 </dev/tty; echo
    if [ "${#P}" -ge 8 ] && [ "$P" = "$P2" ]; then break; fi
    echo "Пароли не совпали или короче 8 символов, ещё раз."
  done
  umask 077; printf '%s' "$P" > /etc/aira/dashboard.pass; unset P P2
fi
echo
echo "============================================================"
echo " Отправьте Claude эту строку (открытый ключ, не секретный):"
echo
cat /home/aira/.ssh/id_ed25519.pub
echo "============================================================"
echo "Жду, пока ключ добавят в GitHub (можно не закрывать окно)…"
until sudo -u aira git ls-remote "$REPO" >/dev/null 2>&1; do sleep 15; printf '.'; done
echo; echo "Ключ подключён. Устанавливаю Айру (10–15 минут)…"
install -d -o aira -g aira /opt/aira
[ -d /opt/aira/src/.git ] || sudo -u aira git clone -q "$REPO" /opt/aira/src
bash /opt/aira/src/cloud/install.sh
