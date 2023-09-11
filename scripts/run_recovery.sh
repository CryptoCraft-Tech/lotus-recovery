#!/bin/bash
CORES=$1
SECTOR_ID=$2
SID=$3
IP=$4

#该文件路径需管理机、Worker机器均能读写的路径，与manage.sh中为同一路径
WORKER_LIST="/storage1/worker1.list"
#该路径与worker.list路径保持一致
LOCKFILE="/storage1/worker1.lock"
#该文件输出恢复出错的扇区列表
RECO_FAULTS_LIST="/storage/reco_faults.list"

export FIL_PROOFS_MAXIMIZE_CACHING=1
export FIL_PROOFS_USE_MULTICORE_SDR=1
export FIL_PROOFS_MULTICORE_SDR_PRODUCERS=1
#该路径需要对应修改
export TMPDIR=/storage/recotmp
#该路径需要对应修改
export FIL_PROOFS_PARENT_CACHE=/storage/filecoin-parents-reco
export FIL_PROOFS_USE_GPU_COLUMN_BUILDER=1
export FIL_PROOFS_USE_GPU_TREE_BUILDER=1
export FIL_PROOFS_MULTICORE_SDR_CORES="${CORES}"

#该命令中的路径修改请参考文档中的释义进行
lotus-recovery sectors recover --recovery-metadata=/storage/sectors-f02228866.json --recovery-key=N0nvYJ9sp+dczDbj4PWftUmJ3Wsn9xYyEtMEMh2D9TA= --recovering-from=/mnt/data4 --recovering-to=/storage/recover/recovering-to --is-deal=true --by-unsealed=false ${SECTOR_ID}

#需要修改源文件的路径和最终落盘存储的路径
if [ -e "/storage/recover/recovering-to/cache/s-t08866-${SECTOR_ID}/t_aux" ]; then
    mv "/storage/recover/recovering-to/cache/s-t08866-${SECTOR_ID}" "/storage${SID}/cache/"
    mv "/storage/recover/recovering-to/sealed/s-t08866-${SECTOR_ID}" "/storage${SID}/sealed/"
    mv "/storage/recover/recovering-to/unsealed/s-t08866-${SECTOR_ID}" "/storage${SID}/unsealed/"
else
    echo "${SECTOR_ID}" >>$RECO_FAULTS_LIST
fi

(
    flock -x 200
    awk -v ip="${IP}" -v cores="${CORES}" '{
    if ($2 == ip) {
        printf "%s %s %s %s %s", $1, $2, $3, $4, $5;
        for (i = 6; i <= NF; i++) {
            if ($i != cores) {
                printf " %s", $i;
            }
        }
        printf "\n";
    } else {
        print $0;
    }
}' $WORKER_LIST >${WORKER_LIST}.tmp && mv ${WORKER_LIST}.tmp $WORKER_LIST
) 200>$LOCKFILE

tmux kill-session -t recovery-"${SECTOR_ID}"
