#!/bin/bash
# Script de theming para bspwm
# Ejecutar después de instalar: yay -S papirus-icon-theme bibata-cursor-theme

# Colores Catppuccin Mocha
ACCENT="#89b4fa"
BG="#1e1e2e"
FG="#cdd6f4"

# GTK 3
cat > ~/.config/gtk-3.0/settings.ini << EOF
[Settings]
gtk-theme-name=Catppuccin-Mocha-Standard-Blue-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=JetBrainsMono Nerd Font 11
gtk-cursor-theme-name=Bibata-Modern-Ice
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_ICONS
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintmedium
gtk-xft-rgba=rgb
gtk-application-prefer-dark-theme=1
EOF

# GTK 4
cat > ~/.config/gtk-4.0/settings.ini << EOF
[Settings]
gtk-theme-name=Catppuccin-Mocha-Standard-Blue-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=JetBrainsMono Nerd Font 11
gtk-cursor-theme-name=Bibata-Modern-Ice
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme=1
EOF

# GTK CSS para border radius redondeado (estilo Hyprland)
cat > ~/.config/gtk-3.0/gtk.css << 'EOF'
/* Rounded corners for GTK3 */
headerbar {
    border-radius: 0 0 12px 12px;
}

dialog .titlebar {
    border-radius: 12px 12px 0 0;
}

messagedialog .titlebar {
    border-radius: 12px 12px 0 0;
}
EOF

cat > ~/.config/gtk-4.0/gtk.css << 'EOF'
/* Rounded corners for GTK4 */
headerbar {
    border-radius: 0 0 12px 12px;
}

window {
    border-radius: 12px;
}
EOF

# Xresources para cursor
cat > ~/.Xresources << 'EOF'
Xcursor.theme: Bibata-Modern-Ice
Xcursor.size: 24
EOF
xrdb -merge ~/.Xresources

# Aplicar cursor con xset
xsetroot -cursor_name left_ptr 2>/dev/null

echo "✓ Theming configurado. Reinicia las apps GTK para ver los cambios."
