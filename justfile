# poxo — small and lazy panda

# List available recipes
default:
    @just --list

# Run tests
test:
    pytest

# Run tests with coverage
coverage:
    pytest --cov=poxo --cov-report=term-missing --cov-fail-under=80

# Lint with pylint
lint:
    pylint poxo

# Check spelling
spellcheck:
    typos

# Lint prose in markdown
prose:
    vale README.md CONTRIBUTE.md

# Run all checks
check: spellcheck lint test

# Install in development mode
dev:
    flit install --deps develop
