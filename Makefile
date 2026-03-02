init:
	stow --dir=. --target=${HOME}/.local/bin scripts
	mkdir -p ${HOME}/.local/share/prompts
	stow --dir=. --target=${HOME}/.local/share/prompts prompts
	stow --dir=. --target=${HOME} configs
	mkdir -p ${HOME}/.claude/skills
	stow --dir=. --target=${HOME}/.claude/skills skills
	
