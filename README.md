# GNOME Mines AI 🏆

**GNOME Mines AI** is an enhanced version of GNOME Mines with advanced AI features for testing and benchmarking Large Language Models (LLMs).

![Screenshot](screenshot.png)

## ✨ Features

### 🤖 AI Auto-Play
- **Multi-Model**: Supports **Groq** (Llama, GPT-OSS, Gemma, Qwen) and **Ollama** (local models)
- **Visible Reasoning**: See AI thinking in real-time
- **Universal Format**: JSON + line-based parsing for maximum compatibility

### 🏆 Benchmark Mode
- **Fixed Layouts**: Reproducible patterns for fair tests
- **3 Difficulties**: 8×8, 16×16, 30×16
- **Complete Metrics**: Accuracy, tokens, API calls, time

### 📊 Leaderboard
- **Auto-Save**: Every game is tracked
- **Filters**: By model, difficulty, provider
- **CSV Export**: External analysis with Python/Excel

### ⚡ Optimizations
- **Ultra Compact Prompt**: 70% shorter prompts (⚠️ May be unstable with some models)
- **Move Cache**: Reuse responses for identical situations
- **Local Logic**: RULE A/B for obvious moves (optional)
- **Batch Moves**: Execute all moves in one call

## 🚀 Installation

### Prerequisites

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

### Local Build (without installation)

```bash
meson setup build --prefix=$HOME/.local
ninja -C build
ninja -C build install
~/.local/bin/gnome-mines
```

## 🎯 AI Usage

### 1. Configure API Key

1. Open **Menu → AI Settings**
2. Select **Provider** (Groq recommended)
3. Paste **API Key** (auto-saves)
4. Click **"Verify API Key"**
5. Choose **Model** (e.g., `llama-3.3-70b-versatile`)

### 2. Enable AI

1. **Menu → 🤖 AI Auto-Play**
2. AI starts playing automatically
3. See **reasoning** in side panel

### 3. Benchmark Mode

1. On start screen, click **🏆 Benchmark**
2. Choose difficulty (8×8, 16×16, 30×16)
3. Enable AI Auto-Play
4. Mine layout is **always identical** for fair tests

### 4. View Benchmarks

1. **Menu → AI Benchmarks**
2. Filter by model/difficulty
3. See accuracy, tokens, time
4. **Export CSV** for external analysis

## 📈 Tracked Metrics

| Metric | Description |
|--------|-------------|
| **Model** | AI model name |
| **Provider** | Groq, OpenAI, Ollama |
| **Win/Loss** | Victory or defeat |
| **Accuracy** | Certain moves / Total moves |
| **Tokens** | Tokens used (prompt + response) |
| **API Calls** | Number of API calls |
| **Duration** | Game time |
| **Avg Time/Move** | Average time per move |

## 🔧 Configuration

### AI Settings

| Option | Default | Description |
|--------|---------|-------------|
| **Compact Prompt** | OFF | -70% tokens for large boards |
| **Local Logic** | OFF | Obvious moves without API (RULE A/B) |
| **Move Cache** | OFF | Reuse identical responses |
| **Batch Moves** | OFF | Execute all moves together |
| **Low Temperature** | OFF | More deterministic AI (0.01 vs 0.2) |

### Configuration Files

- **Config**: `~/.gnome-mines-ai-config.json`
- **Benchmarks**: `~/.gnome-mines-benchmarks.json`
- **CSV Export**: Choose path

## 🧠 Supported Models

### ✅ Tested & Working

#### **Groq (Cloud - Fast)**
- ✅ `llama-3.3-70b-versatile` - **Best for reasoning**
- ✅ `llama-3.1-8b-instant` - Fast and reliable
- ✅ `gpt-oss-120b` - Maximum reasoning capability
- ✅ `gemma2-9b-it` - Google model
- ✅ `qwen/qwen3-32b` - Qwen model

#### **Ollama (Local - Free)**
- ✅ `phi3:mini` (3.8B) - **Best balance for Minesweeper**
- ✅ `llama3.2:3b` - Stable and reliable
- ✅ `mistral:7b` - Best quality (slower)
- ✅ `qwen2.5:3b` - Good alternative

### ⚠️ Known Issues

- **Ultra Compact Prompt**: May be unstable with smaller models (<3B parameters). Use full prompt for better reliability.
- **Small models** (<1B): Often produce invalid JSON output. Not recommended.

### ❌ Not Tested

- OpenAI API (should work, not tested)
- Other providers (should work with OpenAI-compatible endpoints)

## 📊 Benchmark Example

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

## 🤝 Contributing

1. Fork the project
2. Create a branch (`git checkout -b feature/AmazingFeature`)
3. Commit (`git commit -m 'Add AmazingFeature'`)
4. Push (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

Distributed under the **GPLv3+** License. See `COPYING` for more information.

## 🙏 Acknowledgments

- **GNOME Mines** - Original project
- **Groq** - Fast API for testing
- **Meta** - Llama models
- **GNOME Community** - Support

## 📞 Contact

- **GitHub Issues**: [Report bugs](https://github.com/GiDanis/gnome-mines-ai/issues)
- **Discussions**: [Discuss features](https://github.com/GiDanis/gnome-mines-ai/discussions)

## 🏗️ Architecture

```
gnome-mines-ai/
├── src/
│   ├── ai/
│   │   ├── ai-manager.vala        # AI gameplay management
│   │   ├── ai-prompt.vala         # Prompt generation
│   │   ├── ai-benchmark.vala      # Metric tracking
│   │   ├── llm-provider.vala      # LLM providers (Groq, OpenAI, Ollama)
│   │   ├── api-key-validator.vala # API key validation
│   │   └── ai-debug-logger.vala   # Debug logging
│   ├── ai-manager.vala
│   ├── ai-preferences-dialog.vala # AI settings UI
│   ├── ai-commentary-overlay.vala # Reasoning panel
│   ├── ai-benchmark-dialog.vala   # Leaderboard UI
│   └── ... (other original files)
├── data/
├── build-aux/
└── README.md
```

---

**Happy testing! 🎮🏆**
