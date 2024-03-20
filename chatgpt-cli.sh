#!/bin/bash

# OpenAI API key placeholder. Replace "your_api_key_here" with your actual OpenAI API key.
API_KEY="your_api_key_here"

# The model you want to use
MODEL="gpt-3.5-turbo"

# Endpoint URL for OpenAI API
ENDPOINT="https://api.openai.com/v1/chat/completions"

# ----------------------------------------------------------------------------------------

# Check for --debug flag
if [[ " $* " =~ " --debug " ]]; then
    DEBUG_MODE=1
fi

# Initialize an empty JSON array for the conversation history
conversation_json='[]'

# Debug print function
debug_print() {
    if [[ $DEBUG_MODE -eq 1 ]]; then
        echo "$1"
    fi
}

# Function to start a simple loading animation
start_loading() {
    echo -n ""
    while true; do
        echo -n "."
        sleep 0.5
    done
}

# Function to stop the loading animation
stop_loading() {
    kill $1 2>/dev/null
    wait $1 2>/dev/null
    echo -ne "\r\033[K"
}

# Function to preprocess and correctly handle newlines and code blocks
preprocess_for_rendering() {
    local content="$1"
    # Replace literal '\n' with actual newline characters
    content="${content//\\n/$'\n'}"

    # Additional preprocessing can be added here, such as handling code blocks
    # This is a placeholder for potential enhancements

    echo "$content"
}

# Modify the render_with_glow function to call preprocess_for_rendering
render_with_glow() {
    local response="$1"
    local preprocessed_response=$(preprocess_for_rendering "$response")
    echo "$preprocessed_response" | glow -
}

query_chatgpt() {
    local prompt="$1"
    # Append the new user prompt to the conversation JSON array
    conversation_json=$(jq --arg role "user" --arg content "$prompt" '. + [{"role": $role, "content": $content}]' <<< "$conversation_json")

    debug_print "Sending with conversation history: $conversation_json"

    start_loading &
    local loading_pid=$!

    # Make the API request
    local response=$(curl -s -X POST "$ENDPOINT" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_KEY" \
        --data "{\"model\": \"$MODEL\", \"messages\": $conversation_json}")

    stop_loading $loading_pid

    local assistant_response=$(echo $response | jq -r '.choices[0].message.content')
    # Check for null or error response
    if [[ "$assistant_response" == "null" ]]; then
        echo "Failed to get a response. Please check your API key and internet connection."
        return
    fi

    # Append the assistant's response to the conversation JSON array for subsequent requests
    conversation_json=$(jq --arg role "assistant" --arg content "$assistant_response" '. + [{"role": $role, "content": $content}]' <<< "$conversation_json")

    render_with_glow "$assistant_response"
}

while IFS= read -r -p "You: " input; do
    if [[ "$input" == "exit" ]]; then
        echo "Exiting..."
        break
    elif [[ "$input" == "--debug" ]]; then
        DEBUG_MODE=1
        echo "Debug mode enabled."
        continue
    fi

    query_chatgpt "$input"
done
