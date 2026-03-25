# poxo — small and lazy panda

# List available recipes
default:
    @just --list

# Sync dependencies
sync:
    uv sync

# Run tests
test:
    uv run pytest

# Run tests with coverage
coverage:
    uv run pytest --cov=poxo --cov-report=term-missing --cov-fail-under=80

# Lint with pylint
lint:
    uv run pylint poxo

# Check spelling
spellcheck:
    typos

# Lint prose in markdown
prose:
    vale README.md CONTRIBUTE.md

# Run all checks
check: spellcheck lint test
