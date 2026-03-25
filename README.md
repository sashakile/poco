[![tracked with wai](https://img.shields.io/badge/tracked%20with-wai-blue)](https://github.com/charly-vibes/wai)

# poxo
*(poco)*

*Pequeño y perezoso panda | Small and lazy panda*

[EN](#intro) | [ES](#introducción)

## Introducción

poxo es una librería de DataFrames en Python puro para ejemplos exploratorios
y de enseñanza. No es una copia de pandas — busca identificar las interfaces
abstractas verdaderas necesarias para operaciones de datos, fundamentadas en
teoría de categorías.

### Principios de diseño

- **Perezoso primero**: las operaciones construyen árboles de expresión, materializados bajo demanda
- **Algebraico**: operaciones siguen el triple adjunto Σ ⊣ Δ ⊣ Π de Spivak
- **Componible**: sintaxis pipe vía operador `|`, pipelines inspirados en transductores
- **Intercambiable**: backends abstractos de Storage y Compute (Python puro por defecto)
- **Estricto**: errores tempranos, sin coerción silenciosa
- **Python puro**: sin dependencias requeridas

### Ejemplo

```python
import poxo as po
from poxo import _

df = po.DataFrame({"nombre": ["Ana", "Luis"], "edad": [30, 25]})
resultado = df | po.where(_.edad > 25) | po.select(_.nombre)
```

## Intro

poxo is a pure Python DataFrame library for small exploratory and teaching
examples. It is not a pandas clone — it aims to identify the true abstract
interfaces needed for data operations, grounded in category theory.

### Design Principles

- **Lazy-first**: operations build expression trees, materialized on demand
- **Algebraic**: operations follow Spivak's Σ ⊣ Δ ⊣ Π adjoint triple
- **Composable**: pipe syntax via `|` operator, transducer-inspired pipelines
- **Swappable**: abstract Storage and Compute backends (pure Python default)
- **Strict**: raises early on errors, no silent coercion
- **Pure Python**: no required dependencies

### Example

```python
import poxo as po
from poxo import _

df = po.DataFrame({"name": ["Ana", "Luis"], "age": [30, 25]})
result = df | po.where(_.age > 25) | po.select(_.name)
```

## Influencias | Influences

- [Functorial Data Migration](https://arxiv.org/abs/1009.1166) (Spivak, 2012)
- [Seven Sketches in Compositionality](https://arxiv.org/abs/1803.05316) (Fong & Spivak, 2019)
- [AlgebraicJulia ACSets.jl](https://github.com/AlgebraicJulia/ACSets.jl)
- [Clojure Transducers](https://clojure.org/reference/transducers)
- [ibis](https://github.com/ibis-project/ibis)
- [siuba](https://github.com/machow/siuba)

## Desarrollo | Development

```bash
flit install --deps develop
just test       # run tests
just check      # run all checks (spellcheck, lint, test)
just coverage   # tests with coverage
```
