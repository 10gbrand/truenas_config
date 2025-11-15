#!/usr/bin/env bash

# Ladda .env
if [ ! -f .env ]; then
    echo ".env saknas!"
    exit 1
fi
export $(grep -v '^#' .env | xargs)

# Kontrollera miljövariabler
if [ -z "$IMMICH_URL" ] || [ -z "$IMMICH_API_KEY" ] || [ -z "$PHOTO_DIR" ]; then
    echo "Fel: IMMICH_URL, IMMICH_API_KEY eller PHOTO_DIR saknas i .env"
    exit 1
fi

# Loggfiler
LOGFILE="immich_upload.log"
ERRORLOG="immich_errors.log"

echo "Startar upload $(date)" | tee -a "$LOGFILE"

# Funktion för att räkna hash
get_hash() {
    local file="$1"
    shasum -a 256 "$file" | awk '{print $1}'
}

# Hämta alla filtyper som Immich stödjer
find "$PHOTO_DIR" -type f \( \
    -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
    -o -iname "*.heic" -o -iname "*.webp" -o -iname "*.gif" \
    -o -iname "*.mp4" -o -iname "*.mov" \
\) | while read -r FILE; do

    echo "➡️ Fil hittad: $FILE" | tee -a "$LOGFILE"
    
    HASH=$(get_hash "$FILE")

    echo "   Beräknar hash: $HASH" >> "$LOGFILE"

    # Kontrollera om filen redan finns i Immich
    EXISTS=$(curl -s -X GET "$IMMICH_URL/api/assets/exist?checksum=$HASH" \
        -H "x-api-key: $IMMICH_API_KEY" | grep -o '"exists":true')

    if [ "$EXISTS" = "\"exists\":true" ]; then
        echo "   ⏭  Hoppar över: Finns redan i Immich" | tee -a "$LOGFILE"
        continue
    fi

    echo "   Laddar upp ..." | tee -a "$LOGFILE"

    # Ladda upp filen
    curl -s -X POST "$IMMICH_URL/api/assets" \
        -H "x-api-key: $IMMICH_API_KEY" \
        -H "Accept: application/json" \
        -F "assetData=@${FILE}" \
        -F "deviceAssetId=$(basename "$FILE")-$(uuidgen)" \
        -F "deviceId=upload-script" \
        -F "fileCreatedAt=$(date -r "$FILE" -Iseconds)" \
        -F "fileModifiedAt=$(date -r "$FILE" -Iseconds)" \
        >> "$LOGFILE" 2>> "$ERRORLOG"

    # Kontrollera om uppladdningen lyckades
    if [ $? -eq 0 ]; then
        echo "   ✔ Uppladdad" | tee -a "$LOGFILE"
    else
        echo "   ❌ Fel vid uppladdning: $FILE" | tee -a "$ERRORLOG"
    fi
done

echo "🎉 Klar! Logg finns i $LOGFILE"
