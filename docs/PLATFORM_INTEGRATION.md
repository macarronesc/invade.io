# Integración con Android/iOS (propuesta 11)

## Estado real

Este repositorio no contiene plugins nativos, presets de exportación móvil,
identificadores de aplicación, credenciales ni configuración de servicios de tienda.
No se muestran botones de conexión que simulen servicios inexistentes.
El panel de ajustes indica que nube, clasificaciones y notificaciones no están conectadas.

Sí está implementada la base de persistencia:

- `GameManager.save_data()` genera el mismo documento versionado para el guardado
  local y la copia manual.
- `write_save()` escribe con archivo temporal y renombrado, devolviendo errores.
- `import_save()` rechaza JSON ajeno, versiones futuras y archivos mayores de 2 MB;
  valida los campos, conserva una copia del progreso anterior y revierte el estado
  en memoria si falla la escritura. La interfaz exige confirmación.
- La restauración está deshabilitada durante una batalla para no mezclar dos partidas.

Las copias manuales no ofrecen autenticación, sincronización ni resolución de
conflictos; no deben anunciarse como nube. Los datos locales son modificables y no
son una autoridad segura para clasificaciones competitivas.

## Datos y dependencias que faltan

1. Elegir plataformas objetivo y nombres de paquete/bundle definitivos.
2. Configurar las aplicaciones en Google Play Console y App Store Connect, con
   cuentas de prueba, firma y habilitación de Play Games / Game Center.
3. Elegir plugins compatibles con **Godot 4.7 y los SDK móviles actuales**, fijar sus
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

- Inicio de sesión cancelado, sin red, cuenta cambiada y servicio no disponible.
- Guardado en dos dispositivos, conflicto, versión antigua y descarga interrumpida.
- Permiso de avisos denegado/revocado, cambio de huso horario y reinstalación.
- Abrir la app desde un aviso y no reclamar recompensas automáticamente.
- Compartir mediante portapapeles y probar acceso a archivos/exportación en el
  sandbox Android/iOS (los diálogos de archivos se han validado sólo en escritorio).

Hasta disponer de estos datos y dispositivos, el punto 11 sigue pendiente; el juego
permanece funcional offline y sin dependencias nativas nuevas.
