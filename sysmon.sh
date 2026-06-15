#!/usr/bin/env bash
# sysmon.sh — lightweight macOS CPU/MEM monitor

INTERVAL=2
W=40
TOTAL_BYTES=$(sysctl -n hw.memsize 2>/dev/null); [[ -z $TOTAL_BYTES ]] && TOTAL_BYTES=1

R=$'\033[0m'; B=$'\033[1m'; D=$'\033[2m'
CY=$'\033[36m'; MG=$'\033[35m'

bar() {
    local p=$1 n e s c i
    c=$(awk -v x="$p" 'BEGIN{
        if(x+0<50) printf"\033[32m"
        else if(x+0<80) printf"\033[33m"
        else printf"\033[31m"
    }')
    n=$(awk -v x="$p" -v w=$W 'BEGIN{v=int(x*w/100+.5);if(v>w)v=w;if(v<0)v=0;print v}')
    e=$(( W - n )); s=""
    for((i=0;i<n;i++)); do s+="█"; done
    for((i=0;i<e;i++)); do s+="░"; done
    printf "${c}[${s}]${R} ${B}%5.1f%%${R}" "$p"
}

while true; do
    TDATA=$(top -l 1 -n 0 2>/dev/null)

    IDLE=$(echo "$TDATA" | grep "CPU usage" | grep -oE '[0-9.]+% idle' | grep -oE '^[0-9.]+')
    CPU=$(awk -v i="${IDLE:-0}" 'BEGIN{printf"%.1f",100-i}')

    # MEM: Activity Monitor 방식 (App + Wired + Compressed) / 총 RAM
    read -r MP UG TG <<<"$(vm_stat 2>/dev/null | awk -F: -v total="$TOTAL_BYTES" '
        /page size of/                {match($0,/[0-9]+/); ps=substr($0,RSTART,RLENGTH)}
        /Pages wired down/            {gsub(/[ .]/,"",$2); w=$2}
        /Pages occupied by compressor/{gsub(/[ .]/,"",$2); c=$2}
        /Anonymous pages/             {gsub(/[ .]/,"",$2); a=$2}
        /Pages purgeable/             {gsub(/[ .]/,"",$2); p=$2}
        END{
            used=(w+c+(a-p))*ps; if(total<1)total=1
            printf "%.1f %.1f %.1f", used/total*100, used/1073741824, total/1073741824
        }')"

    PSDATA=$(ps -Ao pid,pcpu,pmem,command 2>/dev/null | awk 'NR>1{
        n=split($4,a,"/"); $4=a[n]; $1=$1; print
    }')
    TC5=$(sort -k2 -rn <<<"$PSDATA" | head -5)
    TM5=$(sort -k3 -rn <<<"$PSDATA" | head -5)

    clear
    printf "\n"
    printf "  ${B}${CY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}\n"
    printf "  ${B}${CY}  macOS System Monitor          %s${R}\n" "$(date '+%H:%M:%S')"
    printf "  ${B}${CY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}\n\n"

    printf "  ${B}CPU${R}  "; bar "$CPU"; printf "\n"
    printf "  ${B}MEM${R}  "; bar "$MP"; printf "  ${D}${UG}G / ${TG}G${R}\n\n"

    printf "  ${B}${CY}▸ Top 5  CPU${R}\n"
    printf "  ${D}%7s  %6s  %6s  %-30s${R}\n" "PID" "CPU%" "MEM%" "PROCESS"
    awk '{printf"  %7s  %6s  %6s  %-30.30s\n",$1,$2,$3,$4}' <<<"$TC5"

    printf "\n  ${B}${MG}▸ Top 5  MEM${R}\n"
    printf "  ${D}%7s  %6s  %6s  %-30s${R}\n" "PID" "CPU%" "MEM%" "PROCESS"
    awk '{printf"  %7s  %6s  %6s  %-30.30s\n",$1,$2,$3,$4}' <<<"$TM5"

    printf "\n  ${D}[q] 종료  •  매 ${INTERVAL}초 갱신${R}\n\n"

    read -t $INTERVAL -n1 k 2>/dev/null
    [[ $k == q ]] && { printf "\n"; break; }
done
