.PHONY: clean clean-test clean-pyc clean-build docs help
.DEFAULT_GOAL := help

define BROWSER_PYSCRIPT
import os, webbrowser, sys

try:
	from urllib import pathname2url
except:
	from urllib.request import pathname2url

webbrowser.open("file://" + pathname2url(os.path.abspath(sys.argv[1])))
endef
export BROWSER_PYSCRIPT

define PRINT_HELP_PYSCRIPT
import re, sys

for line in sys.stdin:
	match = re.match(r'^([a-zA-Z_-]+):.*?## (.*)$$', line)
	if match:
		target, help = match.groups()
		print("%-20s %s" % (target, help))
endef
export PRINT_HELP_PYSCRIPT

PYTHON := python3

BROWSER := $(PYTHON) -c "$$BROWSER_PYSCRIPT"

help:
	@$(PYTHON) -c "$$PRINT_HELP_PYSCRIPT" < $(MAKEFILE_LIST)

clean: clean-build clean-pyc clean-test clean-doc ## remove all build, test, coverage and Python artifacts

clean-build: ## remove build artifacts
	rm -fr build/
	rm -fr dist/
	rm -fr .eggs/
	find . -name '*.egg-info' -exec rm -fr {} +
	find . -name '*.egg' -exec rm -f {} +

clean-pyc: ## remove Python file artifacts
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '*~' -exec rm -f {} +
	find . -name '__pycache__' -exec rm -fr {} +
	find . -name '*.so' -exec rm -f {} +

clean-test: ## remove test and coverage artifacts
	rm -fr .tox/
	rm -f .coverage
	rm -fr htmlcov/
	rm -fr .pytest_cache

clean-doc:
	rm -rf doc/build
	nbstripout doc/*.ipynb

lint: ## check style with flake8
	flake8 bxa tests

test: ## run tests quickly with the default Python
	pytest

test-xspec:
	export PYTHONPATH=$PWD:$PYTHONPATH; pushd examples/xspec/ && git clean -f . && bash runall.sh

test-all: ## run tests on every Python version with tox
	tox

coverage: ## check code coverage quickly with the default Python
	coverage run --source bxa -m pytest
	coverage report -m
	coverage html
	$(BROWSER) htmlcov/index.html

docs: ## generate Sphinx HTML documentation, including API docs
	rm -f doc/bxa{,.sherpa,.xspec,.sherpa.background}.rst
	rm -f doc/modules.rst
	sphinx-apidoc -H API -o doc/ bxa
	$(MAKE) -C doc clean
	PYTHONPATH=${PWD}:${PWD}/npyinterp:${PYTHONPATH} LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${PWD}/npyinterp $(MAKE) MAKESPHINXDOC=1 -C doc html
	$(BROWSER) doc/build/html/index.html

servedocs: docs ## compile the docs watching for changes
	watchmedo shell-command -p '*.rst' -c '$(MAKE) -C docs html' -R -D .

release: dist ## package and upload a release
	rm -rf logs/features-*
	echo testfeatures/runsettings-*-iterated.json | xargs --max-args=1 mpiexec -np 3 coverage run --parallel-mode examples/testfeatures.py
	bash -c 'echo $$RANDOM' | xargs mpiexec -np 5 coverage run --parallel-mode examples/testfeatures.py --random --seed
	twine upload -s dist/*.tar.gz

dist: clean ## builds source and wheel package
	$(PYTHON) setup.py sdist
	$(PYTHON) setup.py bdist_wheel
	ls -l dist

install: clean ## install the package to the active Python's site-packages
	$(PYTHON) setup.py install
