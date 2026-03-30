# Contribuire a GNOME Mines AI

Grazie per il tuo interesse in GNOME Mines AI! Questo documento ti guiderà attraverso il processo di contribuzione.

## 🚀 Iniziare

### 1. Fork e Clone

```bash
# Fork su GitHub
# Poi clona il tuo fork
git clone https://github.com/YOUR_USERNAME/gnome-mines-ai.git
cd gnome-mines-ai
```

### 2. Setup Ambiente di Sviluppo

```bash
# Installa dipendenze (Ubuntu/Debian)
sudo apt install meson valac libsoup-3.0-dev libjson-glib-dev \
    libgtk-4-dev libadwaita-1-dev libgee-0.8-dev librsvg2-dev gettext

# Configura build
meson setup build --prefix=/usr

# Compila
ninja -C build

# Esegui (senza installare)
./build/src/gnome-mines
```

### 3. Crea un Branch

```bash
git checkout -b feature/tua-feature
# o per bug fix
git checkout -b fix/tuo-fix
```

## 📝 Linee Guida Codice

### Stile Vala

- Usa **4 spazi** per indentazione
- Nomi classi: `PascalCase`
- Nomi metodi: `snake_case`
- Nomi variabili: `snake_case`
- Commenti: solo per logica complessa

```vala
// ✅ Buono
public class AiManager : Object {
    private Minefield minefield;
    
    public void execute_move(AiMove move) {
        // Esegui mossa
    }
}

// ❌ Cattivo
public class aiManager {
    private Minefield Minefield;
    public void ExecuteMove(AiMove Move) { }
}
```

### Logging

Usa il logger di debug per tracing:

```vala
logger.log("categoria", "Messaggio: %s", valore);
logger.logf("benchmark", "Token: %d, Accuracy: %.2f", tokens, accuracy);
```

### Gestione Errori

```vala
try {
    // Codice che può fallire
} catch (Error e) {
    logger.logf("errore", "Descrizione: %s", e.message);
    commentary_ready("⚠️ Errore: " + e.message, "error");
}
```

## 🧪 Testing

### Test Manuali

1. **AI Auto-Play**: Attiva e verifica che giochi correttamente
2. **Benchmark Mode**: Usa layout fissi e confronta risultati
3. **Multi-Modello**: Testa con Groq, OpenAI, Ollama
4. **Persistenza**: Chiudi/riapri e verifica settings salvate

### Test Benchmark

```bash
# Dopo una partita, controlla i log
tail -f /tmp/gnome-mines-ai-debug.log | grep benchmark

# Verifica file benchmark
cat ~/.gnome-mines-benchmarks.json | jq '.runs[-1]'
```

## 📤 Pull Request

### 1. Commit

```bash
git add .
git commit -m "feat: aggiungi supporto per modello X

- Descrizione dettagliata
- Cosa cambia
- Come testare

Fixes #123"
```

### 2. Push

```bash
git push origin feature/tua-feature
```

### 3. Apri PR su GitHub

- Titolo chiaro
- Descrizione cosa cambia
- Screenshot se UI changes
- Linka issue correlate

## 🏷️ Tipi di Commit

| Tipo | Descrizione |
|------|-------------|
| `feat:` | Nuova feature |
| `fix:` | Bug fix |
| `docs:` | Documentazione |
| `style:` | Formattazione |
| `refactor:` | Refactoring |
| `test:` | Test |
| `chore:` | Build/config |

## 📋 Checklist PR

- [ ] Codice compilato senza errori
- [ ] Testato manualmente
- [ ] Logging aggiunto per debug
- [ ] Documentazione aggiornata
- [ ] Nessuna API key nei file
- [ ] .gitignore aggiornato se necessario

## 💡 Idee per Contributi

### Facili
- [ ] Traduzioni in altre lingue
- [ ] Migliorie UI minori
- [ ] Documentazione
- [ ] Icone/temi

### Medi
- [ ] Nuovi provider LLM
- [ ] Statistiche avanzate
- [ ] Export formati alternativi
- [ ] Keyboard shortcuts

### Difficili
- [ ] Algoritmi solving avanzati
- [ ] Pattern recognition
- [ ] Multi-AI competition
- [ ] Cloud benchmark sync

## ❓ Bisogno di Aiuto?

- **GitHub Issues**: [Segnala problemi](https://github.com/YOUR_USERNAME/gnome-mines-ai/issues)
- **GitHub Discussions**: [Chiedi aiuto](https://github.com/YOUR_USERNAME/gnome-mines-ai/discussions)
- **Email**: tua.email@example.com

## 📜 Licenza

Contribuendo, accetti che il tuo codice sia distribuito sotto **GPLv3+**.

---

**Grazie per contribuire! 🎮🏆**
