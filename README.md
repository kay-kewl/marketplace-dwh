# Homework 1

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

# Homework 2
## Архитектура
Data Vault 2.0
## Обоснование выбора архитектуры
- **Масштабируемость и производительность:** В отличие от классического Data Vault, версия 2.0 спроектирована для работы с MPP-системами и data Lakes. Использование хэш-ключей обеспечивает равномерное распределение данных по узлам кластера, что важно для горизонтального масштабирования.
- **Оптимальный компромисс по сложности:** В отличие от Anchor Model, группировка атрибутов в satellite сокращает количество JOIN-ов при сборке витрин, ускоряя разработку и повышая читаемость кода.
- **Параллельная загрузка:** Строгое разделение на хабы, линки и сателлиты позволяет выполнять загрузку данных в разные части модели одновременно, без блокировок и взаимного влияния. 
- **Использование SCD2-структур:** Поскольку исходные данные уже содержат версионность, это удобно можно использовать для маппинга в сателлиты Data Vault 2.0, сохраняя всю историю изменений без потерь и дублирования логики.
- **Устойчивость к изменениям:** Добавление нового источника или атрибута не требует перестройки существующей модели, достаточно создать новый сателлит.
- **Insert-only:** Отсутствие Update и Delete гарантирует идемпотентность загрузки и возможность отката во времени для восстановления состояния данных на любой момент.

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
- в `iceberg.events_raw` сохраняются технические поля CDC;
- загрузка append-only с checkpoint в `s3a://warehouse/checkpoints/iceberg`;
- используется S3-совместимое объектное хранилище MinIO + Iceberg как табличный слой DWH;
- схема рассчитана на масштабирование и отделена от OLTP PostgreSQL.

## Инструкция по запуску
1. Запустить скрипты генерации инициализации DDL
Необходимо выполнить из корня проекта
```
# установка библиотеки 
python -m pip install pyyaml  

# запуск скриптов
python dwh/scripts/generate_hubs.py
python dwh/scripts/generate_links.py
python dwh/scripts/generate_satellites.py
python dwh/scripts/generate_ddl.py
```
2. Запустить сервисы
```
cd ha/
docker-compose up -d
```
3. Проверка создания таблиц
```
docker-compose exec dwh-postgres psql -U dwh_user -d dwh -c "\dt dwh_detailed.*"
```

4. Проверка работы debezium
```
cd ../debezium
./scripts/check-debezium.sh
```

5. Проверка подключения коннекторов
```
curl -s http://localhost:8083/connectors | jq .
```

6. Протестировать запись в MinIO
```
cd spark/scripts
./check_system.sh
```

7. Проверить данные в Iceberg вручную
```
docker exec spark-iceberg spark-sql \
    --conf spark.sql.catalog.iceberg=org.apache.iceberg.spark.SparkCatalog \
    --conf spark.sql.catalog.iceberg.type=hadoop \
    --conf spark.sql.catalog.iceberg.warehouse=s3a://warehouse/ \
    --conf spark.hadoop.fs.s3a.endpoint=http://minio:9000 \
    --conf spark.hadoop.fs.s3a.access.key=minioadmin \
    --conf spark.hadoop.fs.s3a.secret.key=minioadmin \
    --conf spark.hadoop.fs.s3a.path.style.access=true \
    --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
    -e "SELECT source_db, source_table, event_type, COUNT(*) FROM iceberg.events_raw GROUP BY 1,2,3 ORDER BY 1,2,3;"
```