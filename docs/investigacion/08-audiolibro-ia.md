# 08 · Audiolibro con voz de IA

*Octubre 2026. Precios y rankings de fuentes de terceros; verificarlos en la prueba S7 antes de fijarlos.*

## Lo que se busca

Escuchar cualquier libro como audiolibro, en español o inglés, con una voz que suene humana, a un costo bajo, y con una IA que entienda el texto: diálogos, personajes, tono, pronunciación y qué no leer.

## Arquitectura propuesta

```
Capítulo (texto del EPUB)
   │
   ▼
Director de escena (LLM: DeepSeek V4 Flash vía OpenRouter, o el modelo de Apple)
   → guion JSON: [{texto, tipo: narración|diálogo, personaje, tono, pausa}, …]
   → pronunciaciones, qué saltar, traducción opcional
   │
   ▼
Voz (TTS vía OpenRouter /api/v1/audio/speech, compatible con OpenAI)
   → un archivo de audio por fragmento, con indicaciones de tono
   │
   ▼
Reproductor nativo (AVFoundation)
   → cola por fragmentos = sincronía por frase con el texto
   → caché local; nunca se paga dos veces el mismo capítulo
```

Generar por fragmentos (una o pocas frases) da dos cosas gratis: la sincronía texto-audio por frase y la posibilidad de empezar a escuchar en segundos.

## Opciones de voz

| Opción | Costo aproximado | Notas |
|---|---|---|
| Voces del sistema (AVSpeechSynthesizer, voces mejoradas y premium) | Gratis, sin conexión | Base y respaldo. Suenan bien, pero no interpretan |
| GPT-4o mini TTS (OpenAI, vía OpenRouter) | ≈ 0.015 USD por minuto ≈ 0.90 USD por hora ≈ 9 USD por libro de 10 h. Se cobra 0.60 USD por millón de tokens de texto **más** 12 USD por millón de tokens de audio; el audio es casi todo el costo. OpenRouter solo muestra los 0.60 USD de entrada, lo que lo hace parecer más barato de lo que es | Acepta instrucciones de tono por fragmento |
| Gemini Flash TTS (Google, vía OpenRouter) | ≈ 0.8–1.8 USD por hora de audio según versión; precio de preview que podría subir en 2027 | Control de estilo con lenguaje natural; pensado también para audiolibros; multi-voz limitado |
| Voxtral Mini TTS (Mistral, vía OpenRouter) | ≈ 16 USD por millón de caracteres (≈ 10 USD por libro de 10 h) | Buena calidad en español según una comparativa contra ElevenLabs Flash; clonación de voz |
| ElevenLabs Flash / v3 | ≈ 3–6 USD por hora | Referencia en narración expresiva; conector aparte, opcional |
| Modelos abiertos en el iPhone (Kokoro, NeuTTS Nano Spanish, PocketTTS) | Gratis | Prometedores para el futuro (P3); falta probar calidad en español y velocidad en el iPhone |

Un libro típico de 80,000–100,000 palabras son ~500,000–600,000 caracteres, unas 9–11 horas de audio. El director de escena con DeepSeek cuesta centavos por libro.

## Prueba S7

1. Un capítulo en español (Quijote, dominio público) y uno en inglés.
2. Narrarlos con voz del sistema, GPT-4o mini TTS, Gemini Flash TTS y Voxtral, con y sin director.
3. Prueba a ciegas: ¿cuál escucharías una hora seguida?
4. Medir costo real por hora y tiempo hasta el primer audio.

## Fuentes

- [GPT-4o mini TTS (OpenAI)](https://developers.openai.com/api/docs/models/gpt-4o-mini-tts) · [Foro de OpenAI: costo por caracteres](https://community.openai.com/t/understanding-gpt-4o-mini-tts-pricing-input-characters-cost/1151816) · [Medición independiente del costo](https://www.s-anand.net/blog/openai-tts-cost/)
- [OpenRouter: anuncio de las APIs de audio](https://openrouter.ai/blog/announcing-audio-apis) · [Docs de TTS](https://openrouter.ai/docs/guides/overview/multimodal/tts) · [GPT-4o mini TTS](https://openrouter.ai/openai/gpt-4o-mini-tts-2025-12-15/api) · [Voxtral Mini TTS](https://openrouter.ai/mistralai/voxtral-mini-tts-2603/api)
- [Gemini-TTS (Google Cloud)](https://docs.cloud.google.com/text-to-speech/docs/gemini-tts) · [Gemini 3.8 Flash TTS pricing (eesel)](https://www.eesel.ai/blog/gemini-3-8-flash-tts-pricing) · [Gemini 3.1 Flash TTS pricing (nemovideo)](https://www.nemovideo.com/blog/gemini-3-1-flash-tts-pricing)
- [Comparativa ElevenLabs, OpenAI y Gemini TTS (Tech Insider)](https://tech-insider.org/ca/elevenlabs-vs-openai-vs-google-gemini-tts-2026/) · [Text to Speech Price Comparison, agosto 2026 (Silma)](https://silma.ai/blog/text-to-speech-price-comparison-august-2026) · [Best TTS APIs 2026 (Texttolab)](https://texttolab.com/blog/best-text-to-speech-api)
- [Voxtral TTS (Mistral)](https://mistral.ai/news/voxtral-tts/) · [Best on-device TTS models (GetStream)](https://getstream.io/blog/best-on-device-tts-models/) · [NeuTTS (Neuphonic)](https://github.com/neuphonic/neutts) · [Open-source TTS 2026 (BentoML)](https://www.bentoml.com/blog/exploring-the-world-of-open-source-text-to-speech-models)
