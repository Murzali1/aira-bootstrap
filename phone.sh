#!/data/data/com.termux/files/usr/bin/bash
# Айра: домашний мост на телефоне (Termux).
# Телефон держит туннель к серверу Айры, и сервер заходит на медсайты
# через домашний интернет. Ничего, кроме этого туннеля, телефон серверу не открывает.
set -e
HOST=89-126-194-112.sslip.io
IP=89.126.194.112
echo "== Айра: настройка домашнего моста"
yes | pkg update -y >/dev/null 2>&1 || true
pkg install -y openssh curl >/dev/null
mkdir -p ~/.ssh ~/.termux/boot
[ -f ~/.ssh/aira_bridge ] || ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/aira_bridge -C aira-phone

echo
echo "Введите пароль от дашборда Айры (буквы на экране не появляются) и нажмите Enter:"
read -rs P </dev/tty; echo
T=$(curl -fsS -u "aira:$P" "https://$HOST/api/aira/session" | sed -E 's/.*"token": *"([^"]+)".*/\1/')
[ -n "$T" ] || { echo "Не получилось войти — проверьте пароль и запустите ещё раз."; exit 1; }
K=$(cut -d' ' -f1,2 ~/.ssh/aira_bridge.pub)
R=$(curl -sS -u "aira:$P" -H "X-Aira-Token: $T" -H 'Content-Type: application/json' \
     -d "{\"key\":\"$K\"}" "https://$HOST/api/aira/bridge/key")
unset P
echo "$R" | grep -q '"ok": true' || { echo "Сервер ответил: $R"; exit 1; }

cat > ~/aira-bridge.sh <<LOOP
#!/data/data/com.termux/files/usr/bin/bash
# aira-bridge-loop: держит туннель, переподключается после обрыва связи.
termux-wake-lock 2>/dev/null || true
while true; do
  ssh -N -i ~/.ssh/aira_bridge -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \\
      -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=accept-new -o BatchMode=yes \\
      -R 127.0.0.1:1080 tunnel@$IP >/dev/null 2>&1
  sleep 15
done
LOOP
chmod +x ~/aira-bridge.sh
cat > ~/.termux/boot/aira-bridge <<'BOOT'
#!/data/data/com.termux/files/usr/bin/bash
pkill -f aira-bridge.sh 2>/dev/null
nohup ~/aira-bridge.sh >/dev/null 2>&1 &
BOOT
chmod +x ~/.termux/boot/aira-bridge
~/.termux/boot/aira-bridge
# Без Termux:Boot: после перезагрузки телефона мост стартует, как только откроют Termux.
grep -q aira-bridge ~/.bashrc 2>/dev/null || echo 'pgrep -f aira-bridge.sh >/dev/null || ~/.termux/boot/aira-bridge' >> ~/.bashrc

echo
echo "Готово. Телефон привязан, мост запустится в течение 1–2 минут."
echo "Termux можно свернуть (не закрывать)."
