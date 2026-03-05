init:
	mkdir -p ${HOME}/.local/bin
	stow --dir=. --target=${HOME}/.local/bin scripts
	mkdir -p ${HOME}/.local/share/prompts
	stow --dir=. --target=${HOME}/.local/share/prompts prompts
	stow --dir=. --target=${HOME} configs
	
