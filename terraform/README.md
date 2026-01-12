# Kubernetes - Домашние задания

Репозиторий с решениями домашних заданий по курсу Kubernetes.

## Инфраструктура

Все задания выполняются на GKE кластере в Google Cloud Platform, развернутом через Terraform:
- **Регион**: us-central1-a
- **Тип узлов**: e2-small
- **Количество узлов**: 1
- **Имя кластера**: netology-k8s-cluster

## Развертывание инфраструктуры

```bash
# Инициализация Terraform
terraform init

# Создание кластера
terraform apply

# Настройка kubectl
gcloud container clusters get-credentials netology-k8s-cluster --zone us-central1-a --project <PROJECT_ID>
```

## Выполненные задания

### [1.2 - Базовые объекты K8S](1.2/)
Работа с Pod и Service:
- Создание Pod с echoserver
- Создание Service для доступа к Pod
- Проверка работы через port-forward

### [1.3 - Запуск приложений в K8S](1.3/)
Развертывание приложений с несколькими контейнерами:
- Deployment с nginx и multitool контейнерами
- Масштабирование приложения
- Работа с init-контейнерами
- Создание Service для балансировки трафика

### [1.4 - Сетевое взаимодействие в Kubernetes](1.4/)
Настройка сетевого доступа к приложениям:
- Настройка ClusterIP Service для внутреннего доступа
- Настройка NodePort Service для внешнего доступа
- Развертывание и настройка Ingress контроллера
- Маршрутизация трафика через Ingress по путям

## Структура проекта

```
.
├── README.md              # Этот файл
├── main.tf                # Terraform конфигурация GKE
├── variables.tf           # Переменные Terraform
├── outputs.tf             # Выходные значения
├── terraform.tfvars       # Значения переменных (не в git)
├── 1.2/                   # Домашнее задание 1.2
│   ├── README.md
│   └── manifests/
├── 1.3/                   # Домашнее задание 1.3
│   ├── README.md
│   └── manifests/
└── 1.4/                   # Домашнее задание 1.4
    ├── README.md
    └── manifests/
```

## Очистка ресурсов

```bash
# Удалить GKE кластер
terraform destroy
```
