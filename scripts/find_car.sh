#!/bin/bash
JSON_FILE="$HOME/sectors-f0888866.json"
CAR_PATH="/mnt/data*"

>unfind.list
>prepare.list

jq -c '.SectorInfos[]' "$JSON_FILE" | while read -r sector; do
    sectorNumber=$(echo "$sector" | jq '.SectorNumber')
    pieceInfos=$(echo "$sector" | jq -c '.PieceInfo[]')

    allFound=true
    index=0
    echo "$pieceInfos" | while read -r pieceInfo; do
        pieceCID=$(echo "$pieceInfo" | jq -r '.PieceCID["/"]')
        fileFound=$(sudo find "$CAR_PATH" -type f -name $pieceCID.car -print -quit)

        if [[ -z "$fileFound" ]]; then
            echo "SectorNumber: $sectorNumber, PieceCID: $pieceCID" >>unfind.list
            allFound=false
        else
            jq --arg sectorNum "$sectorNumber" --arg file "$fileFound" --argjson idx "$index" '.SectorInfos |= map(if .SectorNumber == ($sectorNum | tonumber) then .CarFiles[$idx] = $file else . end)' "$JSON_FILE" >tmp.json && mv tmp.json "$JSON_FILE"
        fi
        index=$((index + 1))
    done

    if $allFound; then
        echo "$sectorNumber" >>prepare.list
    fi
done
