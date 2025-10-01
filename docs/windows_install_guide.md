# Installazione su Windows

Guida completa per l'installazione dell'Audio Transcription Tool su Windows 10/11.

## Installazione Rapida

### Metodo 1: Script Automatico (Raccomandato)

1. **Scarica tutti i file del progetto** in una cartella
2. **Apri PowerShell come Amministratore**:
   - Premi `Win + X`
   - Seleziona "Windows PowerShell (Admin)" o "Terminale (Admin)"
3. **Naviga nella cartella del progetto**:
   ```powershell
   cd C:\path\to\py-audio-transcribe-claude
   ```
4. **Esegui l'installazione**:
   ```powershell
   .\install.ps1
   ```

### Metodo 2: Usando il file Batch

1. **Doppio click su `install.bat`** (più semplice)
2. **Oppure da Command Prompt**:
   ```cmd
   install.bat
   ```

## Opzioni di Installazione

### Script PowerShell con Parametri

```powershell
# Installazione completa
.\install.ps1

# Installazione con download modelli
.\install.ps1 -DownloadModels

# Solo CPU (senza supporto GPU)
.\install.ps1 -NoGPU

# Salta dipendenze sistema (se già installate)
.\install.ps1 -SkipDependencies

# Con token HuggingFace
.\install.ps1 -HuggingFaceToken "your_token_here"

# Mostra aiuto
.\install.ps1 -Help
```

## Installazione Manuale

Se l'installazione automatica fallisce, segui questi passaggi:

### 1. Installa Python 3.8+
- Scarica da https://python.org
- **IMPORTANTE**: Spunta "Add Python to PATH"
- Verifica: `python --version`

### 2. Installa FFmpeg
- **Opzione A - Chocolatey** (raccomandato):
  ```powershell
  # Installa Chocolatey
  Set-ExecutionPolicy Bypass -Scope Process -Force
  [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
  iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
  
  # Installa FFmpeg
  choco install ffmpeg
  ```

- **Opzione B - Manuale**:
  - Scarica da https://ffmpeg.org/download.html
  - Estrai in `C:\ffmpeg`
  - Aggiungi `C:\ffmpeg\bin` al PATH

### 3. Crea Ambiente Virtuale
```powershell
python -m venv venv
venv\Scripts\Activate.ps1
```

### 4. Installa Dipendenze Python
```powershell
# Aggiorna pip
python -m pip install --upgrade pip

# PyTorch (GPU)
pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu118

# PyTorch (solo CPU)
pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu

# Altre dipendenze
pip install -r requirements.txt
```

## Test Installazione

### Test Rapido
```powershell
# Attiva ambiente virtuale
venv\Scripts\Activate.ps1

# Test componenti base
python -c "import whisper, librosa; print('Installazione OK')"

# Test modello Whisper
python -c "import whisper; whisper.load_model('tiny'); print('Whisper OK')"
```

### Test con Audio
```powershell
# Crea file audio di test
python -c "
import numpy as np
import soundfile as sf
t = np.linspace(0, 5, 16000*5)
audio = 0.3 * np.sin(2*np.pi*440*t)
sf.write('test.wav', audio, 16000)
print('File test creato: test.wav')
"

# Test trascrizione
python main.py test.wav -o test_output --format txt
```

## Risoluzione Problemi

### Errore: "Execution Policy"
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Errore: "Python non trovato"
- Reinstalla Python spuntando "Add to PATH"
- Oppure aggiungi manualmente al PATH:
  - `C:\Users\USERNAME\AppData\Local\Programs\Python\Python311`
  - `C:\Users\USERNAME\AppData\Local\Programs\Python\Python311\Scripts`

### Errore: "FFmpeg non trovato"
```powershell
# Verifica installazione
ffmpeg -version

# Se non funziona, reinstalla
choco uninstall ffmpeg
choco install ffmpeg
```

### Errore: "CUDA not available"
- Per GPU NVIDIA: installa CUDA Toolkit 11.8
- Per CPU: usa `-NoGPU` nell'installazione

### Errore: "Failed to load diarization model"
- Configura token HuggingFace:
  ```powershell
  $env:HUGGINGFACE_HUB_TOKEN = "your_token"
  ```
- Accetta termini su: https://huggingface.co/pyannote/speaker-diarization-3.1

## Consigli per Windows

### 1. Antivirus
- Alcuni antivirus bloccano il download dei modelli
- Aggiungi la cartella del progetto alle esclusioni

### 2. Performance
- **GPU NVIDIA**: Installa CUDA per accelerazione
- **CPU Intel**: I modelli "small" e "medium" sono ottimi compromessi
- **RAM limitata**: Usa modello "tiny" o "base"

### 3. Percorsi File
```powershell
# Usa sempre slash o backslash doppi
python main.py "C:\Audio\meeting.m4a" -o "C:\Output\transcript"

# Oppure percorsi relativi
python main.py audio\meeting.m4a -o output\transcript
```

### 4. Variabili d'Ambiente
```powershell
# HuggingFace token (permanente)
[System.Environment]::SetEnvironmentVariable("HUGGINGFACE_HUB_TOKEN", "your_token", "User")

# Cache personalizzata
[System.Environment]::SetEnvironmentVariable("WHISPER_CACHE_DIR", "C:\whisper_models", "User")
```

## Struttura Directory Windows

```
C:\py-audio-transcribe-claude\
├── install.ps1           # Script PowerShell principale
├── install.bat           # Wrapper batch
├── main.py               # Script principale
├── requirements.txt      # Dipendenze
├── venv\                 # Ambiente virtuale
│   └── Scripts\
│       ├── activate.bat  # Attivazione CMD
│       └── Activate.ps1  # Attivazione PowerShell
├── models\               # Modelli scaricati
├── temp\                 # File temporanei
└── data\                 # I tuoi file audio
```

## Utilizzo Dopo Installazione

```powershell
# Attiva ambiente virtuale
venv\Scripts\Activate.ps1

# Trascrizione base
python main.py audio.m4a -o output --format txt

# Con speaker e pulizia audio
python main.py audio.m4a -o output --format md --diarize --clean-audio

# Alta qualità
python main.py audio.m4a -o output --format json --model-size large-v3
```

## Script di Utilità Aggiuntivi

### Attivazione Rapida (activate.bat)
```batch
@echo off
call venv\Scripts\activate.bat
echo Ambiente virtuale attivato!
echo Usa: python main.py audio.m4a -o output --format txt
cmd /k
```

### Trascrizione Rapida (transcribe.bat)
```batch
@echo off
if "%1"=="" (
    echo Uso: transcribe.bat file_audio.m4a
    pause
    exit /b
)
call venv\Scripts\activate.bat
python main.py "%1" -o "%~n1_transcript" --format txt
pause
```

Salva questi file nella cartella principale per un uso più comodo!

## Comandi Rapidi Windows

```powershell
# Installazione completa
.\install.ps1 -DownloadModels

# Test veloce
venv\Scripts\Activate.ps1
python main.py --help

# Trascrizione esempio
python main.py C:\audio\meeting.m4a -o C:\output\meeting --format md --diarize
```
