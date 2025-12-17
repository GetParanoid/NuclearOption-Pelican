#!/bin/bash
set -euo pipefail

# Configuration
readonly APP_ID="3930080"
readonly WORKSHOP_APP_ID="2168680"
readonly MISSION_DIR="/home/container/missions/"
readonly CONFIG_PATH="DedicatedServerConfig.json"
readonly FRAMERATE="${FRAMERATE:-30}"
readonly STEAMCMD="/home/container/steamcmd/steamcmd.sh"
readonly FORCE_PLATFORM="+@sSteamCmdForcePlatformType linux"
readonly HOME=/home/container

export HOME
mkdir -p "$HOME"

# Logging
log() {
    echo "[$(date -Is)] $*"
}

# Convert string to boolean (returns 0 for true, 1 for false)
is_enabled() {
    local value="${1:-0}"
    case "${value,,}" in
        1|true|yes|on) return 0 ;;
        *) return 1 ;;
    esac
}

# Sanitize filenames/folder names
sanitize_name() {
    local name="$1"
    local fallback="${2:-unnamed}"
    local clean
    
    clean=$(echo "$name" | tr -cd '[:alnum:]._ +-' | sed 's/^ *//;s/ *$//')
    echo "${clean:-$fallback}"
}

# Fetch workshop item IDs from a collection
fetch_collection_items() {
    local collection_id="$1"
    
    curl -s -X POST \
        -d "collectioncount=1&publishedfileids[0]=${collection_id}" \
        https://api.steampowered.com/ISteamRemoteStorage/GetCollectionDetails/v1/ | \
        tr '\n' ' ' | \
        sed 's/"publishedfileid"/\n"publishedfileid"/g' | \
        grep '"publishedfileid"' | \
        sed -E 's/.*"publishedfileid"\s*:\s*"([0-9]+)".*/\1/' | \
        tr '\n' ' ' | \
        sed 's/[[:space:]]*$//'
}

# Fetch workshop item title
fetch_item_title() {
    local file_id="$1"
    
    curl -s -X POST \
        -d "itemcount=1&publishedfileids[0]=${file_id}" \
        https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/ | \
        tr '\n' ' ' | \
        sed -E 's/.*"title"\s*:\s*"([^"]*)".*/\1/'
}

# Install a workshop item to the missions directory
install_workshop_item() {
    local file_id="$1"
    local title="$2"
    local src="/home/container/steamapps/workshop/content/${WORKSHOP_APP_ID}/${file_id}"

    # Skip copying the collection entry itself; it is not a mission payload.
    if [[ -n "${WORKSHOP_COLLECTION_ID:-}" && "${file_id}" == "${WORKSHOP_COLLECTION_ID}" ]]; then
        log "Skipping collection id ${file_id}"
        return
    fi
    
    if [[ ! -d "$src" ]]; then
        log "Workshop item ${file_id} not found at ${src}"
        return
    fi
    
    local folder_name
    folder_name=$(sanitize_name "$title" "$file_id")
    
    # Check for mission JSON file to determine proper folder name
    local mission_json=""
    while IFS= read -r json_file; do
        local base_name
        base_name=$(basename "$json_file" .json)
        local normalized
        normalized=$(sanitize_name "$base_name")
        
        if [[ "${normalized,,}" == "${folder_name,,}" ]]; then
            mission_json="$json_file"
            break
        fi
    done < <(find "$src" -maxdepth 1 -type f -name '*.json')
    
    local copy_source="$src"
    if [[ -n "$mission_json" ]]; then
        local mission_name
        mission_name=$(basename "$mission_json" .json)
        folder_name=$(sanitize_name "$mission_name" "$folder_name")
        copy_source=$(dirname "$mission_json")
        log "Found mission file ${mission_name}.json, using folder ${folder_name}"
    fi
    
    local dest="${MISSION_DIR}/${folder_name}"
    rm -rf "$dest"
    mkdir -p "$dest"
    cp -a "${copy_source}/." "${dest}/"
    log "Installed workshop item ${file_id} to ${dest}"
}

# Queue workshop items for download
queue_workshop_items() {
    local -n ids_ref=$1
    local -n titles_ref=$2
    
    if ! is_enabled "${WORKSHOP_AUTO_UPDATE:-0}"; then
        log "Workshop auto-update disabled"
        return
    fi
    
    if [[ -z "${WORKSHOP_COLLECTION_ID:-}" ]]; then
        log "Workshop auto-update enabled but no collection ID provided"
        return
    fi
    
    if [[ -z "${STEAM_USER:-}" ]]; then
        log "Workshop auto-update enabled but no Steam user set"
        return
    fi
    
    log "Fetching workshop collection ${WORKSHOP_COLLECTION_ID}..."
    local items
    if ! items=$(fetch_collection_items "$WORKSHOP_COLLECTION_ID"); then
        log "Failed to fetch collection ${WORKSHOP_COLLECTION_ID}"
        return
    fi
    
    if [[ -z "$items" ]]; then
        log "Collection ${WORKSHOP_COLLECTION_ID} contains no items"
        return
    fi
    
    for item_id in $items; do
        local item_title
        item_title=$(fetch_item_title "$item_id" || echo "$item_id")
        
        ids_ref+=("$item_id")
        titles_ref+=("$item_title")
        log "Queued workshop item ${item_id}: ${item_title}"
    done
}

# Build SteamCMD command
build_steamcmd_command() {
    local do_update=$1
    local do_workshop=$2
    local needs_auth=$3
    local -n workshop_ids_ref=$4
    local -n cmd_ref=$5
    
    cmd_ref=("$STEAMCMD" $FORCE_PLATFORM "-remember_password")
    
    # Login
    if [[ $needs_auth -eq 1 ]]; then
        cmd_ref+=("+login" "${STEAM_USER}" "${STEAM_PASS:-}" "${STEAM_AUTH:-}")
        log "Using authenticated login for workshop downloads"
    else
        cmd_ref+=("+login" "anonymous")
        log "Using anonymous login"
    fi
    
    cmd_ref+=("+force_install_dir" "/home/container/")
    
    # App update
    if [[ $do_update -eq 1 ]]; then
        cmd_ref+=("+app_update" "$APP_ID")
        
        [[ -n "${SRCDS_BETAID:-}" ]] && cmd_ref+=("-beta" "${SRCDS_BETAID}")
        [[ -n "${SRCDS_BETAPASS:-}" ]] && cmd_ref+=("-betapassword" "${SRCDS_BETAPASS}")
        
        if [[ -n "${INSTALL_FLAGS:-}" ]]; then
            local -a install_flags
            read -r -a install_flags <<<"${INSTALL_FLAGS}"
            cmd_ref+=("${install_flags[@]}")
        fi
        
        cmd_ref+=("validate")
    else
        log "Auto-update disabled, skipping app update"
    fi
    
    # Workshop downloads
    if [[ $do_workshop -eq 1 && ${#workshop_ids_ref[@]} -gt 0 ]]; then
        for item_id in "${workshop_ids_ref[@]}"; do
            cmd_ref+=("+workshop_download_item" "$WORKSHOP_APP_ID" "$item_id")
        done
    fi
    
    cmd_ref+=("+quit")
}

# Main execution
main() {
    mkdir -p "$MISSION_DIR"
    
    # Parse configuration
    local do_update=0
    local do_workshop=0
    is_enabled "${STEAM_AUTO_UPDATE:-1}" && do_update=1
    is_enabled "${WORKSHOP_AUTO_UPDATE:-0}" && do_workshop=1
    
    log "Steam auto-update: $([[ $do_update -eq 1 ]] && echo "enabled" || echo "disabled")"
    
    # Queue workshop items
    local workshop_ids=()
    local workshop_titles=()
    queue_workshop_items workshop_ids workshop_titles
    
    # Determine if authentication is needed
    local needs_auth=0
    if [[ $do_workshop -eq 1 && ${#workshop_ids[@]} -gt 0 && -n "${STEAM_USER:-}" ]]; then
        needs_auth=1
    fi
    
    # Run SteamCMD if there's work to do
    if [[ $do_update -eq 1 || (${do_workshop} -eq 1 && ${#workshop_ids[@]} -gt 0) ]]; then
        log "Running SteamCMD..."
        local -a steamcmd_cmd
        build_steamcmd_command "$do_update" "$do_workshop" "$needs_auth" workshop_ids steamcmd_cmd
        "${steamcmd_cmd[@]}"
    else
        log "No update or workshop tasks to perform"
    fi
    
    # Install workshop items
    if [[ ${#workshop_ids[@]} -gt 0 ]]; then
        for i in "${!workshop_ids[@]}"; do
            install_workshop_item "${workshop_ids[$i]}" "${workshop_titles[$i]}"
        done
    fi
    
    # Start server
    log "Starting Nuclear Option dedicated server..."
    sleep 5
    exec ./NuclearOptionServer.x86_64 -batchmode -nographics -limitframerate "$FRAMERATE" -DedicatedServer "$CONFIG_PATH"
}

main "$@"
