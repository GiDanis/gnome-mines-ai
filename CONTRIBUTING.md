# Contributing to GNOME Mines AI

Thank you for your interest in GNOME Mines AI! This document will guide you through the contribution process.

## 🚀 Getting Started

### 1. Fork and Clone

```bash
# Fork on GitHub
# Then clone your fork
git clone https://github.com/YOUR_USERNAME/gnome-mines-ai.git
cd gnome-mines-ai
```

### 2. Setup Development Environment

```bash
# Install dependencies (Ubuntu/Debian)
sudo apt install meson valac libsoup-3.0-dev libjson-glib-dev \
    libgtk-4-dev libadwaita-1-dev libgee-0.8-dev librsvg2-dev gettext

# Configure build
meson setup build --prefix=/usr

# Build
ninja -C build

# Run (without installing)
./build/src/gnome-mines
```

### 3. Create a Branch

```bash
git checkout -b feature/your-feature
# or for bug fixes
git checkout -b fix/your-fix
```

## 📝 Code Guidelines

### Vala Style

- Use **4 spaces** for indentation
- Class names: `PascalCase`
- Method names: `snake_case`
- Variable names: `snake_case`
- Comments: only for complex logic

```vala
// ✅ Good
public class AiManager : Object {
    private Minefield minefield;
    
    public void execute_move(AiMove move) {
        // Execute move
    }
}

// ❌ Bad
public class aiManager {
    private Minefield Minefield;
    public void ExecuteMove(AiMove Move) { }
}
```

### Logging

Use debug logger for tracing:

```vala
logger.log("category", "Message: %s", value);
logger.logf("benchmark", "Tokens: %d, Accuracy: %.2f", tokens, accuracy);
```

### Error Handling

```vala
try {
    // Code that may fail
} catch (Error e) {
    logger.logf("error", "Description: %s", e.message);
    commentary_ready("⚠️ Error: " + e.message, "error");
}
```

## 🧪 Testing

### Manual Tests

1. **AI Auto-Play**: Enable and verify it plays correctly
2. **Benchmark Mode**: Use fixed layouts and compare results
3. **Multi-Model**: Test with Groq, OpenAI, Ollama
4. **Persistence**: Close/reopen and verify saved settings

### Benchmark Tests

```bash
# After a game, check logs
tail -f /tmp/gnome-mines-ai-debug.log | grep benchmark

# Verify benchmark file
cat ~/.gnome-mines-benchmarks.json | jq '.runs[-1]'
```

## 📤 Pull Request

### 1. Commit

```bash
git add .
git commit -m "feat: add model X support

- Detailed description
- What changes
- How to test

Fixes #123"
```

### 2. Push

```bash
git push origin feature/your-feature
```

### 3. Open PR on GitHub

- Clear title
- Description of changes
- Screenshots if UI changes
- Link related issues

## 🏷️ Commit Types

| Type | Description |
|------|-------------|
| `feat:` | New feature |
| `fix:` | Bug fix |
| `docs:` | Documentation |
| `style:` | Formatting |
| `refactor:` | Refactoring |
| `test:` | Tests |
| `chore:` | Build/config |

## 📋 PR Checklist

- [ ] Code compiles without errors
- [ ] Manually tested
- [ ] Logging added for debug
- [ ] Documentation updated
- [ ] No API keys in files
- [ ] .gitignore updated if needed

## 💡 Contribution Ideas

### Easy
- [ ] Translations to other languages
- [ ] Minor UI improvements
- [ ] Documentation
- [ ] Icons/themes

### Medium
- [ ] New LLM providers
- [ ] Advanced statistics
- [ ] Alternative export formats
- [ ] Keyboard shortcuts

### Difficult
- [ ] Advanced solving algorithms
- [ ] Pattern recognition
- [ ] Multi-AI competition
- [ ] Cloud benchmark sync

## ❓ Need Help?

- **GitHub Issues**: [Report problems](https://github.com/GiDanis/gnome-mines-ai/issues)
- **GitHub Discussions**: [Ask for help](https://github.com/GiDanis/gnome-mines-ai/discussions)
- **Email**: your.email@example.com

## 📜 License

By contributing, you agree that your code will be distributed under **GPLv3+**.

---

**Thank you for contributing! 🎮🏆**
