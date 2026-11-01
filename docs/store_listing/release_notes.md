# Versioning and release-note reference

[Documentation](../README.md) · [Release process](../RELEASES.md) · [Google Play publishing](../PLAY_STORE.md)

This document contains version-specific Play Console text and historical draft
announcement payloads. Play's **What's new** field permits **500 characters per
language**. Use only the blocks for the build being distributed, not this entire
document. Localized payloads below are preserved in their intended languages.

**Publication is not established by this file.** Historical dates were not
recorded here, and early announcement templates contain placeholders and claims
that must not be copied as current behavior. Confirm the shipped binary and
current [privacy/publication gate](../PLAY_STORE_UPDATE.md#7-mandatory-privacy-audience-and-release-gate).
The [0.4.0 candidate notes](#candidate-invadeio-040--faster-battles-and-smoother-startup)
are not suitable for a listing-only refresh without that application build.

## Version fields

The [release guide](../RELEASES.md#before-merging-a-release) owns the required
version-increase checks. This table identifies the corresponding fields:

| Field | Location | Meaning | Rule |
|---|---|---|---|
| `config/version` | `project.godot` | Source/release version, also used by telemetry | `MAJOR.MINOR.PATCH` |
| `version/name` | Android and Android AAB export presets | Player-visible version | Matches the source version |
| `version/code` | Both Android presets | Internal Play version code | Increasing, never reused for the production package |
| `application/short_version` | Both iOS presets | Player-visible version | Matches the source version |
| `application/version` | iOS presets | Build number | CI supplies `GITHUB_RUN_NUMBER` to Xcode; App Store distribution needs increasing valid build numbers |

Convention: patch versions are fixes, minor versions introduce content/features,
and major versions mark substantial milestones. The two Android presets must
have matching names/codes; Play's maximum code is 2,100,000,000. Android and iOS
store numbering are independent. Check used Android codes in **App bundle
explorer**, never by guessing from source history.

Older save formats are validated/migrated by the game. A future-format save
blocks writes rather than being overwritten; this is separate from application
version numbering.

## Before each release

Follow [RELEASES.md](../RELEASES.md#before-merging-a-release), add accurate notes
and a history entry here, and confirm the artifact and Console version. Do not
treat a placeholder date or prepared text as a record of publication.

## Historical draft: invade.io 0.1.0 — first public release

`versionCode` 1 · `versionName` 0.1.0. The original templates describe an internal
test → closed test → production sequence; actual publication dates are not
recorded here. These are archived payloads, not the current feature reference.

### Play Console notes (Spanish)

Historical localized payload; verify applicability before reuse.

```
Primera versión pública de invade.io.
• Campaña de 30 niveles: capitales, fábricas, selva, oasis, fortalezas y rutas marítimas.
• Conquista libre en expediciones y desafío diario con reglas rotatorias.
• Misiones diarias, racha que perdona un día de ausencia y 20 logros.
• Invasiones regionales de tres frentes sobre ciudades reales.
• Mejoras de ejército, rangos, atlas de ciudades reales y estética desbloqueable.
• Sin anuncios, sin compras y sin conexión. Guardado local con copia exportable.
15 idiomas, incluido español e inglés.
```

### What's new on Play (English)

Historical English payload; verify applicability before reuse.

```
First public release of invade.io.
• A 30-level campaign: capitals, factories, jungle, oases, fortresses and sea routes.
• Free-conquest expeditions and a daily challenge with rotating rules.
• Daily missions, a streak that forgives one missed day, and 20 achievements.
• Regional three-front invasions across real cities.
• Army upgrades, ranks, an atlas of real cities and unlockable looks.
• No ads, no purchases, plays offline. Local save with an exportable backup.
15 languages, including Spanish and English.
```

### Archived long-form announcement templates

These original Spanish/English templates have no Play field-length limit and
contain publication-date placeholders. They are retained for history, not as
verified current announcements. In particular, historical network/privacy and
accessibility wording must not override the current source or shipped behavior.

```
invade.io 0.1.0 — primera versión pública

Ya disponible en Google Play:
https://play.google.com/store/apps/details?id=macarronesc.invadeio
(FECHA DE PUBLICACIÓN)

Estrategia territorial en vertical y con una mano: eliges una base, arrastras el dedo y las tropas
marchan a conquistar la siguiente. El mapa es el mundo real, con costas, fronteras y más de mil
ciudades auténticas.

Qué incluye esta 0.1.0
• Campaña de 30 niveles repartida en seis continentes, cada uno con su regla: capitales que producen
  un 50 % más, fábricas neutrales, selva que frena las marchas un 20 %, oasis, fortalezas y rutas
  marítimas obligatorias. Cada quinto nivel espera un jefe con refuerzos propios.
• Conquista libre en expediciones de cinco regiones, con jefe y oro doble al cerrar cada una.
• Desafío diario con reglas rotatorias y las mismas fuerzas para todos los jugadores.
• Misiones diarias, recompensa con racha que perdona un día de ausencia y 20 logros.
• Invasiones regionales de tres frentes sobre ciudades reales.
• Mejoras de ejército (guarnición, reclutamiento, velocidad de marcha y botín), rangos, colecciones
  de ciudades reales y estética desbloqueable que no altera el combate.
• 15 idiomas, tema claro y oscuro, paleta para daltonismo, opción de reducir movimiento,
  velocidad de juego y respuesta táctil ajustable.

Lo que todavía no tiene
Ni anuncios, ni compras, ni cuentas, ni conexión. El progreso vive en el móvil y se puede exportar una
copia cuando se quiera. Requiere Android 7.0 o superior.

Primer número de la serie: 0.1.0 con versionCode 1. Las versiones siguientes suben el nombre y el
código tal como se explica en docs/store_listing/release_notes.md.
```

```
invade.io 0.1.0 — first public release

Available now on Google Play:
https://play.google.com/store/apps/details?id=macarronesc.invadeio
(PUBLISH DATE)

One-handed portrait territorial strategy: pick a base, drag your finger and your troops march out to
take the next one. The map is the real world, with coastlines, borders and more than a thousand real
cities.

What's in 0.1.0
• A 30-level campaign across six continents, each with its own rule: capitals that produce 50 % more,
  neutral factories, jungle that slows marches by 20 %, oases, fortresses and mandatory sea routes.
  Every fifth level waits a boss with its own reinforcements.
• Free conquest in five-region expeditions, each ending with a boss and double gold.
• A daily challenge with rotating rules and equal forces for every player.
• Daily missions, a streak reward that forgives one missed day, and 20 achievements.
• Regional three-front invasions across real cities.
• Army upgrades (garrison, recruitment, march speed and spoils), ranks, collections of real cities
  and unlockable looks that never change combat.
• 15 languages, light and dark themes, colour-blind palette, reduced-motion option, game speed
  and adjustable haptic feedback.

What it does not have yet
No ads, no purchases, no accounts, no connection. Progress lives on your phone and you can export a
copy whenever you want. Requires Android 7.0 or higher.

First release of the series: 0.1.0 with versionCode 1. Later versions bump the name and the code as
described in docs/store_listing/release_notes.md.
```

### Claims to avoid

Only advertise implemented behavior. Do not promise cloud saves, accounts,
online rankings, purchases, advertising, or multiplayer. Avoid keyword stuffing
and do not treat historical copy as a current privacy statement.

## Reference: invade.io 0.2.0 — invasions and languages

`versionCode` 3 · `versionName` 0.2.0.

Historical internal Console label: `0.2.0 (3) — Invasiones y 15 idiomas`.

Play Console payloads (under 500 characters per language):

```
<es-ES>
¡Nueva actualización de invade.io!
• 36 regiones de invasión y 108 frentes, con progreso, recompensas y logros.
• Juega en 15 idiomas, incluido el árabe con interfaz de derecha a izquierda.
• Mejoras de navegación, resumen de batalla, contraste del mapa y respuesta táctil.
• Estadísticas de uso e informes de fallos opcionales, desactivados de forma predeterminada.
• Tu progreso anterior se conserva al actualizar.
</es-ES>
<en-US>
A major update for invade.io!
• Explore 36 invasion regions and 108 fronts, with progression, rewards, and achievements.
• Play in 15 languages, including Arabic with a right-to-left interface.
• Improved navigation, battle briefings, map contrast, and haptic feedback.
• Usage analytics and crash reports are optional and off by default.
• Your existing progress is preserved when you update.
</en-US>
```

## Candidate: invade.io 0.3.1 — contributions and build safety

`versionCode` 5 · **owner must confirm code availability and publication status in Play Console**.

- Offline open-source licenses in Settings.
- Test installations separated from the production app and its saves.
- PR CI, secret/package checks, and isolated, approved production signing.

Publish the matching policy and review Data safety/consent requirements before
distributing. Proposed payloads below apply **only to a shipped 0.3.1 binary**,
not a listing refresh without a build. Each locale's text is under 500 characters;
confirm actual production behavior first:

```text
<es-ES>
• Consulta las licencias de código abierto desde Ajustes, también sin conexión.
• Se conserva tu progreso al actualizar.
</es-ES>
<en-US>
• Open-source licenses are available in Settings, including offline.
• Your existing progress is preserved when you update.
</en-US>
```

Listing assets and update procedure: [PLAY_STORE_UPDATE.md](../PLAY_STORE_UPDATE.md).

## Candidate: invade.io 0.4.0 — faster battles and smoother startup

`versionCode` 7 · **owner must confirm code availability and publication status in Play Console**.

- Faster, smoother battles and menus: batched drawing, reused map geometry, coalesced interface updates, and animations that pause after five seconds without input.
- A new launch animation that can be skipped with a tap and is skipped entirely by Reduced Motion.
- Smaller production mobile packages through the optimized engine, font width-axis trimming, and export-only artwork exclusions.
- Safer save timing: interface-driven changes are grouped, while pause, background, close, purchases, and rewards still save immediately.
- Existing saves and progress remain compatible. The game still has no accounts, ads, purchases, or online play.

Publish the matching policy and review Data safety/consent requirements before
distributing. Proposed payloads below apply **only to a shipped 0.4.0 binary**;
confirm actual production behavior first. Translations are drafts and need the
same native-speaker review as the listing copy:

```text
<es-ES>
• Batallas y menús más fluidos: dibujo por lotes, mapas reutilizados y animaciones que se pausan tras cinco segundos sin interacción.
• Nueva animación de inicio, omitible con un toque y desactivada con Movimiento reducido.
• Descargas móviles más ligeras gracias al motor y las fuentes optimizados.
• Guardado más seguro: los cambios de interfaz se agrupan; pausa, segundo plano, cierre, compras y recompensas siguen guardándose al instante.
• Las partidas y el progreso existentes siguen siendo compatibles.
</es-ES>
<en-US>
• Faster, smoother battles and menus with batched drawing, reused map geometry, and animations that pause after five seconds without input.
• A new launch animation, skippable with a tap and skipped by Reduced Motion.
• Smaller mobile downloads through the optimized engine and fonts.
• Safer save timing: interface changes are grouped, while pause, background, close, purchases, and rewards still save immediately.
• Existing saves and progress remain compatible.
</en-US>
<pt-BR>
• Batalhas e menus mais fluidos: desenho em lotes, mapas reutilizados e animações que pausam após cinco segundos sem interação.
• Nova animação de abertura, ignorável com um toque e desativada com Movimento reduzido.
• Downloads móveis menores com o motor e as fontes otimizados.
• Gravação mais segura: alterações de interface são agrupadas; pausa, segundo plano, fecho, compras e recompensas continuam a guardar imediatamente.
• Os saves e o progresso existentes continuam compatíveis.
</pt-BR>
<fr-FR>
• Batailles et menus plus fluides : dessin par lots, cartes réutilisées et animations suspendues après cinq secondes sans interaction.
• Nouvelle animation de lancement, ignorable d’un toucher et désactivée avec Mouvement réduit.
• Téléchargements mobiles plus légers grâce au moteur et aux polices optimisés.
• Sauvegarde plus sûre : les réglages d’interface sont regroupés ; pause, arrière-plan, fermeture, achats et récompenses restent enregistrés immédiatement.
• Les sauvegardes et la progression existantes restent compatibles.
</fr-FR>
<de-DE>
• Flüssigere Kämpfe und Menüs: gebündeltes Zeichnen, wiederverwendete Karten und Animationen, die nach fünf Sekunden ohne Eingabe pausieren.
• Neue Startanimation, per Tippen überspringbar und bei Reduzierter Bewegung deaktiviert.
• Kleinere mobile Downloads durch optimierte Engine und Schriftarten.
• Sichereres Speichern: Oberflächenänderungen werden gebündelt; Pause, Hintergrund, Schließen, Käufe und Belohnungen werden weiterhin sofort gespeichert.
• Bestehende Spielstände und Fortschritte bleiben kompatibel.
</de-DE>
<it-IT>
• Battaglie e menu più fluidi: disegno in batch, mappe riutilizzate e animazioni in pausa dopo cinque secondi senza interazione.
• Nuova animazione di avvio, saltabile con un tocco e disattivata con Movimento ridotto.
• Download mobili più leggeri grazie al motore e ai font ottimizzati.
• Salvataggio più sicuro: le modifiche all’interfaccia vengono raggruppate; pausa, background, chiusura, acquisti e ricompense restano immediati.
• I salvataggi e i progressi esistenti restano compatibili.
</it-IT>
<ru-RU>
• Более плавные бои и меню: пакетная отрисовка, повторное использование карт и пауза анимаций через пять секунд без ввода.
• Новая анимация запуска: пропускается касанием и отключается при уменьшенном движении.
• Меньший размер мобильной загрузки благодаря оптимизированным движку и шрифтам.
• Надёжнее сохранение: изменения интерфейса группируются; пауза, фон, закрытие, покупки и награды по-прежнему сохраняются сразу.
• Существующие сохранения и прогресс остаются совместимыми.
</ru-RU>
<tr-TR>
• Daha akıcı savaşlar ve menüler: toplu çizim, yeniden kullanılan haritalar ve beş saniye işlem yapılmayınca duraklayan animasyonlar.
• Yeni açılış animasyonu bir dokunuşla atlanabilir ve Azaltılmış Hareket'te kapalıdır.
• Optimize edilmiş motor ve yazı tipleriyle daha küçük mobil indirmeler.
• Daha güvenli kayıt: arayüz değişiklikleri gruplanır; duraklatma, arka plan, kapatma, satın almalar ve ödüller anında kaydedilmeye devam eder.
• Mevcut kayıtlar ve ilerleme uyumlu kalır.
</tr-TR>
<ar>
• معارك وقوائم أكثر سلاسة: رسم مجمّع وخرائط معاد استخدامها ورسوم متحركة تتوقف بعد خمس ثوانٍ دون تفاعل.
• رسوم بدء جديدة يمكن تخطيها بلمسة وتُعطّل مع تقليل الحركة.
• تنزيلات جوال أصغر بفضل المحرك والخطوط المحسّنة.
• حفظ أكثر أمانًا: تُجمّع تغييرات الواجهة، بينما يظل الحفظ فوريًا عند الإيقاف المؤقت والخلفية والإغلاق والمشتريات والمكافآت.
• تظل عمليات الحفظ والتقدم الحالية متوافقة.
</ar>
<hi-IN>
• अधिक सहज लड़ाइयाँ और मेन्यू: बैच में ड्रॉइंग, दोबारा उपयोग किए गए मैप और पाँच सेकंड बिना इनपुट के बाद रुकने वाले एनिमेशन।
• नया लॉन्च एनिमेशन, टैप से छोड़ा जा सकता है और कम गति में बंद रहता है।
• अनुकूलित इंजन और फ़ॉन्ट के साथ छोटे मोबाइल डाउनलोड।
• अधिक सुरक्षित सेव: इंटरफ़ेस बदलाव एक साथ सेव होते हैं; पॉज़, बैकग्राउंड, बंद करना, खरीद और इनाम तुरंत सेव रहते हैं।
• मौजूदा सेव और प्रगति संगत रहती है।
</hi-IN>
<id>
• Pertempuran dan menu lebih lancar: penggambaran batch, peta yang dipakai ulang, dan animasi yang berhenti setelah lima detik tanpa interaksi.
• Animasi peluncuran baru, dapat dilewati dengan ketukan dan dinonaktifkan saat Gerakan Dikurangi.
• Unduhan seluler lebih kecil berkat mesin dan font yang dioptimalkan.
• Penyimpanan lebih aman: perubahan antarmuka dikelompokkan; jeda, latar belakang, penutupan, pembelian, dan hadiah tetap disimpan segera.
• Simpanan dan progres yang ada tetap kompatibel.
</id>
<vi>
• Trận chiến và menu mượt hơn: vẽ theo lô, bản đồ dùng lại và hoạt ảnh tạm dừng sau năm giây không tương tác.
• Hoạt ảnh khởi động mới, có thể bỏ qua bằng chạm và tắt khi bật Giảm chuyển động.
• Bản tải xuống di động nhỏ hơn nhờ engine và phông chữ được tối ưu.
• Lưu an toàn hơn: thay đổi giao diện được gom lại; tạm dừng, nền, đóng, mua và phần thưởng vẫn lưu ngay.
• Bản lưu và tiến trình hiện có vẫn tương thích.
</vi>
<zh-CN>
• 更流畅的战斗和菜单：批量绘制、复用地图，并在五秒无操作后暂停动画。
• 新的启动动画，轻触即可跳过，减少动态效果时自动禁用。
• 通过优化引擎和字体，移动端下载更小。
• 更安全的保存：界面改动会合并写入；暂停、切到后台、关闭、购买和奖励仍会立即保存。
• 现有存档和进度保持兼容。
</zh-CN>
<ja-JP>
• バトルとメニューがより滑らかに：描画をまとめ、マップを再利用し、5秒間操作がないとアニメーションを停止します。
• 新しい起動アニメーションはタップでスキップでき、視差効果を減らす設定では無効になります。
• 最適化されたエンジンとフォントでモバイルのダウンロードが軽量化。
• 保存がより安全に：画面設定の変更はまとめて保存され、一時停止・バックグラウンド・終了・購入・報酬は引き続き即時保存されます。
• 既存のセーブと進行状況は互換性を保ちます。
</ja-JP>
<ko-KR>
• 더 부드러운 전투와 메뉴: 일괄 그리기, 재사용되는 지도, 5초간 입력이 없으면 멈추는 애니메이션.
• 새 시작 애니메이션은 탭으로 건너뛸 수 있으며 동작 줄이기에서 비활성화됩니다.
• 최적화된 엔진과 글꼴로 모바일 다운로드 크기 감소.
• 더 안전한 저장: 화면 변경은 묶어서 저장하고, 일시정지·백그라운드·종료·구매·보상은 계속 즉시 저장됩니다.
• 기존 저장과 진행 상황은 호환됩니다.
</ko-KR>
```

Listing assets and update procedure: [PLAY_STORE_UPDATE.md](../PLAY_STORE_UPDATE.md).

## Candidate: invade.io 0.3.2 — telemetry defaults and store refresh

`versionCode` 6 · **owner must confirm code availability and publication status in Play Console**.

- Usage statistics and crash reports start enabled for new or missing settings; saved choices, including opt-outs, remain unchanged.
- Each option can be disabled separately in Settings → Privacy; analytics events waiting to be sent are discarded when disabled.
- Telemetry uses the actual Godot Debug/Release build type; editor tooling, tests, and headless runs do not initialize providers.
- The Play listing and its localized phone/tablet gallery are refreshed across 15 languages. These are store materials, not new in-game features.

Publish the matching policy and review Data safety/consent requirements before
distributing. Proposed payloads below apply **only to a shipped 0.3.2 binary**;
confirm actual production behavior first:

```text
<es-ES>
• Las estadísticas de uso y los informes de fallos empiezan activados; se respetan tus preferencias guardadas. Desactiva cada opción en Ajustes → Privacidad.
• Tu progreso se conserva al actualizar.
</es-ES>
<en-US>
• Usage statistics and crash reports now start enabled; your saved choices are respected. Turn either off in Settings → Privacy.
• Your existing progress is preserved when you update.
</en-US>
<pt-BR>
• As estatísticas de uso e os relatórios de falhas agora começam ativados; suas preferências salvas são respeitadas. Desative cada opção em Configurações → Privacidade.
• Seu progresso é mantido ao atualizar.
</pt-BR>
<fr-FR>
• Les statistiques d’utilisation et les rapports d'erreur sont désormais activés au départ ; vos choix enregistrés sont respectés. Désactivez chaque option dans Paramètres → Confidentialité.
• Votre progression est conservée lors de la mise à jour.
</fr-FR>
<de-DE>
• Nutzungsstatistiken und Absturzberichte sind jetzt zunächst aktiviert; gespeicherte Einstellungen bleiben erhalten. Deaktiviere die Optionen einzeln unter Einstellungen → Privatsphäre.
• Dein Fortschritt bleibt beim Update erhalten.
</de-DE>
<it-IT>
• Le statistiche di utilizzo e i rapporti sugli incidenti sono ora attivi inizialmente; le preferenze salvate vengono rispettate. Disattiva ogni opzione in Impostazioni → Privacy.
• I tuoi progressi vengono conservati con l’aggiornamento.
</it-IT>
<ru-RU>
• Статистика использования и отчёты о сбоях теперь включены по умолчанию; сохранённые настройки учитываются. Каждую опцию можно отключить в разделе Настройки → Конфиденциальность.
• Ваш прогресс сохраняется при обновлении.
</ru-RU>
<tr-TR>
• Kullanım istatistikleri ve kilitlenme raporları artık başlangıçta açık; kaydedilmiş tercihleriniz korunur. Her seçeneği Ayarlar → Mahremiyet bölümünden kapatabilirsiniz.
• İlerlemeniz güncelleme sırasında korunur.
</tr-TR>
<ar>
• أصبحت إحصاءات الاستخدام وتقارير الأعطال مفعّلة افتراضيًا؛ تُحترم تفضيلاتك المحفوظة. يمكنك تعطيل كل خيار على حدة من إعدادات → خصوصية.
• يُحفظ تقدمك عند التحديث.
</ar>
<hi-IN>
• उपयोग के आँकड़े और दुर्घटना की रिपोर्ट अब शुरुआत में चालू रहते हैं; आपकी सहेजी गई पसंद का सम्मान किया जाता है। सेटिंग्स → गोपनीयता में हर विकल्प अलग से बंद करें।
• अपडेट करने पर आपकी प्रगति सुरक्षित रहती है।
</hi-IN>
<id>
• Statistik penggunaan dan laporan kerusakan kini aktif secara default; pilihan yang tersimpan tetap dihormati. Nonaktifkan setiap opsi di Pengaturan → Pribadi.
• Progres Anda tetap tersimpan saat memperbarui.
</id>
<vi>
• Thống kê sử dụng và báo cáo sự cố hiện được bật mặc định; lựa chọn đã lưu của bạn được giữ nguyên. Tắt từng tùy chọn trong Cài đặt → Sự riêng tư.
• Tiến trình của bạn được giữ lại khi cập nhật.
</vi>
<zh-CN>
• 使用统计和崩溃报告现在默认开启；已保存的选择保持不变。可在设置 → 隐私中分别关闭这两个选项。
• 更新后保留现有游戏进度。
</zh-CN>
<ja-JP>
• 利用状況の統計とクラッシュレポートが初期設定で有効になりました。保存済みの設定は引き継がれます。設定 → プライバシーでそれぞれ無効にできます。
• アップデート後もゲームの進行状況は保持されます。
</ja-JP>
<ko-KR>
• 사용 통계와 충돌 보고서가 이제 기본으로 켜집니다. 저장된 설정은 그대로 유지됩니다. 설정 → 개인정보에서 각 항목을 따로 끌 수 있습니다.
• 업데이트해도 기존 게임 진행 상황이 유지됩니다.
</ko-KR>
```

Listing assets and update procedure: [PLAY_STORE_UPDATE.md](../PLAY_STORE_UPDATE.md).

## Reference: invade.io 0.3.0 — accessibility and large screens

`versionCode` 4 · `versionName` 0.3.0.

Historical Play Console payloads (under 500 characters per language). The phrase
“screen-reader-friendly” describes the controls, not verified mobile TalkBack or
VoiceOver support; see [platform limitations](../PLATFORM_INTEGRATION.md#accessibility).

```
<es-ES>
¡Nueva actualización de invade.io!
• Más accesibilidad: texto grande, más contraste y controles de batalla para lector de pantalla.
• Menús y batallas para tabletas y apaisado, incluso al girar durante una partida.
• Partidas nuevas y guardados sin idioma siguen el idioma del dispositivo; se conserva tu elección.
• Más estabilidad en iPhone y diagnósticos opcionales.
• Tu progreso se conserva al actualizar.
</es-ES>
<en-US>
New invade.io update!
• Accessibility options: larger text, stronger map contrast, and screen-reader-friendly battle controls.
• Menus and battles adapt to tablets and landscape screens, including rotation during a match.
• New games and older saves without a saved language follow your device language; saved choices stay in place.
• Improved iPhone stability and optional diagnostics.
• Your progress is preserved when you update.
</en-US>
```

## Version reference

Dates were not recorded in this document. Confirm distributed versions in Play
Console and exact commits in GitHub releases; these rows are not deployment logs.

| Version | versionCode | Publication date | Scope described by the reference notes |
|---|---|---|---|
| 0.1.0 | 1 | Not recorded | Initial campaign, free conquest, daily challenge/missions, achievements, atlas, and cosmetics draft |
| 0.2.0 | 3 | Not recorded | 36 invasion regions / 108 fronts, 15 languages, optional telemetry, and UI improvements |
| 0.3.0 | 4 | Not recorded | Alternate controls, large-screen layouts, iOS improvements, and device-locale selection |
| 0.3.1 | 5 | Verify before distribution | License viewer and build isolation/hardening |
| 0.3.2 | 6 | Verify before distribution | Enabled telemetry defaults and localized store refresh |
| 0.4.0 | 7 | Verify before distribution | Faster battles/menus, launch animation, safer save timing, and smaller mobile builds |
