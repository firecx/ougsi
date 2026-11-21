# Система оркестрации

Первый макет проверяет создание виртуальной машины на KVM по заявке через службу оркестрации, службу управления ВМ и агент узла. Текущая сборка принимает заявку и сохраняет её для последующего исполнения. Вызовы агента и запуск гостя предусмотрены в Э4, обмен через очередь и проверка конечного результата — в Э5. Для подготовки ВМ стенда на Windows 11 используйте [локальный модуль Hyper-V](#развёртывание-вм-стенда-на-hyper-v).

- [План разработки v2](doc/Техническое%20задание/План%20разработки%20v2.md)
- [Журнал разработки](doc/Журнал%20разработки.md)
- [Ресурсы и проверки стенда Э1](doc/Эскизный%20проект/Стенд%20Э1.md)
- [Архитектура и контракт Э2](doc/Эскизный%20проект/Архитектура%20макета%20Э2.md)
- [OpenAPI службы оркестрации](api/orchestrator.openapi.yaml) и [службы управления ВМ](api/vm-service.openapi.yaml)

## Версионирование

Версия системы записывается в формате `X.Y.Z`. Для макета исходная версия — `0.1.0`. Maven собирает версию разработки `0.1.0-SNAPSHOT`.

| Разряд | Когда повышаем | Пример |
| --- | --- | --- |
| `X` | Глобальное изменение системы. Например, изменение архитектуры или контракта, требующее доработки нескольких компонентов. | `0.1.0` → `1.0.0` |
| `Y` | Изменение среднего масштаба внутри одного модуля или сервиса при сохранении работы остальных компонентов и их контрактов. | `0.1.0` → `0.2.0` |
| `Z` | Небольшая правка, исправление ошибки или другое минорное изменение. | `0.1.0` → `0.1.1` |

Увеличиваем выбранный разряд на единицу и обнуляем разряды справа. Если выпуск включает изменения разных уровней, повышаем старший из них. Новый номер и причину повышения записываем в журнале в строке коммита, который меняет версию. [Журнал разработки](doc/Журнал%20разработки.md)

При смене версии сборки обновляем корневой `pom.xml`, ссылки на него в POM обоих сервисов и имена JAR в командах запуска и CI. Версии API и протоколов ведём в их контрактах.

## Сборка и тесты

Службы используют Spring Boot 4.1.1. Для сборки из корня репозитория нужны JDK 21 и Maven 3.6.3 или новее.

```sh
mvn --batch-mode --no-transfer-progress verify
```

Обе службы собираются отдельными исполняемыми JAR. Тесты Java запускает JUnit через Maven Surefire. Для Java используйте форматирование IntelliJ IDEA с отступом в четыре пробела.

Агент собирается GCC с поддержкой C++17 и CMake/CTest 3.20 или новее. На Linux нужны GCC и Make. Для C++ используйте clang-format с правилами из [node-agent/.clang-format](node-agent/.clang-format). Тесты запускает CTest.

```sh
cmake -S node-agent -B .build/node-agent -DCMAKE_BUILD_TYPE=Release
cmake --build .build/node-agent --parallel
ctest --test-dir .build/node-agent --output-on-failure
.build/node-agent/node-agent --check-config 14c48a31-e5a4-491b-8f96-6a82876afa95 https://localhost:8443
```

На Windows используйте GCC MinGW-w64 и доступный в `PATH` GNU Make. Пример настройки из PowerShell использует `make.exe`. Если установлен `mingw32-make.exe`, укажите его в `Get-Command`.

```powershell
cmake -S node-agent -B .build/node-agent -G 'MinGW Makefiles' "-DCMAKE_MAKE_PROGRAM=$((Get-Command make.exe).Source)" "-DCMAKE_CXX_COMPILER=$((Get-Command g++.exe).Source)" -DCMAKE_BUILD_TYPE=Release
cmake --build .build/node-agent --parallel
ctest --test-dir .build/node-agent --output-on-failure
.\.build\node-agent\node-agent.exe --check-config 14c48a31-e5a4-491b-8f96-6a82876afa95 https://localhost:8443
```

## Развёртывание ВМ стенда на Hyper-V

Модуль Э0 создаёт ВМ второго поколения на локальном Hyper-V из установочного ISO или готового VHDX. Он запускается из командной строки и готовит гостевые ОС для разработки системы оркестрации.

Для сборки и тестов нужен .NET SDK 10. Для создания ВМ нужны Windows 11 Pro или Enterprise x64, включённый Hyper-V с модулем управления для Windows PowerShell 5.1 и аппаратная виртуализация. Запускайте `check` и `create` из PowerShell от имени администратора или под учётной записью с правами управления Hyper-V. [Установка Hyper-V](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/get-started/install-hyper-v)

Из корня репозитория соберите модуль и запустите тесты конфигурации и вызовов командлетов. Консольный проект .NET и сценарий Windows PowerShell выполняют тесты без запущенного Hyper-V. Для C# используйте `dotnet format whitespace windows-hyperv --folder`. В C# и PowerShell используйте отступ в четыре пробела.

```powershell
dotnet build windows-hyperv/src -c Release
dotnet run --project windows-hyperv/tests -c Release
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File windows-hyperv/tests/HyperV.Tests.ps1
```

Проверьте доступ к Hyper-V и список виртуальных коммутаторов, затем скопируйте [пример конфигурации](windows-hyperv/vm.example.json).

```powershell
dotnet run --project windows-hyperv/src -c Release -- check
New-Item -ItemType Directory -Path .build -Force | Out-Null
Copy-Item windows-hyperv/vm.example.json .build/hyperv-vm.json
```

В `.build/hyperv-vm.json` задайте имя ВМ и абсолютные пути на локальных дисках. `storageRoot` указывает на существующий каталог. Выберите один источник загрузки.

- `isoPath` указывает на установочный ISO с поддержкой UEFI. Модуль создаст динамический диск и запустит установщик с ISO. Установку гостевой ОС выполните в консоли ВМ.
- `sourceVhdxPath` указывает на самостоятельный VHDX с установленной гостевой ОС и загрузчиком UEFI. Модуль создаст отдельную копию диска для ВМ.

По умолчанию ВМ получает 2 vCPU, 4096 МиБ памяти и при установке с ISO диск 32 ГиБ. Эти параметры задаются полями `vcpus`, `memoryMiB` и `diskGiB`. Для подключения к сети укажите существующий `switchName`, например `Default Switch`, если он есть в результате `check`. Если поле пропущено, ВМ создаётся без подключения к коммутатору. `start: false` оставляет ВМ выключенной. Для Secure Boot укажите `secureBootTemplate` со значением `MicrosoftWindows` или `MicrosoftUEFICertificateAuthority`. При отсутствии поля Secure Boot выключен. [Настройки загрузки ВМ второго поколения](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/plan/should-i-create-a-generation-1-or-2-virtual-machine-in-hyper-v)

Создайте ВМ и проверьте её параметры по идентификатору из результата.

```powershell
$vm = dotnet run --project windows-hyperv/src -c Release --no-build -- create .build/hyperv-vm.json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Не удалось создать ВМ.' }
Get-VM -Id $vm.id
vmconnect.exe localhost $vm.name
```

Команда `create` возвращает JSON с идентификатором, именем и состоянием ВМ, путями к каталогу ВМ и диску и именем коммутатора. При занятом имени или каталоге модуль завершится с ошибкой. После установки с ISO извлеките его из виртуального DVD-привода, чтобы ВМ загружалась с системного диска.

Для узла KVM задайте `nestedVirtualization: true`. После загрузки Linux установите QEMU и libvirt и выполните [проверки Э1](doc/Эскизный%20проект/Стенд%20Э1.md#проверка-узла-kvm). Для готовности стенда проверьте запуск вложенной ВМ с ускорением KVM. [Требования к вложенной виртуализации](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/enable-nested-virtualization)

## Запуск контура разработки

Понадобятся работающий Docker Engine с Linux-контейнерами, Docker Compose с поддержкой `up --wait` и доступ к Maven Central и Docker Hub либо к локальным копиям зависимостей и образов. Порты 5432, 5672, 8080 и 8081 должны быть свободны. Все порты текущего контура привязаны к loopback.

```sh
cp .env.example .env
docker compose up --detach --wait
```

На Windows для копирования выполните `Copy-Item .env.example .env`. Значения из `.env.example` предназначены для локального стенда. При первом запуске PostgreSQL создаёт две схемы и отдельную роль для каждой службы. Данные PostgreSQL и RabbitMQ хранятся в именованных томах. SQL инициализации выполняется при первом создании тома PostgreSQL.

В двух терминалах из корня проекта загрузите значения из `.env` и запустите службы по одной на терминал:

```sh
set -a
. ./.env
set +a

# Терминал 1
java -jar services/orchestrator/target/orchestrator-0.1.0-SNAPSHOT.jar

# Терминал 2 (повторите загрузку .env)
java -jar services/vm-service/target/vm-service-0.1.0-SNAPSHOT.jar
```

В PowerShell для загрузки переменных выполните следующий блок перед командой `java` в каждом терминале:

```powershell
(Get-Content -Raw .env | ConvertFrom-StringData).GetEnumerator() | ForEach-Object {
    [Environment]::SetEnvironmentVariable($_.Key, $_.Value, 'Process')
}
```

Проверка работоспособности обеих служб возвращает `{"status":"UP"}`.

```sh
curl --fail http://127.0.0.1:8080/actuator/health
curl --fail http://127.0.0.1:8081/actuator/health
```

## Заявка на создание ВМ

В примере используются идентификаторы для проверки приёма и сохранения заявки. Для запуска гостя в Э4 потребуются реальные идентификаторы узла и подготовленного образа.

```sh
curl --include --header 'Content-Type: application/json' \
  --data '{"nodeId":"14c48a31-e5a4-491b-8f96-6a82876afa95","imageId":"6b7cda20-f659-479c-b30f-fb3913da97b6","name":"demo-guest","vcpus":2,"memoryMiB":2048,"diskGiB":20,"network":"default"}' \
  http://127.0.0.1:8080/api/v1/requests
```

Служба отвечает `202 Accepted` и возвращает `requestId`, `stepId`, статус `QUEUED` и заголовок `Location`. Вызовите `curl --fail http://127.0.0.1:8080<значение Location>`, чтобы прочитать состояние. После перезапуска службы повторите запрос по тому же адресу. Процесс GitHub Actions выполняет сборку, тесты и эту проверку с чистой копии.

Чтобы остановить контур, завершите процессы Java и выполните `docker compose down`.
