# Marketplace Data Warehouse Platform

**Полноценная end-to-end платформа Data Warehouse для онлайн-маркетплейса**

Проект реализует современный аналитический стек: от высокодоступного OLTP-слоя до real-time CDC, моделирования данных по Data Vault 2.0, потоковой загрузки в Iceberg и построения витрин с оркестрацией Airflow + BI в Superset.

## Миграции
* В папке migrations созданы 3 файла с миграциями, которые создают структуру трех бд онлайн-магазина.

* Настроена автоматическая инициализация бд через добавление volume с миграциями в docker-compose

## Репликация
* Настроена автоматическая репликация. 
* Инициализация реплкик происходит в файле scripts/init_replica.sh, который подключается в volume реплики. 
* Скрипт проверяет доступнось мастера, создает копию данных через basebackup и настраивает автоматичекое подключение к мастеру.
* Создание файла pg_hba.conf происходит в скрипте из миграций 005_pg_hba_replication.sh
* Создание пользователя репликации происходит в файле микграций 004_replication.sql

## Когортный анализ
* Проведен когортный анализ клиентов. Скрипт содержится в папке cohort_analysis
* Скрипт конвертируется во view

## Отказоустойчивость
* Patroni управляет репликацией, автоматически переключает лидера
* Etcd $-$ распределённое хранилище конфигураций
* HAProxy маршрутизует запросы:
    * Запись идёт к Primary (мастеру) на порт 5000
    * Чтение идёт к репликам на порт 5001
* Мигратор ожидает лидера и инициализирует схему

## Инструкция по запуску
1. Склонировать репозиторий
```bash
git clone https://github.com/kay-kewl/marketplace-dwh
cd marketplace-dwh
```
2. Запустить сервисы
```bash
docker-compose up -d

# Проверьте статус
docker-compose ps
```

3. Когортный анализ
```bash
docker exec -i marketplace-dwh-postgres-master-1 psql -U postgres -d order_service_db < cohort_analysis/cohort_analysis.sql
```

4. Когортный анализ view
```bash
docker exec -i marketplace-dwh-postgres-master-1 psql -U postgres -d order_service_db < cohort_analysis/cohort_view.sql
```

5. Вывод таблицы с когортным анализом
```bash
docker exec marketplace-dwh-postgres-master-1 psql -U postgres -d order_service_db -c "SELECT * FROM cohort_analysis_view LIMIT 5;"
```

6. Отказоустойчивость 
```
# Запуск
cd ha/
docker-compose up -d --build

# Проверка HAProxy
curl -I http://localhost:7001

# Проверка Patroni
docker exec -it patroni-1 curl -I http://localhost:8008/master
docker exec -it patroni-1 curl -I http://localhost:8008/replica

# Проверка БД
docker exec -it patroni-1 pg_isready -h haproxy -p 5000
docker exec -it patroni-1 pg_isready -h haproxy -p 5001
```

## Connection string
```
# user_service_db
postgresql://postgres:postgres@localhost:5432/user_service_db

# order_service_db
postgresql://postgres:postgres@localhost:5432/order_service_db

# logistics_service_db
postgresql://postgres:postgres@localhost:5432/logistics_service_db
```

## Архитектура
Data Vault 2.0
## Обоснование выбора архитектуры
- **Масштабируемость и производительность:** В отличие от классического Data Vault, версия 2.0 спроектирована для работы с MPP-системами и data Lakes. Использование хэш-ключей обеспечивает равномерное распределение данных по узлам кластера, что важно для горизонтального масштабирования.
- **Оптимальный компромисс по сложности:** В отличие от Anchor Model, группировка атрибутов в satellite сокращает количество JOIN-ов при сборке витрин, ускоряя разработку и повышая читаемость кода.
- **Параллельная загрузка:** Строгое разделение на хабы, линки и сателлиты позволяет выполнять загрузку данных в разные части модели одновременно, без блокировок и взаимного влияния. 
- **Использование SCD2-структур:** Поскольку исходные данные уже содержат версионность, это удобно можно использовать для маппинга в сателлиты Data Vault 2.0, сохраняя всю историю изменений без потерь и дублирования логики.
- **Устойчивость к изменениям:** Добавление нового источника или атрибута не требует перестройки существующей модели, достаточно создать новый сателлит.
- **Append-first подход:** CDC-события сохраняются в staging insert-only, а в сателлитах применяется SCD2, что сохраняет историю изменений и обеспечивает идемпотентную загрузку.

## DDL
В файле dwh/docs/entities.md содержится описание хабов, линков и сателитов для DDL детального слоя.

В файле dwh/docs/ddl_config.yaml содержится конфигурация, которая подается на вход скриптам для генерации кода DDL.

Написаны скрипты для автоматического создания DDL детального слоя в папке dwh/scripts

ER-диаграмма:
![ER-диаграмма](./dwh/docs/dwh_ddl.png)
Построена по mermaid файлу dwh/docs/er_diagram.mmd

## Kafka + Debezium
Поднят debezium с автоматическим подключением коннекторов. Проверить создание топиков:
```
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list
```
## DMP
Реализован потоковый DMP:
- чтение CDC-событий из Kafka (Debezium);
- insert-only загрузка в `dwh_detailed.stg_kafka_events`;
- автоматическое разложение в hub-link-satellite по yaml-конфигу;
- SCD2 для satellite.

## Iceberg + MinIO
Добавлено масштабируемое хранилище MinIO + Iceberg(табличный формат). В качестве вычислительного движка используется Apache Spark. Код Spark-приложения расположен в директории spark/

В ha/docker-compose добавлены новые сервисы minio, spark-iceberg, mc

Реализован поток "Kafka $\to$ Spark $\to$ Iceberg":
- приложение читает Debezium-топики трёх сервисов;
- в `iceberg.default.events_raw` сохраняются технические поля CDC;
- загрузка append-only с checkpoint в `s3a://warehouse/checkpoints/iceberg`;
- используется S3-совместимое объектное хранилище MinIO + Iceberg как табличный слой DWH;
- схема рассчитана на масштабирование и отделена от OLTP PostgreSQL.

## Инструкция по запуску
0. Остановить и удалить контейнеры и тома (в корне)
```
docker compose down -v --remove-orphans || true
docker compose -f ha/docker-compose.yml down -v --remove-orphans || true
```
1. Запустить скрипты генерации инициализации DDL
```
# установка библиотеки 
python3 -m pip install pyyaml  

# запуск скриптов
python3 dwh/scripts/generate_hubs.py
python3 dwh/scripts/generate_links.py
python3 dwh/scripts/generate_satellites.py
python3 dwh/scripts/generate_ddl.py
```
2. Запустить сервисы
```
docker compose -f ha/docker-compose.yml up -d --build
docker compose -f ha/docker-compose.yml ps

# проверить готовность
docker compose -f ha/docker-compose.yml logs migrator
```

`migrator` должен завершиться с кодом 0. `dwh-postgres`, `debezium`, `kafka`, `dmp`, `spark-iceberg` должны быть в состоянии `Up`.

Проверка статуса `migrator`:
```
docker compose -f ha/docker-compose.yml ps -a migrator
```

Должно быть `Exited (0)`.

3. Проверка репликации
```
docker compose -f ha/docker-compose.yml exec -T patroni-1 psql -U postgres -d postgres -c "SELECT pg_is_in_recovery();"
docker compose -f ha/docker-compose.yml exec -T patroni-2 psql -U postgres -d postgres -c "SELECT pg_is_in_recovery();"
docker compose -f ha/docker-compose.yml exec -T patroni-3 psql -U postgres -d postgres -c "SELECT pg_is_in_recovery();"
```
Один узел должен быть с `f`, это primary, остальные с `t`, replica.


4. Проверка dwh
```
docker compose -f ha/docker-compose.yml exec -T dwh-postgres psql -U dwh_user -d dwh -c "\dt dwh_detailed.*"
```

5. Проверка работы debezium и kafka
```
bash debezium/scripts/check-debezium.sh
curl -s http://localhost:8083/connectors | jq .
```

6. Проверка e2e для CDC $\to$ DWH
```
bash spark/scripts/check_system.sh
```

Если ошибок нет и видно прирост Kafka offsets, `stg_kafka_events`, `iceberg.default.events_raw`, то система поднята.

## Для подключения
```
# DWH PostgreSQL
postgresql://dwh_user:dwh_password@localhost:5433/dwh

# Debezium Connect API
http://localhost:8083

# Kafka bootstrap
localhost:9092

# MinIO API / Console
http://localhost:9000
http://localhost:9001
```

## Airflow в docker-compose
- Добавлены сервисы Airflow в `ha/docker-compose.yml`:
    - `airflow-db`
    - `airflow-init`
    - `airflow-webserver`
    - `airflow-scheduler`
- Airflow подключен к DWH через connection URI в переменной `AIRFLOW_CONN_DWH_POSTGRES`.

## DAG-и и ETL витрин
- Реализован DAG `purchases_mart_daily`:
    - расписание: ежедневно в `02:00`
    - витрина: `presentation.purchase_analytics`
    - режим обновления: `full refresh` (`TRUNCATE` + `INSERT`)

- Реализован DAG `warehouse_delivery_daily`:
    - расписание: ежедневно в `03:00`
    - витрина: `presentation.warehouse_delivery_daily`
    - режим обновления: за `business_date` (за вчера)
    - защита от дублей: удаление старых данных за дату перед вставкой

- DDL обеих витрин лежит в `dwh/ddl/002_presentation.sql`.

## BI
- Поднят Apache Superset в `ha/docker-compose.yml`:
    - `superset-db`
    - `superset-init`
    - `superset`
- Конфиг Superset: `bi/superset/superset_config.py`.

## Как запустить

1. Очистить окружение:
```bash
docker compose -f ha/docker-compose.yml down -v --remove-orphans || true
```

2. Сгенерировать DDL детального слоя:
```bash
python3 -m pip install pyyaml
python3 dwh/scripts/generate_hubs.py
python3 dwh/scripts/generate_links.py
python3 dwh/scripts/generate_satellites.py
python3 dwh/scripts/generate_ddl.py
```

3. Задать переменные для Superset:
```bash
export SUPERSET_SECRET_KEY="superset_secret_key_change_me"
export SUPERSET_ADMIN_USERNAME="admin"
export SUPERSET_ADMIN_PASSWORD="admin"
export SUPERSET_ADMIN_FIRSTNAME="Superset"
export SUPERSET_ADMIN_LASTNAME="Admin"
export SUPERSET_ADMIN_EMAIL="admin@example.com"
```

4. Поднять сервисы:
```bash
docker compose -f ha/docker-compose.yml up -d --build
```

5. Проверить, что сервисы подняты:
```bash
docker compose -f ha/docker-compose.yml ps
```

6. Проверить Airflow UI:
- URL: `http://localhost:8088`
- Логин/пароль по умолчанию: `admin/admin`
- В списке DAG должны быть:
    - `purchases_mart_daily`
    - `warehouse_delivery_daily`

7. Проверить, что витрины созданы и наполняются:
```bash
docker compose -f ha/docker-compose.yml exec -T dwh-postgres \
    psql -U dwh_user -d dwh -c "\dt presentation.*"

docker compose -f ha/docker-compose.yml exec -T dwh-postgres \
    psql -U dwh_user -d dwh -c "SELECT COUNT(*) FROM presentation.purchase_analytics;"

docker compose -f ha/docker-compose.yml exec -T dwh-postgres \
    psql -U dwh_user -d dwh -c "SELECT COUNT(*) FROM presentation.warehouse_delivery_daily;"
```

8. Проверить бизнес-логику второй витрины:
- В Airflow запустить DAG `warehouse_delivery_daily` дважды с одинаковым `business_date` через `dag_run.conf`.
- Проверить, что число строк за дату не удваивается:
```sql
SELECT shipment_date, warehouse_id, COUNT(*)
FROM presentation.warehouse_delivery_daily
GROUP BY shipment_date, warehouse_id
HAVING COUNT(*) > 1;
```

9. Проверить Superset UI:
- URL: `http://localhost:8089`
- Логин/пароль: из переменных `SUPERSET_ADMIN_USERNAME` / `SUPERSET_ADMIN_PASSWORD`
