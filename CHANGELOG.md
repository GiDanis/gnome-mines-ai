# Changelog

All notable changes to this project are documented in this file.

## [1.0.0] - 2026-03-30

### ✨ Features Added

#### 🤖 AI Auto-Play
- Multi-model support (Groq, OpenAI, Ollama)
- Side panel with AI reasoning
- Universal parsing (JSON + line-based)
- Robust error handling
- Auto-save API key

#### 🏆 Benchmark Mode
- 3 difficulties with fixed layouts (8×8, 16×16, 30×16)
- Reproducible patterns for fair tests
- Dedicated buttons with 🏆 icon

#### 📊 Benchmark System
- Automatic metric tracking:
  - Model, Provider, Difficulty
  - Win/Loss
  - Accuracy (certain moves / total moves)
  - Tokens (prompt + response)
  - API calls
  - Game duration
  - Average time per move
- Auto-save to `~/.gnome-mines-benchmarks.json`
- Leaderboard with filters
- CSV export

#### ⚡ Optimizations
- **Compact Prompt**: -70% tokens for large boards
- **Move Cache**: Reuse responses for identical situations
- **Local Logic**: RULE A/B for obvious moves
- **Batch Moves**: Execute all moves in one call
- **Low Temperature**: More deterministic AI (0.01)

#### 🎨 UI/UX
- Expandable AI panel (see full reasoning)
- Current model visible in panel
- Dynamic model update when changed
- Toggle for each optimization
- Visual feedback for settings save

### 🔧 Fixes
- Crash in benchmark mode (mine positions out of bounds)
- API key not saving correctly
- Model not updating in panel
- JSON parsing failed with some models
- Game time not calculated correctly

### 📝 Documentation
- Complete README.md
- CONTRIBUTING.md for contributors
- CHANGELOG.md
- Detailed installation instructions

### 🏗️ Architecture
- `src/ai/ai-manager.vala`: AI gameplay management
- `src/ai/ai-prompt.vala`: Prompt generation
- `src/ai/ai-benchmark.vala`: Metric tracking
- `src/ai/llm-provider.vala`: Multi LLM providers
- `src/ai/api-key-validator.vala`: API key validation
- `src/ai/ai-debug-logger.vala`: Debug logging
- `src/ai-preferences-dialog.vala`: Settings UI
- `src/ai-commentary-overlay.vala`: Reasoning panel
- `src/ai-benchmark-dialog.vala`: Leaderboard UI

---

## [0.0.0] - 2026-03-XX

### Notes
- Initial version based on GNOME Mines 50.0
- First release with AI features

---

## Formatting

- `[1.0.0]` - Version
- `2026-03-30` - Date (YYYY-MM-DD)
- `### ✨ Features Added` - Category
- `- Multi-model support` - Change

## Change Types

| Icon | Type | Description |
|------|------|-------------|
| ✨ | Added | New features |
| 🐛 | Fixed | Bug fixes |
| 🔧 | Changed | Existing changes |
| 🗑️ | Removed | Removed features |
| 📝 | Documentation | Documentation |
| 🏗️ | Architecture | Code structure |
