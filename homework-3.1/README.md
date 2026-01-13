# Домашнее задание 3.1 - Компоненты Kubernetes

Расчет требований к кластеру для многокомпонентного приложения и упаковка в Helm chart для разных окружений.

## Описание системы

Приложение состоит из четырех компонентов:

1. **База данных (PostgreSQL)** - отказоустойчивое хранилище
2. **Система кеширования (Redis)** - отказоустойчивый кеш
3. **Frontend (nginx)** - статические файлы и веб-интерфейс
4. **Backend** - API и бизнес-логика

## Требования к ресурсам

### Исходные данные из задания

| Компонент | RAM на копию | CPU на копию | Количество копий | RAM всего | CPU всего |
|-----------|--------------|--------------|------------------|-----------|-----------|
| База данных | 4 GB | 1 CPU | 3 | 12 GB | 3 CPU |
| Система кеширования | 4 GB | 1 CPU | 3 | 12 GB | 3 CPU |
| Frontend | 50 MB | 0.2 CPU | 5 | 250 MB | 1 CPU |
| Backend | 600 MB | 1 CPU | 10 | 6 GB | 10 CPU |
| **ИТОГО приложения** | | | **21 копий** | **~30.1 GB** | **17 CPU** |

### Служебные ресурсы Kubernetes

На каждой ноде Kubernetes требуются ресурсы для системных компонентов:

| Компонент | RAM | CPU |
|-----------|-----|-----|
| kubelet, kube-proxy | ~200 MB | 0.1 |
| CNI, CSI драйверы | ~300 MB | 0.1 |
| Системный мониторинг | ~200 MB | 0.1 |
| **Итого на ноду** | **~700 MB** | **~0.3 CPU** |

## Расчет количества нод

### Вариант 1: e2-standard-4 (4 vCPU, 16 GB RAM)

**Доступно на ноду после вычета системных ресурсов:**
- RAM: 16 GB - 0.7 GB = 15.3 GB
- CPU: 4 - 0.3 = 3.7 CPU

**Минимальное количество нод:**
- По RAM: 30.1 GB / 15.3 GB = **1.97 ноды → 2 ноды**
- По CPU: 17 CPU / 3.7 CPU = **4.59 нод → 5 нод**

**Узкое место: CPU** - нужно минимум **5 нод**

**С учетом отказоустойчивости (+1 нода):** **6 нод e2-standard-4**

### Вариант 2: e2-standard-8 (8 vCPU, 32 GB RAM)

**Доступно на ноду после вычета системных ресурсов:**
- RAM: 32 GB - 0.7 GB = 31.3 GB
- CPU: 8 - 0.3 = 7.7 CPU

**Минимальное количество нод:**
- По RAM: 30.1 GB / 31.3 GB = **0.96 ноды → 1 нода**
- По CPU: 17 CPU / 7.7 CPU = **2.21 ноды → 3 ноды**

**Узкое место: CPU** - нужно минимум **3 ноды**

**С учетом отказоустойчивости (+1 нода):** **4 ноды e2-standard-8**

### Сравнение вариантов

| Параметр | e2-standard-4 (6 нод) | e2-standard-8 (4 ноды) |
|----------|----------------------|------------------------|
| Общий CPU | 24 vCPU | 32 vCPU |
| Общий RAM | 96 GB | 128 GB |
| Запас CPU | 41% | 88% |
| Запас RAM | 219% | 325% |
| Отказоустойчивость | Средняя | Хорошая |
| Стоимость (месяц)* | ~$145 | ~$192 |
| Управление | Сложнее | Проще |

*Примерные цены для GCP us-central1

## Итоговая конфигурация

### Рекомендация: 4 ноды e2-standard-8

**Обоснование:**
1. **Достаточный запас ресурсов** - при отказе одной ноды (25% мощности) остается ~65% CPU и 244% RAM
2. **Проще управлять** - меньше нод означает меньше точек отказа
3. **Оптимальная стоимость** - всего на 32% дороже, но с лучшим запасом
4. **Упрощенное размещение подов** - больше ресурсов на ноде упрощает планирование

**Итоговые ресурсы кластера:**
- **Нод**: 4
- **Тип ноды**: e2-standard-8 (8 vCPU, 32 GB RAM)
- **Общие ресурсы**: 32 vCPU, 128 GB RAM
- **Доступно приложениям**: ~30.8 vCPU, ~125.2 GB RAM
- **Используется приложениями**: 17 vCPU, 30.1 GB RAM
- **Запас**: 13.8 vCPU (81%), 95.1 GB RAM (316%)

## Helm Chart

### Структура проекта

```
homework-3.1/
├── README.md                          # Документация
└── myapp/                             # Helm chart
    ├── Chart.yaml                     # Описание чарта
    ├── values.yaml                    # Базовые значения (prod)
    ├── values-dev.yaml                # Окружение разработки
    ├── values-staging.yaml            # Тестовое окружение
    └── templates/
        ├── _helpers.tpl               # Вспомогательные функции
        ├── database-statefulset.yaml  # StatefulSet для PostgreSQL
        ├── database-service.yaml      # Service для базы данных
        ├── cache-statefulset.yaml     # StatefulSet для Redis
        ├── cache-service.yaml         # Service для кеша
        ├── frontend-deployment.yaml   # Deployment для nginx
        ├── frontend-service.yaml      # Service для frontend
        ├── backend-deployment.yaml    # Deployment для backend
        └── backend-service.yaml       # Service для backend
```

### Окружения

#### Production (values.yaml)
- База данных: 3 реплики, 4 GB RAM, 1 CPU
- Кеш: 3 реплики, 4 GB RAM, 1 CPU
- Frontend: 5 реплик, 50 MB RAM, 0.2 CPU
- Backend: 10 реплик, 600 MB RAM, 1 CPU
- Persistent storage: включен

#### Staging (values-staging.yaml)
- База данных: 2 реплики, 3 GB RAM, 0.75 CPU
- Кеш: 2 реплики, 3 GB RAM, 0.75 CPU
- Frontend: 3 реплики
- Backend: 5 реплик, 450 MB RAM, 0.75 CPU
- Persistent storage: включен

#### Development (values-dev.yaml)
- База данных: 1 реплика, 2 GB RAM, 0.5 CPU
- Кеш: 1 реплика, 2 GB RAM, 0.5 CPU
- Frontend: 2 реплики
- Backend: 2 реплики, 300 MB RAM, 0.5 CPU
- Persistent storage: выключен

## Установка и использование

### Проверка чарта

```bash
# Проверить синтаксис
helm lint myapp/

# Проверить шаблоны для dev окружения
helm template myapp-dev myapp/ -f myapp/values-dev.yaml

# Проверить шаблоны для staging окружения
helm template myapp-staging myapp/ -f myapp/values-staging.yaml

# Проверить шаблоны для production окружения
helm template myapp-prod myapp/
```

### Создание кластера GKE

```bash
# Создать кластер с 4 нодами e2-standard-8
gcloud container clusters create k8s-homework-3-1 \
  --zone us-central1-a \
  --num-nodes 4 \
  --machine-type e2-standard-8 \
  --project upheld-rookery-471109-b0 \
  --service-account serviceforbot@upheld-rookery-471109-b0.iam.gserviceaccount.com

# Подключиться к кластеру
gcloud container clusters get-credentials k8s-homework-3-1 \
  --zone us-central1-a \
  --project upheld-rookery-471109-b0
```

### Развертывание приложения

#### Development окружение

```bash
# Создать namespace
kubectl create namespace dev

# Установить приложение
helm install myapp-dev ./myapp \
  --namespace dev \
  --values myapp/values-dev.yaml

# Проверить статус
kubectl get all -n dev
helm list -n dev
```

#### Staging окружение

```bash
kubectl create namespace staging

helm install myapp-staging ./myapp \
  --namespace staging \
  --values myapp/values-staging.yaml

kubectl get all -n staging
```

#### Production окружение

```bash
kubectl create namespace prod

helm install myapp-prod ./myapp \
  --namespace prod

kubectl get all -n prod
```

### Обновление релиза

```bash
# Обновить количество реплик backend в dev
helm upgrade myapp-dev ./myapp \
  --namespace dev \
  --values myapp/values-dev.yaml \
  --set replicaCount.backend=3

# Посмотреть историю изменений
helm history myapp-dev -n dev

# Откатиться к предыдущей версии
helm rollback myapp-dev 1 -n dev
```

### Мониторинг ресурсов

```bash
# Использование ресурсов нод
kubectl top nodes

# Использование ресурсов подов
kubectl top pods -n dev
kubectl top pods -n staging
kubectl top pods -n prod

# Детальная информация о распределении ресурсов
kubectl describe nodes | grep -A 5 "Allocated resources"
```

### Удаление

```bash
# Удалить релизы
helm uninstall myapp-dev -n dev
helm uninstall myapp-staging -n staging
helm uninstall myapp-prod -n prod

# Удалить namespace
kubectl delete namespace dev staging prod

# Удалить кластер
gcloud container clusters delete k8s-homework-3-1 \
  --zone us-central1-a \
  --project upheld-rookery-471109-b0 \
  --quiet
```

## Важные моменты

### Requests vs Limits

- **Requests** - гарантированные ресурсы, используются для планирования размещения подов
- **Limits** - максимальные ресурсы, предотвращают превышение потребления

В нашем чарте:
- Requests = Limits для БД и кеша (стабильное потребление)
- Limits > Requests для frontend и backend (возможны всплески нагрузки)

### StatefulSet vs Deployment

**StatefulSet** используется для:
- База данных (PostgreSQL) - требует стабильной идентичности и постоянного хранилища
- Кеш (Redis) - требует постоянного хранилища для персистентности

**Deployment** используется для:
- Frontend (nginx) - stateless, можно легко масштабировать
- Backend - stateless API, можно горизонтально масштабировать

### Persistence

- **Production/Staging** - включен persistent storage для сохранения данных при перезапусках
- **Development** - выключен для быстрого создания/удаления окружения

## Выводы

1. **Правильный расчет ресурсов критичен** - недостаток приведет к падениям, избыток к переплате
2. **Служебные компоненты K8s занимают 5-10% ресурсов** - всегда нужно учитывать overhead
3. **Отказоустойчивость требует запаса** - минимум +1 нода для обработки отказов
4. **Helm упрощает управление окружениями** - один чарт для dev/staging/prod с разными параметрами
5. **Правильный выбор типа нод** - баланс между стоимостью и управляемостью

## Ссылки

- [Задание на GitHub](https://github.com/netology-code/kuber-homeworks/blob/main/3.1/3.1.md)
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
