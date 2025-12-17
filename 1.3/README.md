# 📦 Kubernetes 1.3 - Запуск приложений в K8S

В этой работе разбираемся с развертыванием приложений в Kubernetes: создаем Deployment с несколькими контейнерами, масштабируем их и работаем с init-контейнерами.

## 🌐 Инфраструктура

Для выполнения заданий используется GKE кластер в Google Cloud:
- 📍 **Регион**: us-central1-a
- 💻 **Тип узлов**: e2-small
- 🔢 **Количество узлов**: 1
- 🏷️ **Имя кластера**: netology-k8s-cluster

## 🎯 Задание 1: Deployment с несколькими контейнерами

### Что делаем
Создаем Deployment, в котором одновременно работают два контейнера - nginx и multitool. Затем масштабируем приложение до 2 экземпляров, создаем Service для доступа и проверяем, что все работает.

### 📝 Шаг 1: Создание Deployment

**Манифест:** [manifests/task1-deployment.yaml](manifests/task1-deployment.yaml)

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

> ⚠️ **Важная деталь**: По умолчанию и nginx, и multitool хотят использовать порт 80, что создаст конфликт. Поэтому для multitool настраиваем порт 8080 через переменные окружения `HTTP_PORT` и `HTTPS_PORT`.

**Запускаем:**
```bash
kubectl apply -f manifests/task1-deployment.yaml
```

**Смотрим, что получилось (пока 1 реплика):**
```bash
kubectl get deployments,pods -o wide
```

**Видим:**
```
NAME                              READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS        IMAGES                               SELECTOR
deployment.apps/nginx-multitool   1/1     1            1           49s   nginx,multitool   nginx:1.25,wbitt/network-multitool   app=nginx-multitool

NAME                                  READY   STATUS    RESTARTS   AGE   IP            NODE
pod/nginx-multitool-7d84c86c9-dqxm8   2/2     Running   0          49s   10.116.0.13   gke-netology-k8s-clu-netology-k8s-clu-3538bf26-8mp0
```

### 📈 Шаг 2: Масштабирование до 2 реплик

Теперь увеличим количество экземпляров приложения:

```bash
kubectl scale deployment nginx-multitool --replicas=2
```

**Проверяем, что теперь работает 2 pod'а:**
```bash
kubectl get deployments,pods -o wide
```

**Результат:**
```
NAME                              READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS        IMAGES                               SELECTOR
deployment.apps/nginx-multitool   2/2     2            2           96s   nginx,multitool   nginx:1.25,wbitt/network-multitool   app=nginx-multitool

NAME                                  READY   STATUS    RESTARTS   AGE   IP            NODE
pod/nginx-multitool-7d84c86c9-6xlw5   2/2     Running   0          26s   10.116.0.14   gke-netology-k8s-clu-netology-k8s-clu-3538bf26-8mp0
pod/nginx-multitool-7d84c86c9-dqxm8   2/2     Running   0          96s   10.116.0.13   gke-netology-k8s-clu-netology-k8s-clu-3538bf26-8mp0
```

### 🌐 Шаг 3: Создание Service

Чтобы можно было обращаться к нашим pod'ам по единому адресу, создаем Service:

**Манифест:** [manifests/task1-service.yaml](manifests/task1-service.yaml)

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

**Применяем:**
```bash
kubectl apply -f manifests/task1-service.yaml
```

**Проверяем:**
```bash
kubectl get svc nginx-multitool-svc
```

**Service создан:**
```
NAME                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)           AGE
nginx-multitool-svc   ClusterIP   34.118.236.137   <none>        80/TCP,8080/TCP   1s
```

### 🧪 Шаг 4: Проверка доступности

Создадим отдельный pod для тестирования:

**Манифест:** [manifests/task1-test-pod.yaml](manifests/task1-test-pod.yaml)

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

**Запускаем тестовый pod:**
```bash
kubectl apply -f manifests/task1-test-pod.yaml
```

**Проверяем nginx (порт 80):**
```bash
kubectl exec multitool-test -- curl -s nginx-multitool-svc:80
```

**Получаем:**
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

**Проверяем multitool (порт 8080):**
```bash
kubectl exec multitool-test -- curl -s nginx-multitool-svc:8080
```

**Получаем:**
```
WBITT Network MultiTool (with NGINX) - nginx-multitool-7d84c86c9-6xlw5 - 10.116.0.14 - HTTP: 8080 , HTTPS: 11443
```

> ✅ **Отлично!** Service успешно балансирует трафик между двумя репликами. Оба контейнера (nginx на порту 80 и multitool на порту 8080) доступны через единую точку входа.

## 🚀 Задание 2: Deployment с Init-контейнером

### Что делаем
Создаем интересный сценарий: nginx должен запуститься только после того, как появится Service. Для этого используем init-контейнер с busybox, который будет проверять доступность Service через DNS.

### 📝 Шаг 1: Создание Deployment с Init-контейнером

**Манифест:** [manifests/task2-deployment.yaml](manifests/task2-deployment.yaml)

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

**Применяем Deployment (но пока БЕЗ Service!):**
```bash
kubectl apply -f manifests/task2-deployment.yaml
```

### ⏳ Шаг 2: Смотрим, что pod "застрял"

**Проверяем статус:**
```bash
kubectl get pods -l app=nginx-with-init
```

**Видим:**
```
NAME                               READY   STATUS     RESTARTS   AGE
nginx-with-init-5b4d7bb88f-k89f9   0/1     Init:0/1   0          6s
```

> 🔍 Статус **Init:0/1** говорит нам, что init-контейнер работает, но не может завершиться. Основной nginx ждет!

**Смотрим логи init-контейнера:**
```bash
kubectl logs -l app=nginx-with-init -c wait-for-service
```

**В логах видим:**
```
waiting for service
Server:		34.118.224.10
Address:	34.118.224.10:53

** server can't find nginx-init-svc.default.svc.cluster.local: NXDOMAIN

** server can't find nginx-init-svc.default.svc.cluster.local: NXDOMAIN

waiting for service
```

> 💡 Init-контейнер в цикле пытается найти Service через DNS, но получает ошибку **NXDOMAIN** (домен не найден). Пока Service не появится, nginx не запустится!

### 🎯 Шаг 3: Создаем Service

**Манифест:** [manifests/task2-service.yaml](manifests/task2-service.yaml)

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

**Создаем Service:**
```bash
kubectl apply -f manifests/task2-service.yaml
```

### ✅ Шаг 4: Pod "ожил"!

**Проверяем статус:**
```bash
kubectl get pods -l app=nginx-with-init
```

**Теперь:**
```
NAME                               READY   STATUS    RESTARTS   AGE
nginx-with-init-5b4d7bb88f-k89f9   1/1     Running   0          34s
```

> 🎉 Статус изменился на **Running (1/1)**! Init-контейнер нашел Service, завершил работу, и nginx успешно запустился.

**Смотрим финальные логи init-контейнера:**
```bash
kubectl logs -l app=nginx-with-init -c wait-for-service --tail=10
```

**В логах:**
```
** server can't find nginx-init-svc.default.svc.cluster.local: NXDOMAIN

waiting for service
Server:		34.118.224.10
Address:	34.118.224.10:53


Name:	nginx-init-svc.default.svc.cluster.local
Address: 34.118.234.8
```

**Проверяем Service:**
```bash
kubectl get svc nginx-init-svc
```

**Service готов:**
```
NAME             TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
nginx-init-svc   ClusterIP   34.118.234.8   <none>        80/TCP    14s
```

> 🎯 **Что произошло:** DNS успешно разрешил имя `nginx-init-svc.default.svc.cluster.local` в ClusterIP (34.118.234.8). Init-контейнер увидел Service, завершил работу, и nginx смог запуститься!

---

## 🔄 Как воспроизвести все самому

### 1️⃣ Подключиться к GKE кластеру
```bash
gcloud container clusters get-credentials netology-k8s-cluster --zone us-central1-a --project original-future-476512-f0
```

### 2️⃣ Задание 1 - Пошагово
```bash
# 1. Создаем Deployment с 1 репликой
kubectl apply -f manifests/task1-deployment.yaml
kubectl get deployments,pods -o wide

# 2. Масштабируем до 2 реплик
kubectl scale deployment nginx-multitool --replicas=2
kubectl get deployments,pods -o wide

# 3. Создаем Service
kubectl apply -f manifests/task1-service.yaml

# 4. Запускаем тестовый pod
kubectl apply -f manifests/task1-test-pod.yaml

# 5. Тестируем nginx
kubectl exec multitool-test -- curl -s nginx-multitool-svc:80

# 6. Тестируем multitool
kubectl exec multitool-test -- curl -s nginx-multitool-svc:8080
```

### 3️⃣ Задание 2 - Пошагово
```bash
# 1. Создаем Deployment БЕЗ Service
kubectl apply -f manifests/task2-deployment.yaml

# 2. Смотрим, что pod в статусе Init:0/1
kubectl get pods -l app=nginx-with-init

# 3. Читаем логи - видим ошибки NXDOMAIN
kubectl logs -l app=nginx-with-init -c wait-for-service

# 4. Создаем Service
kubectl apply -f manifests/task2-service.yaml

# 5. Проверяем - теперь Running!
kubectl get pods -l app=nginx-with-init

# 6. Смотрим логи - Service найден
kubectl logs -l app=nginx-with-init -c wait-for-service --tail=10
```

---

## 🧹 Очистка ресурсов

Когда закончите эксперименты:

```bash
kubectl delete deployment nginx-multitool nginx-with-init
kubectl delete service nginx-multitool-svc nginx-init-svc
kubectl delete pod multitool-test
```

---

## 📁 Структура проекта

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

---

## ✅ Итоги

### Задание 1: Deployment с несколькими контейнерами
- 🐳 Создан Deployment с nginx и multitool в одном Pod'е
- ⚙️ Решен конфликт портов через переменные окружения
- 📊 Успешно масштабирован с 1 до 2 реплик
- 🌐 Создан Service для единой точки входа
- ✅ Оба контейнера доступны и отвечают на запросы

### Задание 2: Init-контейнеры
- 🚀 Создан Deployment с init-контейнером busybox
- ⏸️ Init-контейнер блокирует запуск nginx до появления Service
- 🔍 Проверка через DNS (nslookup) работает корректно
- ✅ После создания Service nginx запускается автоматически

**Все требования выполнены, работа сдана!** 🎉
