# GNOME Mines AI 🏆

**GNOME Mines AI** è una versione potenziata di GNOME Mines con funzionalità AI avanzate per il testing e benchmark di modelli linguistici (LLM).

![Screenshot](screenshot.png)

## ✨ Feature

### 🤖 AI Auto-Play
- **Multi-Modello**: Supporta Groq (Llama, GPT-OSS, Gemma, Qwen), OpenAI, Ollama (locale)
- **Ragionamento Visibile**: Vedi il pensiero dell'AI in tempo reale
- **Formato Universale**: Parsing JSON + line-based per compatibilità massima

### 🏆 Modalità Benchmark
- **Layout Fissi**: Campioni riproducibili per test equi
- **3 Difficoltà**: 8×8, 16×16, 30×16
- **Metriche Complete**: Accuracy, token, chiamate API, tempo

### 📊 Leaderboard
- **Salvataggio Automatico**: Ogni partita viene tracciata
- **Filtri**: Per modello, difficoltà, provider
- **Export CSV**: Analisi esterna con Python/Excel

### ⚡ Ottimizzazioni
- **Prompt Compatto**: -70% token per griglie grandi
- **Cache Mosse**: Riutilizza risposte per situazioni identiche
- **Logica Locale**: RULE A/B per mosse ovvie (opzionale)
- **Batch Moves**: Esegui tutte le mosse in una chiamata

## 🚀 Installazione

### Prerequisiti

```bash
# Ubuntu/Debian
sudo apt install meson valac libsoup-3.0-dev libjson-glib-dev \
    libgtk-4-dev libadwaita-1-dev libgee-0.8-dev librsvg2-dev gettext

# Fedora
sudo dnf install meson vala libsoup3-devel json-glib-devel \
    gtk4-devel libadwaita-devel gee-devel librsvg2-devel gettext
```

### Build

```bash
git clone https://github.com/YOUR_USERNAME/gnome-mines-ai.git
cd gnome-mines-ai/gnome-mines
meson setup build --prefix=/usr
ninja -C build
sudo ninja -C build install
gnome-mines
```

### Build Locale (senza installazione)

```bash
meson setup build --prefix=$HOME/.local
ninja -C build
ninja -C build install
~/.local/bin/gnome-mines
```

## 🎯 Utilizzo AI

### 1. Configura API Key

1. Apri **Menu → AI Settings**
2. Seleziona **Provider** (Groq consigliato)
3. Incolla la **API Key** (si salva automaticamente)
4. Clicca **"Verifica API Key"**
5. Scegli il **Modello** (es. `llama-3.3-70b-versatile`)

### 2. Attiva AI

1. **Menu → 🤖 AI Auto-Play** (o premi un tasto rapido se configurato)
2. L'AI inizia a giocare automaticamente
3. Vedi il **ragionamento** nel pannello laterale

### 3. Modalità Benchmark

1. Nella schermata iniziale, clicca **🏆 Benchmark**
2. Scegli la difficoltà (8×8, 16×16, 30×16)
3. Attiva AI Auto-Play
4. Il layout delle mine è **sempre uguale** per test equi

### 4. Visualizza Benchmark

1. **Menu → AI Benchmarks**
2. Filtra per modello/difficoltà
3. Vedi accuracy, token, tempo
4. **Export CSV** per analisi esterne

## 📈 Metriche Tracciate

| Metrica | Descrizione |
|---------|-------------|
| **Model** | Nome modello AI |
| **Provider** | Groq, OpenAI, Ollama |
| **Win/Loss** | Vittoria o sconfitta |
| **Accuracy** | Mosse certe / Mosse totali |
| **Token** | Token usati (prompt + response) |
| **API Calls** | Numero chiamate API |
| **Duration** | Tempo partita |
| **Avg Time/Move** | Tempo medio per mossa |

## 🔧 Configurazione

### AI Settings

| Opzione | Default | Descrizione |
|---------|---------|-------------|
| **Compact Prompt** | OFF | -70% token per griglie grandi |
| **Local Logic** | OFF | Mosse ovvie senza API (RULE A/B) |
| **Move Cache** | OFF | Riutilizza risposte identiche |
| **Batch Moves** | OFF | Esegui tutte le mosse insieme |
| **Low Temperature** | OFF | AI più deterministica (0.01 vs 0.2) |

### File di Configurazione

- **Config**: `~/.gnome-mines-ai-config.json`
- **Benchmark**: `~/.gnome-mines-benchmarks.json`
- **Export CSV**: Scegli percorso tu

## 🧠 Modelli Supportati

### Groq (Consigliato)
- ✅ `llama-3.3-70b-versatile` (Best for reasoning)
- ✅ `llama-3.1-8b-instant` (Fast)
- ✅ `gpt-oss-120b` (Max reasoning)
- ✅ `gemma2-9b-it` (Google)
- ✅ `qwen/qwen3-32b`

### OpenAI
- ✅ `gpt-4o-mini`
- ✅ `gpt-4o`
- ✅ `gpt-3.5-turbo`

### Locale (Ollama)
- ✅ `llama3.2`
- ✅ `llama3.1:70b`
- ✅ Qualsiasi modello Ollama

## 📊 Esempio Benchmark

```json
{
  "timestamp": "2026-03-30T02:48:49",
  "model": "llama-3.3-70b-versatile",
  "provider": "groq",
  "difficulty": "medium",
  "board_size": "16x16",
  "mines": 40,
  "win": true,
  "game_duration_sec": 145,
  "moves_total": 87,
  "moves_certain": 72,
  "moves_guessed": 15,
  "accuracy": 0.828,
  "api_calls": 23,
  "tokens_prompt": 45230,
  "tokens_response": 8920,
  "tokens_total": 54150,
  "avg_ms_per_move": 628
}
```

## 🤝 Contribuire

1. Fork il progetto
2. Crea un branch (`git checkout -b feature/AmazingFeature`)
3. Commit (`git commit -m 'Add AmazingFeature'`)
4. Push (`git push origin feature/AmazingFeature`)
5. Apri una Pull Request

## 📄 Licenza

Distribuito sotto licenza **GPLv3+**. Vedi `COPYING` per informazioni.

## 🙏 Ringraziamenti

- **GNOME Mines** - Progetto originale
- **Groq** - API veloce per testing
- **Meta** - Modelli Llama
- **Community GNOME** - Supporto

## 📞 Contatti

- **GitHub Issues**: [Segnala bug](https://github.com/YOUR_USERNAME/gnome-mines-ai/issues)
- **Discussions**: [Discuti feature](https://github.com/YOUR_USERNAME/gnome-mines-ai/discussions)

## 🏗️ Architettura

```
gnome-mines-ai/
├── src/
│   ├── ai/
│   │   ├── ai-manager.vala        # Gestione AI gameplay
│   │   ├── ai-prompt.vala         # Generazione prompt
│   │   ├── ai-benchmark.vala      # Tracciamento metriche
│   │   ├── llm-provider.vala      # Provider LLM (Groq, OpenAI, Ollama)
│   │   ├── api-key-validator.vala # Validazione API key
│   │   └── ai-debug-logger.vala   # Logging debug
│   ├── ai-manager.vala
│   ├── ai-preferences-dialog.vala # UI settings AI
│   ├── ai-commentary-overlay.vala # Pannello ragionamento
│   ├── ai-benchmark-dialog.vala   # UI leaderboard
│   └── ... (altri file originali)
├── data/
├── build-aux/
└── README.md
```

---

**Buon testing! 🎮🏆**
