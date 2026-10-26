# Сборка euf

Сборка модов для **Minecraft 1.20.1 (Fabric)**: наши моды и всё, что с ними играется вместе. Ставится и обновляется одним файлом в TLauncher, лицензия Minecraft не нужна.

## Что внутри

| Мод | Что делает | Откуда |
|---|---|---|
| [Ender Obelisks](https://github.com/stardely62-oss/modhyed) | обелиски для телепортации между точками мира, ярусы дальности, руины | наш, GitHub Releases |
| [Mage's Legacy](https://github.com/stardely62-oss/mages-legacy) | расы с деревом талантов: Мицелиды, Пастыри, Застывшие, Кровники | наш, GitHub Releases |
| [JourneyMap](https://modrinth.com/mod/journeymap) | миникарта и полноэкранная карта, обелиски видны на ней | Modrinth, версия 6.0.7 |
| [Fabric API](https://modrinth.com/mod/fabric-api) | библиотека, нужна всем модам | Modrinth, под твой Fabric Loader |

Точный список с версиями лежит в [`modpack.json`](modpack.json). Установщик берёт его отсюда при каждом запуске, так что новые моды сборки приходят сами.

## Установка (TLauncher)

1. В TLauncher выбери **Fabric 1.20.1** и запусти один раз до главного меню.
2. Скачай [`euf-modpack.zip`](https://github.com/stardely62-oss/euf-modpack/releases/latest/download/euf-modpack.zip), распакуй куда угодно и запусти `install-modpack.bat`.
3. Запускай в TLauncher версию **Fabric 1.20.1**.

Для обновления запусти `install-modpack.bat` ещё раз: он докачает новые версии и уберёт старые.

Параметры (для `install.ps1`):
- `-Stable` — стабильные релизы наших модов вместо свежих dev-сборок;
- `-VersionName "…"` — другое имя версии в TLauncher;
- `-GameDir "…"` — другая папка игры.

## Клавиши

Клавиши модов не пересекаются друг с другом. Mage's Legacy: **R / V / Z** — способности расы (у пастырей ещё **H**), **K** — дерево талантов, **U** — бестиарий, **Y** — следующий отряд. JourneyMap: **J** — карта, **B** — новая метка.

## Для разработки

Чужие моды не хранятся в репозитории: установщик качает их с Modrinth и сверяет контрольную сумму. Чтобы добавить мод, допиши его в `modpack.json`:
- для нашего мода — `github` и маску `asset`;
- для чужого — `url`, `file` и `sha512` с Modrinth.

`replaces` — какие старые файлы убрать при обновлении.
