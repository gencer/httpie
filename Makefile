###############################################################################
# See ./CONTRIBUTING.md
###############################################################################

.PHONY: build

ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
VERSION=$(shell grep __version__ httpie/__init__.py)
H1="\n\n\033[0;32m\#\#\# "
H1END=" \#\#\# \033[0m\n"


# Only used to create our venv.
SYSTEM_PYTHON=python3

VENV_ROOT=venv
VENV_BIN=$(VENV_ROOT)/bin
VENV_PIP=$(VENV_BIN)/pip3
VENV_PYTHON=$(VENV_BIN)/python


export PATH := $(VENV_BIN):$(PATH)


all: uninstall-httpie install test


install: venv
	@echo $(H1)Updating package tools$(H1END)
	$(VENV_PIP) install --upgrade pip wheel

	@echo $(H1)Installing dev requirements$(H1END)
	$(VENV_PIP) install --upgrade --editable '.[dev]'

	@echo $(H1)Installing HTTPie$(H1END)
	$(VENV_PIP) install --upgrade --editable .

	@echo

clean:
	@echo $(H1)Cleaning up$(H1END)
	rm -rf $(VENV_ROOT)
	# Remove symlink for virtualenvwrapper, if we’ve created one.
	[ -n "$(WORKON_HOME)" -a -L "$(WORKON_HOME)/httpie" -a -f "$(WORKON_HOME)/httpie" ] && rm $(WORKON_HOME)/httpie || true
	rm -rf *.egg dist build .coverage .cache .pytest_cache httpie.egg-info
	find . -name '__pycache__' -delete -o -name '*.pyc' -delete
	@echo


venv:
	@echo $(H1)Creating a Python environment $(VENV_ROOT) $(H1END)

	$(SYSTEM_PYTHON) -m venv --prompt httpie $(VENV_ROOT)

	@echo
	@echo done.
	@echo
	@echo To active it manually, run:
	@echo
	@echo "    source $(VENV_BIN)/activate"
	@echo
	@echo '(learn more: https://docs.python.org/3/library/venv.html)'
	@echo
	@if [ -n "$(WORKON_HOME)" ]; then \
		echo $(ROOT_DIR) >  $(VENV_ROOT)/.project; \
		if [ ! -d $(WORKON_HOME)/httpie -a ! -L $(WORKON_HOME)/httpie ]; then \
			ln -s $(ROOT_DIR)/$(VENV_ROOT) $(WORKON_HOME)/httpie ; \
			echo ''; \
			echo 'Since you use virtualenvwrapper, we created a symlink'; \
			echo 'so you can also use "workon httpie" to activate the venv.'; \
			echo ''; \
		fi; \
	fi


###############################################################################
# Testing
###############################################################################


test:
	@echo $(H1)Running tests$(HEADER_EXTRA)$(H1END)
	$(VENV_BIN)/python -m pytest $(COV) ./httpie $(COV) ./tests --doctest-modules --verbose ./httpie ./tests
	@echo


test-cover: COV=--cov
test-cover: HEADER_EXTRA=' (with coverage)'
test-cover: test


# test-all is meant to test everything — even this Makefile
test-all: clean install test test-dist codestyle
	@echo


test-dist: test-sdist test-bdist-wheel
	@echo


test-sdist: clean venv
	@echo $(H1)Testing sdist build an installation$(H1END)
	$(VENV_PYTHON) setup.py sdist
	$(VENV_PIP) install --force-reinstall --upgrade dist/*.gz
	$(VENV_BIN)/http --version
	@echo


test-bdist-wheel: clean venv
	@echo $(H1)Testing wheel build an installation$(H1END)
	$(VENV_PIP) install wheel
	$(VENV_PYTHON) setup.py bdist_wheel
	$(VENV_PIP) install --force-reinstall --upgrade dist/*.whl
	$(VENV_BIN)/http --version
	@echo


twine-check:
	twine check dist/*


# Kept for convenience, "make codestyle" is preferred though
pycodestyle: codestyle


codestyle:
	@echo $(H1)Running flake8$(H1END)
	@[ -f $(VENV_BIN)/flake8 ] || $(VENV_PIP) install --upgrade --editable '.[dev]'
	$(VENV_BIN)/flake8 httpie/ tests/ extras/ *.py
	@echo


codecov-upload:
	@echo $(H1)Running codecov$(H1END)
	@[ -f $(VENV_BIN)/codecov ] || $(VENV_PIP) install codecov
	# $(VENV_BIN)/codecov --required
	$(VENV_BIN)/codecov
	@echo


doc-check:
	@echo $(H1)Running documentations checks$(H1END)
	mdl --verbose --git-recurse --style docs/linter/mdl-styles.rb .


###############################################################################
# Publishing to PyPi
###############################################################################


build:
	rm -rf build/
	$(VENV_PYTHON) setup.py sdist bdist_wheel


publish: test-all publish-no-test


publish-no-test:
	@echo $(H1)Testing wheel build an installation$(H1END)
	@echo "$(VERSION)"
	@echo "$(VERSION)" | grep -q "dev" && echo '!!!Not publishing dev version!!!' && exit 1 || echo ok
	make build
	make twine-check
	$(VENV_BIN)/twine upload --repository=httpie dist/*
	@echo



###############################################################################
# Uninstalling
###############################################################################

uninstall-httpie:
	@echo $(H1)Uninstalling httpie$(H1END)
	- $(VENV_PIP) uninstall --yes httpie &2>/dev/null

	@echo "Verifying…"
	cd .. && ! $(VENV_PYTHON) -m httpie --version &2>/dev/null

	@echo "Done"
	@echo


###############################################################################
# Homebrew
###############################################################################

brew-deps:
	extras/brew-deps.py

brew-test:
	@echo $(H1)Uninstalling httpie$(H1END)
	- brew uninstall httpie

	@echo $(H1)Building from source…$(H1END)
	- brew install --build-from-source ./extras/httpie.rb

	@echo $(H1)Verifying…$(H1END)
	brew test httpie

	@echo $(H1)Auditing…$(H1END)
	brew audit --strict httpie
