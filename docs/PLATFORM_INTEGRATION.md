# Integración con Android/iOS (propuesta 11)

## Estado real

El preset iOS y `.github/workflows/build-ios.yml` generan una IPA sin firmar para SideStore,
con identificador `io.github.macarronesc.invadeio`; el Team ID es un marcador, no una credencial.
El único plugin nativo es el selector de copias iOS; no hay credenciales ni servicios de tienda.
No se muestran botones de conexión que simulen servicios inexistentes.
El lanzamiento previsto es Android e iOS, sin backend. Ajustes muestra el estado real del
guardado local, su alcance y la posibilidad de perderlo al desinstalar; no promete nube.
El preset Android habilita `VIBRATE` y target SDK 36; requiere instalar la plantilla Gradle
y configurar el SDK y la firma antes de exportar.

Sí está implementada la base de persistencia:

- `GameManager.save_data()` genera el mismo documento versionado para el guardado
  local y la copia manual.
- `write_save()` escribe con archivo temporal y renombrado, devolviendo errores.
- `save_game()` comprueba los errores, conserva el documento anterior en `.previous` y
  avisa a la interfaz si falla. Ajustes permite reintentar. Un reinicio o una importación
  fallidos no sustituyen el estado en memoria.
- `load_game()` recupera `.previous` si falta el archivo o el JSON principal es ilegible;
  aparta el original en `.corrupt` sin reemplazar copias corruptas ya conservadas. Las
  versiones futuras bloquean el guardado en vez de sobrescribir el archivo desconocido.
- `import_save()` rechaza JSON ajeno, versiones futuras y archivos mayores de 2 MB;
  valida los campos, conserva una copia del progreso anterior y revierte el estado
  en memoria si falla la escritura. La interfaz exige confirmación.
- La restauración está deshabilitada durante una batalla para no mezclar dos partidas.
- Las copias manuales usan el selector SAF nativo de Android y `UIDocumentPicker` en iOS.
  En macOS, ejecuta `bash scripts/build_ios_backup_picker.sh` antes de exportar el preset iOS.

La vibración usa `Input.vibrate_handheld()` con intensidad validada y persistente, pulsos
de 20–120 ms y un límite de repetición. Una acción combinada emite un solo pulso; uno más
largo puede sustituir al anterior. La prueba de Ajustes está deshabilitada en escritorio.

Al perder el foco o entrar en segundo plano, `GameManager` guarda desde cualquier escena,
`AudioManager` suspende sus reproductores sin cambiar los ajustes y la batalla cancela el
gesto y abre la pausa. No se reanuda al regresar, tampoco si se interrumpió la animación
de Reanudar o estaba abierta una ayuda. No se persiste una batalla en curso.

Las copias manuales no ofrecen autenticación, sincronización ni resolución de
conflictos; no deben anunciarse como nube. Los datos locales son modificables y no
son una autoridad segura para clasificaciones competitivas.

## Datos y dependencias que faltan

1. Confirmar los identificadores de publicación Android/iOS y configurar su firma real.
2. Configurar las aplicaciones en Google Play Console y App Store Connect, con
   cuentas de prueba, firma y habilitación de Play Games / Game Center.
3. Elegir plugins online compatibles con **Godot 4.7 y los SDK móviles actuales**, fijar sus
   versiones y validar sus APIs antes de escribir adaptadores. No se han añadido
   clases genéricas ni métodos imaginarios para plugins aún no elegidos.
4. Crear los identificadores reales de clasificación y acordar la puntuación.
   El tiempo actual es de simulación y el juego permite velocidades distintas:
   una clasificación de velocidad necesita reglas comunes, no enviar estos
   resultados directamente como segundos reales.
5. Para nube, acordar política de conflictos entre dispositivos y migraciones.
   Nunca sustituir silenciosamente el progreso local por una partida remota.
6. Para avisos, plugin de notificaciones locales, texto ES/EN, horario elegido por
   el usuario, consentimiento y permiso del sistema. Programar un aviso único
   al salir, cancelarlo al volver y evitar duplicados; no pedir permisos en el tutorial.

## Pruebas necesarias en dispositivos

Para estas funciones offline, antes de publicar:

- Android con `VIBRATE` e iPhone físico: intensidad, desactivación y pulsos de órdenes,
  captura y resultado; comprobar también un dispositivo sin motor háptico.
- Modo avión: comenzar, ganar, comprar, ajustar y volver a abrir sin perder progreso.
- Cambiar de app, bloquear/desbloquear y recibir una llamada durante un arrastre,
  una pausa manual, una ayuda o la animación de Reanudar. Reloj, tropas y producción
  deben detenerse; el audio no debe continuar en segundo plano.
- Cerrar el proceso después de guardar y actualizar sin desinstalar: progreso intacto;
  la batalla interrumpida no se restaura. Desinstalar puede borrar los datos locales.
- Revisar ajustes y pausa en ES/EN, claro/oscuro, pantallas pequeñas y zonas seguras.

La suite `--mobile` simula las notificaciones y fallos de escritura en archivos separados.
No certifica la sensación háptica, las interrupciones reales del sistema ni una build firmada.

Para futuras integraciones online (fuera de esta versión):

- Inicio de sesión cancelado, sin red, cuenta cambiada y servicio no disponible.
- Guardado en dos dispositivos, conflicto, versión antigua y descarga interrumpida.
- Permiso de avisos denegado/revocado, cambio de huso horario y reinstalación.
- Abrir la app desde un aviso y no reclamar recompensas automáticamente.
- Probar acceso y escritura de copias en el sandbox Android/iOS en dispositivos reales.

Hasta disponer de estos datos y dispositivos, las integraciones online siguen pendientes;
el juego permanece funcional offline.
