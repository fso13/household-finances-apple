# Участие в проекте

Спасибо, что хотите помочь. Проект небольшой, поэтому лучший вклад — воспроизводимый баг-репорт или узкий pull request.

## Перед началом

- Посмотрите [Issues](https://github.com/fso13/household-finances-apple/issues) и [Roadmap](ROADMAP.md).
- Для крупной фичи сначала создайте issue и опишите сценарий.
- Не добавляйте внешние зависимости без обсуждения.

## Локальная сборка

```bash
swift build
swift test
./Scripts/package_app.sh
open "dist/Финансы.app"
```

Требования: macOS 14+, Xcode 16+, Swift 6. Подробнее — в [Wiki](https://github.com/fso13/household-finances-apple/wiki/Getting-Started).

## Ветки и коммиты

```
feat/short-description
fix/short-description
chore/short-description
docs/short-description
```

Conventional Commits:

```
feat: add CSV import wizard
fix: prevent duplicate recurring payments
chore: split FinancesCore target
docs: update roadmap
```

В теле коммита ссылайтесь на issue: `Refs #16`, `Closes #16`.

## Что проверяет CI

- `swift build`
- `swift test` (после появления тестов)
- `swift-format lint`
- сборка `.app` и артефакт

## Правила кода

- Бизнес-логика — в `FinancesCore`, без импорта SwiftUI/AppKit.
- Деньги — целые копейки или `Decimal`, не `Double`.
- Даты — через `Clock`/`Calendar`, не `Date()` внутри моделей.
- Ошибки — через `AppError`, не `try?` в пользовательских сценариях.
- Новый расчёт — unit-тест; новый экран — snapshot или smoke-сценарий.
- UI-тексты — на русском, грамотно и без сокращений, которые непонятны без контекста.

## Pull request

- Один PR — одна задача.
- Заполните шаблон PR.
- Приложите скриншоты для изменений интерфейса.
- Обновите README/ROADMAP/CHANGELOG, если меняется поведение.

## Безопасность

Не публикуйте реальные финансовые данные, ключи и полные бэкапы в issues и PR. О проблеме безопасности — см. [SECURITY.md](SECURITY.md).
