if status is-interactive
    # Commands to run in interactive sessions can go here
    set -g fish_greeting ""
end

# Agregar ~/.local/bin al PATH
fish_add_path -g ~/.local/bin

# Usar Python 3.13 de Homebrew como default
fish_add_path -g /opt/homebrew/opt/python@3.13/libexec/bin

alias va='source .venv/bin/activate.fish'

# Starship prompt
if type -q starship
    starship init fish | source
end
