# Warp

Config de [Warp](https://www.warp.dev/) (terminal). Symlinkear a `~/.warp/`.

## Estructura

- `settings.toml` — config principal (apariencia, fuentes, shell override a fish)
- `keybindings.yaml` — keybindings custom
- `tab_configs/` — layouts de tabs (`startup_config.toml` se carga al abrir Warp)
- `themes/warp_bundled/dracula.yaml` — tema activo (Dracula)

## Instalación

```bash
ln -s ~/dotfiles/warp/settings.toml      ~/.warp/settings.toml
ln -s ~/dotfiles/warp/keybindings.yaml   ~/.warp/keybindings.yaml
ln -s ~/dotfiles/warp/tab_configs        ~/.warp/tab_configs
mkdir -p ~/.warp/themes/warp_bundled
ln -s ~/dotfiles/warp/themes/warp_bundled/dracula.yaml \
      ~/.warp/themes/warp_bundled/dracula.yaml
```

Para el catálogo completo de themes:

```bash
git clone https://github.com/warpdotdev/themes ~/.warp/themes
```

## Notas

- `settings.toml` referencia paths absolutos a `~/.warp/themes/...` y al binario de fish (`/opt/homebrew/Cellar/fish/.../bin/fish`). Ajustar en otra máquina.
- `default_tab_config_path` también es absoluto.
