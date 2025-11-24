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


