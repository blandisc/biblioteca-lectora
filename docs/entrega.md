# Antes de decir «listo»

Adaptado de Orbital. Cada regla tiene su «Por qué».

1. **Se mide, no se mira a ojo.** Márgenes iguales a ambos lados, títulos a la misma
   altura entre pantallas, centros compartidos: se miden en las capturas (píxeles →
   puntos). *Por qué:* «Buscar» quedó 35 pt más abajo y con otro margen que las demás
   pantallas, y a ojo no se veía.
2. **Las pruebas de diseño pasan.** `swift test` (con `DesignRulesTests`) y
   `scripts/lint-design.sh`. *Por qué:* las reglas que no se comprueban solas se rompen.
3. **Se ve en claro y en oscuro.** Las capturas de CI salen en los dos modos; se revisan
   las pantallas que cambiaron. *Por qué:* el «+» verde fichero se leía negro en claro.
4. **El informe distingue tres cosas:**
   - **Comprobado:** se vio funcionando (captura, prueba o en el iPhone).
   - **Hecho sin comprobar:** está en el código, compila, pero nadie lo ha visto andar
     (p. ej. lo que necesita tocar: escribir una nota, «Llevar a una nota»).
   - **No hecho.**
   *Por qué:* «listo» sin decir qué se vio de verdad esconde lo que falta probar.
5. **Lo que se arregla y puede volver, se vuelve regla con prueba.** *Por qué:* el lápiz
   rojo reapareció en el lector después de cambiar la identidad.
