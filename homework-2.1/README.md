# Домашнее задание 2.1 - Kubernetes Storage

## Описание
Практическое задание по работе с механизмами хранения данных в Kubernetes.
Выполняется на GCP с использованием Terraform.

## Задачи

### Задача 1: Volume - обмен данными между контейнерами
**Цель:** Создать Deployment с двумя контейнерами, обменивающимися данными через ephemeral volume.

**Требования:**
- Развернуть контейнеры busybox и multitool в одном поде
- Настроить busybox для записи данных каждые 5 секунд в общую директорию
- Multitool должен читать из этой же директории
- **Файл манифеста:** `manifests/containers-data-exchange.yaml`

### Задача 2: PersistentVolume и PersistentVolumeClaim
**Цель:** Реализовать постоянное хранилище с использованием вручную созданных PV ресурсов.

**Шаги:**
- Создать PV и PVC для доступа к локальной директории на ноде
- Развернуть два контейнера с использованием PVC
- Продемонстрировать сохранность данных
- Удалить Deployment/PVC и задокументировать поведение PV
- Удалить PV и проверить сохранность файлов на диске
- **Файл манифеста:** `manifests/pv-pvc.yaml`

### Задача 3: StorageClass
**Цель:** Автоматизировать создание PV через StorageClass.

**Требования:**
- Определить кастомный StorageClass с "kubernetes.io/no-provisioner"
- Создать PVC, ссылающийся на StorageClass
- Развернуть приложение с динамически созданным хранилищем
- Проверить функциональность обмена данными между контейнерами
- **Файл манифеста:** `manifests/sc.yaml`

## Структура проекта

```
homework-2.1/
├── README.md                          # Этот файл
├── terraform/                         # Terraform конфигурации для GCP
│   ├── main.tf                        # Основная конфигурация
│   ├── variables.tf                   # Переменные
│   └── outputs.tf                     # Выходные данные
└── manifests/                         # Kubernetes манифесты
    ├── containers-data-exchange.yaml  # Задача 1
    ├── pv-pvc.yaml                    # Задача 2
    └── sc.yaml                         # Задача 3
```

## Выполнение

### 1. Развертывание инфраструктуры
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 2. Подключение к кластеру
```bash
gcloud container clusters get-credentials <cluster-name> --region <region>
```

### 3. Применение манифестов
```bash
kubectl apply -f manifests/containers-data-exchange.yaml
kubectl apply -f manifests/pv-pvc.yaml
kubectl apply -f manifests/sc.yaml
```

## Результаты

### Задача 1
<!-- Скриншоты и описание -->

### Задача 2
<!-- Скриншоты и объяснение поведения PV -->

### Задача 3
<!-- Скриншоты реализации -->

## Ссылки
- [Оригинальное задание](https://github.com/netology-code/kuber-homeworks/blob/shkuber-16/2.1/2.1.md)
