#!/bin/bash

CORES=$1
SECTOR_ID=$2
SID=$3
IP=$4

LOCKFILE="/storage1/worker1.lock"
WORKER_LIST="/storage1/worker1.list"
RECO_FAULTS_LIST="/storage/reco_faults.list"
CUDANUM=$((SID % 2))

export FIL_PROOFS_MAXIMIZE_CACHING=1
export FIL_PROOFS_USE_MULTICORE_SDR=1
export FIL_PROOFS_MULTICORE_SDR_PRODUCERS=1
export FIL_PROOFS_PARENT_CACHE=/storage/filecoin-parents-reco
export FIL_PROOFS_USE_GPU_COLUMN_BUILDER=1
export FIL_PROOFS_USE_GPU_TREE_BUILDER=1
export FIL_PROOFS_MULTICORE_SDR_CORES="${CORES}"

env CUDA_VISIBLE_DEVICES=${CUDANUM} TMPDIR=/storage/recotmp${CUDANUM} lotus-recovery sectors recover --recovery-metadata=/storage/sectors-f02228866.json --recovery-key=+q28qE44PC3NdoNKuIuIlHaoVX9sg5eT6dCJ9fwdTK0= --recovering-from=/mnt/data4 --recovering-to=/storage/recover/recovering-to --is-deal=true --by-unsealed=false ${SECTOR_ID}

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
