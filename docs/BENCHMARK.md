# Benchmark de consumo

Medición orientativa del consumo de tokens antes y después de la optimización del agente.

## Metodología

- Modelo: `deepseek/deepseek-flash`.
- Tokenizador de referencia: `o200k_base` (OpenAI). El tokenizador exacto de DeepSeek puede variar, por lo que los valores son aproximados.
- Versión anterior: commit `211e02a`.
- Versión actual: la del repositorio en el momento de la medición.
- Muestras de salida: dos peticiones representativas:
  - “El escaneo salió VULNERABLE, ¿qué hago?”
  - “¿En qué repositorios y proyectos te basas?”
- Las respuestas del modelo varían entre ejecuciones. Los ratios son orientativos.

## Resultados

| Concepto | Antes | Ahora | Ratio (ahora/antes) | Reducción |
|---|---:|---:|---:|---:|
| Prompt de entrada | 3.707 tokens | 2.361 tokens | 0,64 | 36 % |
| Respuesta media | 526 tokens | 200 tokens | 0,38 | 62 % |
| Total por turno (entrada + salida) | 4.233 tokens | 2.561 tokens | 0,61 | 40 % |
| Preflight (`--check` vs `--brief`) | 562 tokens | 12 tokens | 0,02 | 98 % |
| Triaje (completo vs `--summary`) | 2.212 tokens | 287 tokens | 0,13 | 87 % |

La respuesta media pasó de unas 345 palabras a unas 126 palabras, con una extensión típica de 7 a 10 líneas.

## Cómo se midió

1. Se extrajo el prompt anterior con `git show 211e02a:core/prompt.md`.
2. Se renderizaron dos agentes aislados, uno con el prompt anterior y otro con el actual.
3. Se ejecutaron las mismas peticiones con `opencode run --agent php2shell`.
4. Se eliminaron las cabeceras y códigos de color de la salida.
5. Se contaron palabras y tokens con `tiktoken`.

## Limitaciones

- La muestra es pequeña y el modelo no es determinista.
- El tokenizador de DeepSeek puede diferir del usado aquí.
- La reducción de salida depende del tipo de petición; una revisión completa con informe detallado consume más que una pregunta informativa.
- El detalle completo sigue disponible en los informes `.json` y `.txt`.
