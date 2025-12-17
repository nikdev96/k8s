# Kubernetes 1.2 - Базовые объекты K8S

Решение домашнего задания по развертыванию Pod и Service в Kubernetes на GKE.

## Инфраструктура

Развернут GKE кластер в Google Cloud Platform через Terraform:
- **Регион**: us-central1-a
- **Тип узлов**: e2-small
- **Количество узлов**: 1

## Задание 1: Pod "hello-world"

### Манифест
Файл: [manifests/hello-world-pod.yaml](manifests/hello-world-pod.yaml)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hello-world
  labels:
    app: hello-world
spec:
  containers:
  - name: echoserver
    image: gcr.io/kubernetes-e2e-test-images/echoserver:2.2
    ports:
    - containerPort: 8080
```

### Проверка работы

```bash
# Применение манифеста
kubectl apply -f manifests/hello-world-pod.yaml

# Статус Pod
kubectl get pods
NAME          READY   STATUS    RESTARTS   AGE
hello-world   1/1     Running   0          4m58s

# Подключение через port-forward
kubectl port-forward pod/hello-world 8080:8080

# Тестирование
curl http://localhost:8080
```

**Результат**: Pod успешно запущен, echoserver отвечает на запросы.

## Задание 2: Pod "netology-web" и Service "netology-svc"

### Манифесты

**Pod**: [manifests/netology-web-pod.yaml](manifests/netology-web-pod.yaml)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: netology-web
  labels:
    app: netology-web
spec:
  containers:
  - name: echoserver
    image: gcr.io/kubernetes-e2e-test-images/echoserver:2.2
    ports:
    - containerPort: 8080
```

**Service**: [manifests/netology-svc-service.yaml](manifests/netology-svc-service.yaml)
```yaml
apiVersion: v1
kind: Service
metadata:
  name: netology-svc
spec:
  selector:
    app: netology-web
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
  type: ClusterIP
```

### Проверка работы

```bash
# Применение манифестов
kubectl apply -f manifests/netology-web-pod.yaml
kubectl apply -f manifests/netology-svc-service.yaml

# Статус ресурсов
kubectl get pods,svc
NAME               READY   STATUS    RESTARTS   AGE
pod/netology-web   1/1     Running   0          113s

NAME                   TYPE        CLUSTER-IP       PORT(S)   AGE
service/netology-svc   ClusterIP   34.118.227.210   80/TCP    111s

# Подключение через port-forward к Service
kubectl port-forward service/netology-svc 8081:80

# Тестирование
curl http://localhost:8081
```

**Результат**: Service успешно направляет трафик на Pod netology-web.

## Как воспроизвести

### 1. Развернуть GKE кластер
```bash
cd terraform
terraform init
terraform apply
```

### 2. Настроить kubectl
```bash
gcloud container clusters get-credentials netology-k8s-cluster --zone us-central1-a
```

### 3. Применить манифесты
```bash
kubectl apply -f manifests/hello-world-pod.yaml
kubectl apply -f manifests/netology-web-pod.yaml
kubectl apply -f manifests/netology-svc-service.yaml
```

### 4. Проверить статус
```bash
kubectl get pods -o wide
kubectl get svc
```

## Очистка ресурсов

```bash
# Удалить Kubernetes ресурсы
kubectl delete pod hello-world netology-web
kubectl delete service netology-svc

# Удалить GKE кластер
terraform destroy
```

## Структура проекта

```
.
├── README.md
├── main.tf              # Terraform конфигурация GKE
├── variables.tf         # Переменные Terraform
├── outputs.tf           # Выходные значения Terraform
├── terraform.tfvars     # Значения переменных
└── manifests/
    ├── hello-world-pod.yaml        # Задание 1
    ├── netology-web-pod.yaml       # Задание 2
    └── netology-svc-service.yaml   # Задание 2
```

## Результаты выполнения

Все задания выполнены:
- ✅ Создан Pod "hello-world"
- ✅ Подключение к Pod через port-forward работает
- ✅ Создан Pod "netology-web"
- ✅ Создан Service "netology-svc"
- ✅ Service правильно маршрутизирует трафик на Pod
