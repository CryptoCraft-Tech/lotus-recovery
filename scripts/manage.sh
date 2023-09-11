#!/bin/bash
#该文件路径需管理机、Worker机器均能读写的路径
WORKER_LIST="/storage/worker.list"
#该路径与worker.list路径保持一致
LOCKFILE="/storage/worker.lock"
#可恢复扇区列表文件路径
SECTORSID_LIST="sectorsid.list"
#Worker机器上run_recovery.sh文件存放的路径
RECOVERY_SCRIPT="/storage/run_recovery.sh"
#管理机上allowcores.list存放的路径
ALLOWCORES_LIST="allowcores.list"
#Worker机器最大运行P1进程数
MAX_NUM=14
#存储目录个数，可以实现均匀落盘，例如3个存储目录，则需要存储的统一挂载目录为/data1、/data2、/data3，即尾数与目录个数数字匹配
STORAGE_NUM=3
#恢复的扇区数量，达到该数值脚本自动停止
SECTOR_NUM=100

i=1
j=1
update_all_nums() {
    while read -r worker_ip; do
        (
            flock -x 200
            tmux_count=$(ssh "$worker_ip" "tmux list-sessions | grep '^recovery' | wc -l" </dev/null)
            awk -v ip="$worker_ip" -v count="$tmux_count" -F' ' '/IP/ && $2 == ip { $4=count } {print}' $WORKER_LIST >${WORKER_LIST}.tmp && mv ${WORKER_LIST}.tmp /storage13/worker1.list
        ) 200>$LOCKFILE
    done < <(awk '/IP/ {print $2}' $WORKER_LIST)
}

while read -r sectorid; do
    update_all_nums
    read -r ip num core <<<$(awk '/IP/ {ip=$2; num=$4; cores=""; for (i=6; i<=NF; i++) cores=(cores==""?"":cores" ")$i; print ip, num, cores}' $WORKER_LIST | sort -k2n | head -n1 | awk '{printf $1" "$2" "; for (i=3; i<=NF; i++) printf $i" "; print ""}')

    while ((num >= MAX_NUM)); do
        echo "---------full sleep----------"
        sleep 60
        update_all_nums
        read -r ip num core <<<$(awk '/IP/ {ip=$2; num=$4; cores=""; for (i=6; i<=NF; i++) cores=(cores==""?"":cores" ")$i; print ip, num, cores}' $WORKER_LIST | sort -k2n | head -n1 | awk '{printf $1" "$2" "; for (i=3; i<=NF; i++) printf $i" "; print ""}')
    done

    coregroup=$(grep "$ip" $ALLOWCORES_LIST | awk '/IP/ {cores=""; for (i=4; i<=NF; i++) cores=cores" "$i; print cores}')

    if [ -n "$core" ]; then
        for c in $core; do
            coregroup=${coregroup//$c/}
        done
    fi
    endcore=$(echo "$coregroup" | awk '{print $1}')
    (
        flock -x 200
        sed -i "/^IP $ip /s/$/ $endcore/" $WORKER_LIST
    ) 200>$LOCKFILE
    echo "-----$sectorid-----$ip-----$endcore-------$i------"
    ssh "$ip" "tmux new-session -d -s recovery-$sectorid '$RECOVERY_SCRIPT $endcore $sectorid $i $ip  2>&1 | tee /storage/log/$sectorid.log'" </dev/null

    sed -i '1d' $SECTORSID_LIST

    ((i++))
    if [ "$i" -eq "$STORAGE_NUM" ]; then
        i=1
    fi
    if [ "$j" -eq "$SECTOR_NUM" ]; then
        break
    fi
    ((j++))

    echo "------sleep------"
    sleep 90

done <$SECTORSID_LIST
