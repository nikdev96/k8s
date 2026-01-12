# Kubernetes 1.3 - Запуск приложений в K8S

Решение домашнего задания по развертыванию Deployment с несколькими контейнерами и масштабированием в Kubernetes на GKE.

## Инфраструктура

Использован существующий GKE кластер в Google Cloud Platform:
- **Регион**: us-central1-a
- **Тип узлов**: e2-small
- **Количество узлов**: 1
- **Имя кластера**: netology-k8s-cluster

## Задание 1: Deployment с несколькими контейнерами

### Описание
Создание Deployment с nginx и multitool контейнерами, масштабирование до 2 реплик, создание Service и проверка доступности.

### Шаг 1: Создание Deployment

Файл: [manifests/task1-deployment.yaml](manifests/task1-deployment.yaml)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-multitool
  labels:
    app: nginx-multitool
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-multitool
  template:
    metadata:
      labels:
        app: nginx-multitool
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
          name: http
      - name: multitool
        image: wbitt/network-multitool
        ports:
        - containerPort: 8080
          name: http-alt
        env:
        - name: HTTP_PORT
          value: "8080"
        - name: HTTPS_PORT
          value: "11443"
```

**Важно**: Для разрешения конфликта портов между nginx и multitool, необходимо настроить multitool на использование порта 8080 через переменные окружения `HTTP_PORT` и `HTTPS_PORT`.

Применение манифеста:
```bash
kubectl apply -f manifests/task1-deployment.yaml
```

Проверка состояния (до масштабирования):
```bash
kubectl get deployments,pods -o wide
```

Результат:
```
NAME                              READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS        IMAGES                               SELECTOR
deployment.apps/nginx-multitool   1/1     1            1           49s   nginx,multitool   nginx:1.25,wbitt/network-multitool   app=nginx-multitool

NAME                                  READY   STATUS    RESTARTS   AGE   IP            NODE
pod/nginx-multitool-7d84c86c9-dqxm8   2/2     Running   0          49s   10.116.0.13   gke-netology-k8s-clu-netology-k8s-clu-3538bf26-8mp0
```

### Шаг 2: Масштабирование до 2 реплик

```bash
kubectl scale deployment nginx-multitool --replicas=2
```

Проверка состояния (после масштабирования):
```bash
kubectl get deployments,pods -o wide
```

Результат:
```
NAME                              READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS        IMAGES                               SELECTOR
deployment.apps/nginx-multitool   2/2     2            2           96s   nginx,multitool   nginx:1.25,wbitt/network-multitool   app=nginx-multitool

NAME                                  READY   STATUS    RESTARTS   AGE   IP            NODE
pod/nginx-multitool-7d84c86c9-6xlw5   2/2     Running   0          26s   10.116.0.14   gke-netology-k8s-clu-netology-k8s-clu-3538bf26-8mp0
pod/nginx-multitool-7d84c86c9-dqxm8   2/2     Running   0          96s   10.116.0.13   gke-netology-k8s-clu-netology-k8s-clu-3538bf26-8mp0
```

### Шаг 3: Создание Service

Файл: [manifests/task1-service.yaml](manifests/task1-service.yaml)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-multitool-svc
spec:
  selector:
    app: nginx-multitool
  ports:
  - name: nginx
    protocol: TCP
    port: 80
    targetPort: 80
  - name: multitool
    protocol: TCP
    port: 8080
    targetPort: 8080
  type: ClusterIP
```

Применение манифеста:
```bash
kubectl apply -f manifests/task1-service.yaml
```

Проверка Service:
```bash
kubectl get svc nginx-multitool-svc
```

Результат:
```
NAME                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)           AGE
nginx-multitool-svc   ClusterIP   34.118.236.137   <none>        80/TCP,8080/TCP   1s
```

### Шаг 4: Проверка доступности через отдельный Pod

Файл: [manifests/task1-test-pod.yaml](manifests/task1-test-pod.yaml)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multitool-test
  labels:
    app: multitool-test
spec:
  containers:
  - name: multitool
    image: wbitt/network-multitool
    command: ["/bin/sh", "-c", "sleep 3600"]
```

Применение манифеста:
```bash
kubectl apply -f manifests/task1-test-pod.yaml
```

Тестирование доступности nginx (порт 80):
```bash
kubectl exec multitool-test -- curl -s nginx-multitool-svc:80
```

Результат:
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

Тестирование доступности multitool (порт 8080):
```bash
kubectl exec multitool-test -- curl -s nginx-multitool-svc:8080
```

Результат:
```
WBITT Network MultiTool (with NGINX) - nginx-multitool-7d84c86c9-6xlw5 - 10.116.0.14 - HTTP: 8080 , HTTPS: 11443
```

**Результат**: Service успешно балансирует трафик между 2 репликами Deployment. Оба контейнера доступны через соответствующие порты.

## Задание 2: Deployment с Init-контейнером

### Описание
Создание Deployment с nginx, который запускается только после появления Service. Init-контейнер использует busybox для проверки доступности Service через nslookup.

### Шаг 1: Создание Deployment с Init-контейнером

Файл: [manifests/task2-deployment.yaml](manifests/task2-deployment.yaml)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-with-init
  labels:
    app: nginx-with-init
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-with-init
  template:
    metadata:
      labels:
        app: nginx-with-init
    spec:
      initContainers:
      - name: wait-for-service
        image: busybox:1.36
        command: ['sh', '-c', 'until nslookup nginx-init-svc.default.svc.cluster.local; do echo waiting for service; sleep 2; done']
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
```

Применение манифеста (БЕЗ Service):
```bash
kubectl apply -f manifests/task2-deployment.yaml
```

### Шаг 2: Проверка статуса Pod без Service

Проверка статуса:
```bash
kubectl get pods -l app=nginx-with-init
```

Результат:
```
NAME                               READY   STATUS     RESTARTS   AGE
nginx-with-init-5b4d7bb88f-k89f9   0/1     Init:0/1   0          6s
```

Статус **Init:0/1** означает, что init-контейнер запущен, но не завершил свою работу.

Проверка логов init-контейнера:
```bash
kubectl logs -l app=nginx-with-init -c wait-for-service
```

Результат:
```
waiting for service
Server:		34.118.224.10
Address:	34.118.224.10:53

** server can't find nginx-init-svc.default.svc.cluster.local: NXDOMAIN

** server can't find nginx-init-svc.default.svc.cluster.local: NXDOMAIN

waiting for service
```

**Вывод**: Init-контейнер циклически пытается найти Service через DNS, но получает ошибку NXDOMAIN (домен не найден). Основной контейнер nginx остается в состоянии ожидания.

### Шаг 3: Создание Service

Файл: [manifests/task2-service.yaml](manifests/task2-service.yaml)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-init-svc
spec:
  selector:
    app: nginx-with-init
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
```

Применение манифеста:
```bash
kubectl apply -f manifests/task2-service.yaml
```

### Шаг 4: Проверка статуса Pod после создания Service

Проверка статуса:
```bash
kubectl get pods -l app=nginx-with-init
```

Результат:
```
NAME                               READY   STATUS    RESTARTS   AGE
nginx-with-init-5b4d7bb88f-k89f9   1/1     Running   0          34s
```

Статус изменился на **Running (1/1)** - init-контейнер успешно завершился, nginx запустился.

Проверка финальных логов init-контейнера:
```bash
kubectl logs -l app=nginx-with-init -c wait-for-service --tail=10
```

Результат:
```
** server can't find nginx-init-svc.default.svc.cluster.local: NXDOMAIN

waiting for service
Server:		34.118.224.10
Address:	34.118.224.10:53


Name:	nginx-init-svc.default.svc.cluster.local
Address: 34.118.234.8
```

Проверка Service:
```bash
kubectl get svc nginx-init-svc
```

Результат:
```
NAME             TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
nginx-init-svc   ClusterIP   34.118.234.8   <none>        80/TCP    14s
```

**Вывод**: После создания Service, DNS успешно разрешил имя `nginx-init-svc.default.svc.cluster.local` в ClusterIP (34.118.234.8). Init-контейнер завершил работу, и nginx запустился.

## Как воспроизвести

### 1. Настроить kubectl для GKE кластера
```bash
gcloud container clusters get-credentials netology-k8s-cluster --zone us-central1-a --project original-future-476512-f0
```

### 2. Выполнить Задание 1
```bash
# Применить Deployment
kubectl apply -f manifests/task1-deployment.yaml

# Проверить состояние (1 реплика)
kubectl get deployments,pods -o wide

# Масштабировать до 2 реплик
kubectl scale deployment nginx-multitool --replicas=2

# Проверить состояние (2 реплики)
kubectl get deployments,pods -o wide

# Применить Service
kubectl apply -f manifests/task1-service.yaml

# Применить тестовый Pod
kubectl apply -f manifests/task1-test-pod.yaml

# Протестировать nginx
kubectl exec multitool-test -- curl -s nginx-multitool-svc:80

# Протестировать multitool
kubectl exec multitool-test -- curl -s nginx-multitool-svc:8080
```

### 3. Выполнить Задание 2
```bash
# Применить Deployment (БЕЗ Service)
kubectl apply -f manifests/task2-deployment.yaml

# Проверить статус - должен быть Init:0/1
kubectl get pods -l app=nginx-with-init

# Проверить логи init-контейнера
kubectl logs -l app=nginx-with-init -c wait-for-service

# Применить Service
kubectl apply -f manifests/task2-service.yaml

# Проверить статус - должен быть Running
kubectl get pods -l app=nginx-with-init

# Проверить финальные логи init-контейнера
kubectl logs -l app=nginx-with-init -c wait-for-service --tail=10
```

## Очистка ресурсов

```bash
# Удалить все созданные ресурсы
kubectl delete deployment nginx-multitool nginx-with-init
kubectl delete service nginx-multitool-svc nginx-init-svc
kubectl delete pod multitool-test
```

## Структура проекта

```
1.3/
├── README.md
└── manifests/
    ├── task1-deployment.yaml    # Deployment с nginx и multitool
    ├── task1-service.yaml       # Service для Deployment
    ├── task1-test-pod.yaml      # Тестовый Pod
    ├── task2-deployment.yaml    # Deployment с init-контейнером
    └── task2-service.yaml       # Service для init-контейнера
```

## Результаты выполнения

Все задания выполнены:

### Задание 1
- ✅ Создан Deployment с nginx и multitool контейнерами
- ✅ Разрешен конфликт портов через настройку переменных окружения multitool
- ✅ Deployment масштабирован с 1 до 2 реплик
- ✅ Создан Service для доступа к репликам
- ✅ Проверена доступность обоих контейнеров через Service из отдельного Pod

### Задание 2
- ✅ Создан Deployment с init-контейнером на базе busybox
- ✅ Продемонстрировано, что без Service init-контейнер блокирует запуск nginx
- ✅ Продемонстрировано, что после создания Service init-контейнер завершается и nginx запускается
- ✅ Init-контейнер использует nslookup для проверки доступности Service через DNS
