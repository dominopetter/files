# Modify the config.json file
OPENAI_API_KEY="${OPENAI_API_KEY}"
MODEL_PROVIDER_ID="${model_provider_id}"
CONFIG_FILE="/home/ubuntu/.local/share/jupyter/jupyter_ai/config.json"
TMP_FILE="/home/ubuntu/tmp_config.json"  # Path for tmp_config.json

# Make dir and Touch file
mkdir -p /home/ubuntu/.local/share/jupyter/jupyter_ai/
touch /home/ubuntu/.local/share/jupyter/jupyter_ai/config.json

# Modify the JSON configuration file
jq --arg openai_api_key "$OPENAI_API_KEY" --arg model_provider_id "$MODEL_PROVIDER_ID" \
    '{
        model_provider_id: $model_provider_id,
        embeddings_provider_id: null,
        send_with_shift_enter: false,
        fields: {
            ($model_provider_id): {}
        },
        api_keys: {
            OPENAI_API_KEY: $openai_api_key
        },
        completions_model_provider_id: null,
        completions_fields: {},
        embeddings_fields: {}
    }' "$CONFIG_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$CONFIG_FILE"

# Verification step: Check if the file has been correctly modified
if jq empty "$CONFIG_FILE" > /dev/null 2>&1; then
    echo "config.json has been successfully modified."
else
    echo "Error: config.json modification failed."
    exit 1
fi
