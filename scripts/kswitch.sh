#!/bin/bash

# Kubernetes Context Switcher
# Interactive script to view and switch between Kubernetes contexts

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Function to extract cluster name from context
extract_cluster_name() {
    local context="$1"
    # Handle EKS ARN format
    if [[ $context == *"arn:aws:eks"* ]]; then
        echo "$context" | sed 's/.*cluster\///' | sed 's/:.*//'
    # Handle other formats - take the last part after the last slash or colon
    elif [[ $context == *"/"* ]] || [[ $context == *":"* ]]; then
        echo "$context" | sed 's/.*[\/:]//g'
    else
        echo "$context"
    fi
}

# Function to get all contexts
get_contexts() {
    kubectl config get-contexts -o name 2>/dev/null | sort -u || {
        echo -e "${RED}Error: kubectl not found or no contexts available${NC}" >&2
        exit 1
    }
}

# Function to get current context
get_current_context() {
    kubectl config current-context 2>/dev/null || echo ""
}

# Function to display menu
display_menu() {
    local current_context="$1"
    local selected_index="$2"
    shift 2
    local contexts=("$@")
    
    clear
    echo -e "${BOLD}${BLUE}Kubernetes Context Switcher${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
    echo -e "Current context: ${GREEN}$(extract_cluster_name "$current_context")${NC}"
    echo ""
    echo -e "Use ${YELLOW}↑/↓${NC} arrow keys to navigate, ${YELLOW}Enter${NC} to select, ${YELLOW}q${NC} to quit"
    echo ""
    
    for i in "${!contexts[@]}"; do
        local context="${contexts[$i]}"
        local cluster_name=$(extract_cluster_name "$context")
        
        if [[ $i -eq $selected_index ]]; then
            # Selected item
            echo -e "  ${YELLOW}→ $cluster_name${NC}"
        elif [[ "$context" == "$current_context" ]]; then
            # Current context (but not selected)
            echo -e "    ${GREEN}$cluster_name${NC}"
        else
            # Regular item
            echo -e "    $cluster_name"
        fi
    done
}

# Function to switch context
switch_context() {
    local new_context="$1"
    echo -e "\n${BLUE}Switching to context: ${YELLOW}$(extract_cluster_name "$new_context")${NC}"
    
    if kubectl config use-context "$new_context" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Successfully switched to $(extract_cluster_name "$new_context")${NC}"
        sleep 1
    else
        echo -e "${RED}✗ Failed to switch context${NC}"
        sleep 2
    fi
}

# Main function
main() {
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}Error: kubectl is not installed or not in PATH${NC}" >&2
        exit 1
    fi

    # Get contexts
    local contexts_raw
    contexts_raw=$(get_contexts)
    
    if [[ -z "$contexts_raw" ]]; then
        echo -e "${RED}No Kubernetes contexts found${NC}" >&2
        exit 1
    fi
    
    # Convert to array
    local contexts=()
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            contexts+=("$line")
        fi
    done <<< "$contexts_raw"
    
    if [[ ${#contexts[@]} -eq 0 ]]; then
        echo -e "${RED}No valid Kubernetes contexts found${NC}" >&2
        exit 1
    fi
    
    local current_context
    current_context=$(get_current_context)
    
    # Find current context index
    local selected_index=0
    for i in "${!contexts[@]}"; do
        if [[ "${contexts[$i]}" == "$current_context" ]]; then
            selected_index=$i
            break
        fi
    done
    
    # Main loop
    while true; do
        display_menu "$current_context" "$selected_index" "${contexts[@]}"
        
        # Read key input
        read -rsn1 key
        
        case "$key" in
            $'\x1b') # ESC sequence
                read -rsn2 key
                case "$key" in
                    '[A') # Up arrow
                        if [[ $selected_index -gt 0 ]]; then
                            ((selected_index--))
                        fi
                        ;;
                    '[B') # Down arrow
                        if [[ $selected_index -lt $((${#contexts[@]} - 1)) ]]; then
                            ((selected_index++))
                        fi
                        ;;
                esac
                ;;
            '') # Enter key
                if [[ "${contexts[$selected_index]}" != "$current_context" ]]; then
                    switch_context "${contexts[$selected_index]}"
                    current_context="${contexts[$selected_index]}"
                else
                    echo -e "\n${YELLOW}Already using this context${NC}"
                    sleep 1
                fi
                ;;
            'q'|'Q') # Quit
                echo -e "\n${BLUE}Goodbye!${NC}"
                exit 0
                ;;
        esac
    done
}

# Run the script
main "$@"
