# Imposta il token Hugging Face
$token = "REPLACE_ME"

# Imposta la cartella di destinazione assoluta
$folder = Join-Path -Path $PSScriptRoot -ChildPath "models\pyannote-diarization"

# Crea la cartella se non esiste
New-Item -ItemType Directory -Path $folder -Force | Out-Null

# Base URL del modello
$baseUrl = "https://huggingface.co/pyannote/speaker-diarization-3.1/resolve/main"

# Elenco file da scaricare
$files = @(
    "config.yaml",
    "pytorch_model.bin",
    "preprocessor_config.json",
    "tokenizer_config.json",
    "special_tokens_map.json"
)

# Scarica ogni file autenticato
foreach ($file in $files) {
    $url = "$baseUrl/$file"
    $output = Join-Path -Path $folder -ChildPath $file
    Write-Host "Scarico $file..."
    curl.exe -H "Authorization: Bearer $token" $url -o $output
}
