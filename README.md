# Система оркестрации

Первый макет проверяет создание виртуальной машины на KVM по заявке через службу оркестрации, службу управления ВМ и агент узла. Текущая сборка принимает заявку и сохраняет её для последующего исполнения. Вызовы агента и запуск гостя предусмотрены в Э4, обмен через очередь и проверка конечного результата — в Э5.

- [План разработки v2](doc/Техническое%20задание/План%20разработки%20v2.md)
- [Журнал разработки](doc/Журнал%20разработки.md)
- [Ресурсы и проверки стенда Э1](doc/Эскизный%20проект/Стенд%20Э1.md)
- [Архитектура и контракт Э2](doc/Эскизный%20проект/Архитектура%20макета%20Э2.md)
- [OpenAPI службы оркестрации](api/orchestrator.openapi.yaml) и [службы управления ВМ](api/vm-service.openapi.yaml)

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
