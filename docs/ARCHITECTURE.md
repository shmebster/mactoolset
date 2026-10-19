# Архитектура

Mac Toolbox — SwiftUI-приложение без Dock-иконки (`LSUIElement`), вся работа идёт в
`MenuBarExtra` со стилем `.window`. Внешних зависимостей нет.

```
MacToolbox/
├── App/
│   ├── MacToolboxApp.swift      точка входа: MenuBarExtra + связи между инструментами
│   └── PreviewWindow.swift      DEBUG: `--preview-window` открывает панель в обычном окне
├── Core/
│   ├── Ticker.swift             секундный тикер + ProcessInfo activity против App Nap
│   ├── DurationFormat.swift     «1 ч 30 мин», «1:23:45», подписи чипов
│   ├── Recordings.swift         папки и имена файлов записей
│   ├── Permissions.swift        микрофон, ссылки в Системные настройки, ошибки
│   └── LaunchAtLogin.swift      SMAppService
├── Tools/
│   ├── PreventSleep/            IOPMAssertion
│   ├── SleepTimer/              pmset / AppleScript
│   ├── ScreenRecorder/          SCStream + SCRecordingOutput, выбор области и окна
│   └── AudioRecorder/           SCStream (audio-only) → .caf → сведение в .m4a
├── UI/
│   ├── RootView.swift           шапка, меню настроек, список карточек
│   ├── ToolCard.swift           общая карточка инструмента
│   ├── DurationPicker.swift     сетка длительностей, ChipStyle, ChipPicker
│   ├── MenuBarLabel.swift       иконка и отсчёт в меню-баре
│   ├── MenuBarPanel.swift       закрытие панели перед записью
│   └── SVGIcon.swift            загрузка SVG-иконок
└── Resources/
    ├── Icons/*.svg              иконки интерфейса (template, 24×24)
    └── AppIcon.icon/            иконка приложения в формате Icon Composer
```

## Как устроен инструмент

Каждый инструмент — это пара **модель + view**:

- **Модель** — `@MainActor @Observable final class` с синглтоном `shared`. Она хранит
  состояние (`isActive`, `phase`, `endDate`, …) и пользовательские настройки. Настройки
  пишутся в `UserDefaults` через `didSet` и читаются в `init`. Модели доступны и из
  `MenuBarLabel`, и из других инструментов: например, таймер сна выключает «Не засыпать»
  перед тем, как усыпить Mac.
- **View** строится на `ToolCard`: иконка-плитка, название, строка статуса, переключатель
  и разворачиваемая панель. Развёрнута карточка или нет, хранится в
  `@AppStorage("ui.expanded.<tool>")`.

Общее правило UX: **переключатель запускает инструмент с последними настройками**, а в
развёрнутой карточке настройку можно выбрать явно — этот выбор сразу запускает инструмент
и становится новым значением по умолчанию.

### Добавление нового инструмента

1. Нарисуйте иконку `Resources/Icons/<name>.svg` (см. ниже).
2. Создайте `Tools/<Name>/<Name>.swift` с моделью по образцу `PreventSleep`.
3. Создайте `Tools/<Name>/<Name>View.swift` на базе `ToolCard`.
4. Добавьте view в `RootView`. Если у инструмента есть состояние, которое стоит показывать
   в меню-баре, — добавьте его в `MenuBarLabel.state`.
5. `make run` — XcodeGen сам подхватит новые файлы.

## Иконки

Все иконки — самописные SVG. `NSImage` умеет рендерить SVG нативно, поэтому они кладутся
в бандл как есть и грузятся через `SVGIcon.image(_:size:)`. Это template-изображения, они
красятся через `foregroundStyle` и сами подстраиваются под светлую/тёмную тему и меню-бар.

Правила для новых иконок: `viewBox="0 0 24 24"`, обводка `#000`, `stroke-width="1.8"`,
скруглённые концы и углы. Заливка — только чёрным: цвет задаёт код.

Иконка приложения лежит в `AppIcon.icon` (формат Icon Composer, Liquid Glass): градиентный
фон описан в `icon.json`, глиф — `Assets/toolbox.svg`. Xcode компилирует её в `AppIcon.icns`
и `Assets.car`.

## Детали реализации

### Не засыпать
`IOPMAssertionCreateWithName` с типом `PreventUserIdleDisplaySleep` (экран не гаснет) или
`PreventUserIdleSystemSleep` (экран может погаснуть, система — нет). Если поменять опцию
во время работы, assertion пересоздаётся.

### Таймер сна
Дедлайн хранится как `Date`, а `Ticker` раз в секунду сверяет его с текущим временем,
поэтому отсчёт остаётся точным даже после пробуждения или «заморозки» процесса. Действия:
`pmset sleepnow`, `pmset displaysleepnow` и `tell application "System Events" to shut down`.

### Тикер и App Nap
Фоновое приложение без окон macOS быстро отправляет в App Nap, и таймеры начинают
опаздывать. `Ticker`, пока он запущен, держит
`ProcessInfo.beginActivity(.userInitiatedAllowingIdleSystemSleep)`: так App Nap не
включается, а система при этом может уснуть по простою.

### Запись экрана
- **Экран** — дисплей под курсором; окна самого Mac Toolbox исключаются из фильтра.
- **Окно** — системный `SCContentSharingPicker` (окно или приложение целиком).
- **Область** — `AreaSelector`: прозрачное окно уровня `.screenSaver` поверх экрана,
  выделение через `DragGesture`. Прямоугольник уходит в `SCStreamConfiguration.sourceRect`.

Видео пишет `SCRecordingOutput` (macOS 15) прямо в HEVC `.mov`. Размеры кадра округляются
до чётных — так требует кодек. Системный звук и микрофон попадают в файл отдельными
дорожками. Остановку через системный индикатор записи ловит `SCStreamDelegate`.

### Запись звука
`SCStream` с минимальным видео (2×2, 1 fps), без него поток не запускается. Буферы
`.audio` и `.microphone` пишутся в отдельные временные `.caf`; формат файла берётся из
первого буфера, поэтому моно-микрофон и стерео-система не конфликтуют. После остановки
`AudioMixer` выравнивает дорожки по времени первого буфера в `AVMutableComposition` и
экспортирует их пресетом `AppleM4A`, который сводит всё в одну AAC-дорожку.

### Swift 6 concurrency
Модели и UI работают на `@MainActor`. Сессии захвата — `@unchecked Sendable` классы,
у которых изменяемое состояние доступно только из собственной serial-очереди (или
защищено `OSAllocatedUnfairLock`). Не-Sendable объекты ScreenCaptureKit передаются между
изоляциями через `UncheckedBox`.
