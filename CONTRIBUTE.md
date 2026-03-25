# Guía de contribución | Contribution Guide

## Setup

```bash
git clone https://github.com/sashakile/poco.git
cd poco
uv sync
```

## Comandos | Commands

```bash
just test       # correr tests | run tests
just lint       # lint con pylint | lint with pylint
just check      # todos los checks | all checks (spellcheck, lint, test)
just coverage   # tests con cobertura | tests with coverage
```

## Flujo de trabajo | Workflow

1. Crear un issue con `bd create --title="..." --type=task`
2. Escribir el test primero (TDD)
3. Implementar hasta que pase
4. `just check` antes de hacer commit
5. Commit atómico con descripción clara

---

1. Create an issue with `bd create --title="..." --type=task`
2. Write the test first (TDD)
3. Implement until it passes
4. `just check` before committing
5. Atomic commit with clear description
