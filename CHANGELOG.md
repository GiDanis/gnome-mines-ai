# Changelog

Tutti i cambiamenti significativi a questo progetto sono documentati in questo file.

## [1.0.0] - 2026-03-30

### ✨ Feature Aggiunte

#### 🤖 AI Auto-Play
- Supporto multi-modello (Groq, OpenAI, Ollama)
- Pannello laterale con ragionamento AI
- Parsing universale (JSON + line-based)
- Gestione errori robusta
- Auto-save API key

#### 🏆 Modalità Benchmark
- 3 difficoltà con layout fissi (8×8, 16×16, 30×16)
- Campioni riproducibili per test equi
- Pulsanti dedicati con icona 🏆

#### 📊 Sistema di Benchmark
- Tracciamento automatico metriche:
  - Model, Provider, Difficulty
  - Win/Loss
  - Accuracy (mosse certe / totali)
  - Token (prompt + response)
  - API calls
  - Tempo partita
  - Tempo medio per mossa
- Salvataggio automatico in `~/.gnome-mines-benchmarks.json`
- Leaderboard con filtri
- Export CSV

#### ⚡ Ottimizzazioni
- **Compact Prompt**: -70% token per griglie grandi
- **Cache Mosse**: Riutilizza risposte per situazioni identiche
- **Logica Locale**: RULE A/B per mosse ovvie
- **Batch Moves**: Esegui tutte le mosse in una chiamata
- **Low Temperature**: AI più deterministica (0.01)

#### 🎨 UI/UX
- Pannello AI espandibile (vedi ragionamento completo)
- Modello corrente visibile nel pannello
- Aggiornamento dinamico quando cambi modello
- Toggle per ogni ottimizzazione
- Feedback visivo salvataggio settings

### 🔧 Fix
- Crash in modalità benchmark (posizioni mine fuori bounds)
- API key non salvata correttamente
- Modello non aggiornato nel pannello
- Parsing JSON falliva con alcuni modelli
- Tempo di gioco non calcolato correttamente

### 📝 Documentazione
- README.md completo
- CONTRIBUTING.md per contributori
- Esempi di benchmark JSON
- Istruzioni installazione dettagliate

### 🏗️ Architettura
- `src/ai/ai-manager.vala`: Gestione AI gameplay
- `src/ai/ai-prompt.vala`: Generazione prompt ottimizzati
- `src/ai/ai-benchmark.vala`: Tracciamento metriche
- `src/ai/llm-provider.vala`: Provider LLM multipli
- `src/ai/api-key-validator.vala`: Validazione API key
- `src/ai/ai-debug-logger.vala`: Logging debug
- `src/ai-preferences-dialog.vala`: UI settings
- `src/ai-commentary-overlay.vala`: Pannello ragionamento
- `src/ai-benchmark-dialog.vala`: UI leaderboard

---

## [0.0.0] - 2026-03-XX

### Note
- Versione iniziale basata su GNOME Mines 50.0
- Prima release con feature AI

---

## Formattazione

- `[1.0.0]` - Versione
- `2026-03-30` - Data (YYYY-MM-DD)
- `### ✨ Feature Aggiunte` - Categoria
- `- Supporto multi-modello` - Cambiamento

## Tipi di Cambiamenti

| Icona | Tipo | Descrizione |
|-------|------|-------------|
| ✨ | Added | Feature nuove |
| 🐛 | Fixed | Bug fix |
| 🔧 | Changed | Cambiamenti esistenti |
| 🗑️ | Removed | Feature rimosse |
| 📝 | Documentation | Documentazione |
| 🏗️ | Architecture | Struttura codice |
