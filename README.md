# Mac Toolbox

Нативный набор утилит для macOS в меню-баре (в духе Parallels Toolbox). Swift 6 + SwiftUI, macOS 14+.

## Инструменты

- **Не засыпать** — держит Mac (и, по желанию, экран) включённым. Переключатель запускает
  последнюю выбранную длительность; разверните карточку, чтобы выбрать 15 мин … 8 ч, ∞ или своё значение.
- **Таймер сна** — через заданное время отправляет Mac в сон, гасит экран или выключает его.
  Во время отсчёта можно добавить +5/15/30 мин.

## Сборка

Нужны Xcode и [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
make run      # сгенерировать проект, собрать и запустить
make project  # только сгенерировать MacToolbox.xcodeproj для Xcode
```

## Структура

```
MacToolbox/
  App/        точка входа (MenuBarExtra)
  Core/       общие вещи: тикер, форматирование, автозапуск
  Tools/      по папке на инструмент: модель + view
  UI/         общие компоненты: ToolCard, DurationPicker, SVG-иконки
  Resources/  Icons/*.svg (template-иконки), AppIcon.icon (Icon Composer)
```

Новый инструмент = папка в `Tools/` с `@Observable`-моделью и view на базе `ToolCard`,
добавленная в `RootView`.
