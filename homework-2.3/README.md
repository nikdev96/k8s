# Домашнее задание 2.3 - Kubernetes ConfigMaps, Secrets, RBAC

## Описание
Практическое задание по управлению конфигурацией и безопасностью в Kubernetes.
Выполняется на GKE кластере в GCP.

## Задачи

### Задача 1: ConfigMaps - Практическое применение
**Цель:** Развернуть приложение с конфигурацией из ConfigMap.

**Требования:**
- Создать ConfigMap с HTML контентом
- Deployment с nginx и multitool
- nginx отображает HTML из ConfigMap
- Проверить доступность через curl

**Файлы манифестов:**
- `manifests/configmap-web.yaml`
- `manifests/deployment-task1.yaml`

### Задача 2: Secrets - HTTPS конфигурация с TLS
**Цель:** Настроить HTTPS доступ через Ingress с TLS сертификатом из Secret.

**Требования:**
- Сгенерировать self-signed сертификат через openssl
- Создать Secret типа tls
- Настроить Ingress для HTTPS
- Проверить через curl -k

**Файлы манифестов:**
- `manifests/secret-tls.yaml`
- `manifests/deployment-task2.yaml`
- `manifests/ingress-tls.yaml`

### Задача 3: RBAC - Управление доступом
**Цель:** Создать пользователя с ограниченными правами на просмотр pods.

**Требования:**
- Сгенерировать сертификат для пользователя developer
- Создать Role с правами на просмотр pods и логов
- Создать RoleBinding
- Проверить доступ через kubectl --as

**Файлы манифестов:**
- `manifests/role-pod-reader.yaml`
- `manifests/rolebinding-developer.yaml`

## Структура проекта

```
homework-2.3/
├── README.md                       # Этот файл
├── terraform/                      # Terraform конфигурации для GCP
│   ├── main.tf                     # Основная конфигурация
│   ├── variables.tf                # Переменные
│   ├── outputs.tf                  # Выходные данные
│   └── terraform.tfvars.example    # Пример переменных
└── manifests/                      # Kubernetes манифесты
    ├── configmap-web.yaml          # Задача 1: ConfigMap
    ├── deployment-task1.yaml        # Задача 1: Deployment с nginx + multitool
    ├── secret-tls.yaml              # Задача 2: TLS Secret
    ├── deployment-task2.yaml        # Задача 2: Deployment для HTTPS
    ├── ingress-tls.yaml             # Задача 2: Ingress с TLS
    ├── role-pod-reader.yaml        # Задача 3: Role
    └── rolebinding-developer.yaml  # Задача 3: RoleBinding
```

## Выполнение

### 1. Развертывание инфраструктуры
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Заполнить project_id
terraform init
terraform apply
```

### 2. Подключение к кластеру
```bash
gcloud container clusters get-credentials k8s-homework-2-3 --zone us-central1-a --project <project-id>
kubectl get nodes
```

### 3. Выполнение заданий

**Задача 1:**
```bash
kubectl apply -f manifests/configmap-web.yaml
kubectl apply -f manifests/deployment-task1.yaml
kubectl get svc web-app-service
curl http://<EXTERNAL-IP>
```

**Задача 2:**
```bash
# Сгенерировать сертификат
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=homework.example.com/O=netology"

# Применить манифесты
kubectl apply -f manifests/secret-tls.yaml
kubectl apply -f manifests/deployment-task2.yaml
kubectl apply -f manifests/ingress-tls.yaml

# Проверить HTTPS
INGRESS_IP=$(kubectl get ingress homework-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -k --resolve homework.example.com:443:$INGRESS_IP https://homework.example.com
```

**Задача 3: Генерация сертификата и проверка:**
```bash
# Создать ключ и CSR для пользователя developer
openssl genrsa -out developer.key 2048
openssl req -new -key developer.key -out developer.csr -subj "/CN=developer/O=netology"

# Создать CertificateSigningRequest в K8s
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: developer
spec:
  request: $(cat developer.csr | base64 | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF

# Approve и получить сертификат
kubectl certificate approve developer
kubectl get csr developer -o jsonpath='{.status.certificate}' | base64 -d > developer.crt

# Применить Role и RoleBinding
kubectl apply -f manifests/role-pod-reader.yaml
kubectl apply -f manifests/rolebinding-developer.yaml

# Проверить доступ
kubectl get pods --as=developer
kubectl get deployments --as=developer  # Должна быть ошибка
```

## Развертывание инфраструктуры

### 1. Настройка Terraform
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Заполните project_id в terraform.tfvars

terraform init
terraform apply
```

### 2. Подключение к кластеру
```bash
gcloud container clusters get-credentials k8s-homework-2-3 --zone us-central1-a --project <project-id>
kubectl get nodes
```

### 3. Применение манифестов
```bash
# Задача 1
kubectl apply -f manifests/configmap-web.yaml
kubectl apply -f manifests/deployment-task1.yaml

# Задача 2
kubectl apply -f manifests/secret-tls.yaml
kubectl apply -f manifests/deployment-task2.yaml
kubectl apply -f manifests/ingress-tls.yaml

# Задача 3
kubectl apply -f manifests/role-pod-reader.yaml
kubectl apply -f manifests/rolebinding-developer.yaml
```

## Результаты

### Задача 1: ConfigMaps
<!-- Результаты будут добавлены после выполнения -->

### Задача 2: Secrets + Ingress
<!-- Результаты будут добавлены после выполнения -->

### Задача 3: RBAC
<!-- Результаты будут добавлены после выполнения -->

## Ссылки
- [Оригинальное задание](https://github.com/netology-code/kuber-homeworks/blob/shkuber-16/2.3/2.3.md)
