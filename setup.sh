#!/bin/bash
# GNOME Mines AI - Setup Script
# Installa dipendenze e configura il progetto

set -e  # Esci su errore

echo "🎮 GNOME Mines AI - Setup"
echo "=========================="
echo ""

# Rileva distribuzione
if [ -f /etc/debian_version ]; then
    echo "📦 Rilevata distribuzione Debian/Ubuntu..."
    echo ""
    
    echo "📥 Installazione dipendenze..."
    sudo apt update
    sudo apt install -y meson valac libsoup-3.0-dev libjson-glib-dev \
        libgtk-4-dev libadwaita-1-dev libgee-0.8-dev librsvg2-dev \
        gettext ninja-build
    
elif [ -f /etc/fedora-release ]; then
    echo "📦 Rilevata distribuzione Fedora..."
    echo ""
    
    echo "📥 Installazione dipendenze..."
    sudo dnf install -y meson vala libsoup3-devel json-glib-devel \
        gtk4-devel libadwaita-devel gee-devel librsvg2-devel \
        gettext ninja-build
    
else
    echo "⚠️  Distribuzione non riconosciuta."
    echo "Installa manualmente le dipendenze per la tua distro."
    exit 1
fi

echo ""
echo "🔨 Configurazione build..."
meson setup build --prefix=/usr

echo ""
echo "✅ Setup completato!"
echo ""
echo "📝 Per compilare ed eseguire:"
echo "   ninja -C build"
echo "   sudo ninja -C build install"
echo "   gnome-mines"
echo ""
echo "📚 Per informazioni, vedi README.md"
echo ""
