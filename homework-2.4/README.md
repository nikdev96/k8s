# Домашнее задание 2.4 - Helm

Практика по упаковке приложений в Helm charts и развертыванию нескольких версий в разных окружениях.

## Что сделано

Создал Helm chart с двумя компонентами (frontend + backend) и развернул три версии:
- Версия 1.0 в namespace app1
- Версия 2.0 в namespace app1
- Версия 3.0 в namespace app2

## Структура Helm Chart

```
myapp/
├── Chart.yaml                  # метаданные чарта
├── values.yaml                 # параметры по умолчанию
├── values-v1.yaml             # параметры для версии 1.0
├── values-v2.yaml             # параметры для версии 2.0
├── values-v3.yaml             # параметры для версии 3.0
└── templates/
    ├── _helpers.tpl           # вспомогательные функции
    ├── frontend-deployment.yaml
    ├── frontend-service.yaml
    ├── backend-deployment.yaml
    └── backend-service.yaml
```

### Chart.yaml

```yaml
apiVersion: v2
name: myapp
description: Multi-component application for Helm homework
type: application
version: 0.1.0
appVersion: "1.0"
```

### Компоненты приложения

**Frontend:**
- nginx (разные версии: 1.25, 1.26, alpine)
- ClusterIP Service на порту 80

**Backend:**
- wbitt/network-multitool
- ClusterIP Service на порту 8080

## Развертывание

### 1. Создание кластера

```bash
gcloud container clusters create k8s-homework-2-4 \
  --zone us-central1-a \
  --num-nodes 2 \
  --machine-type e2-medium \
  --project upheld-rookery-471109-b0 \
  --service-account serviceforbot@upheld-rookery-471109-b0.iam.gserviceaccount.com
```

### 2. Создание namespace

```bash
kubectl create namespace app1
kubectl create namespace app2
```

### 3. Установка релизов

**Версия 1.0 в app1:**
```bash
helm install myapp-v1 ./myapp \
  --namespace app1 \
  --set appVersion="1.0" \
  --set frontend.image.tag="1.25" \
  --set replicaCount=1
```

**Версия 2.0 в app1:**
```bash
helm install myapp-v2 ./myapp \
  --namespace app1 \
  --set appVersion="2.0" \
  --set frontend.image.tag="1.26" \
  --set replicaCount=1
```

**Версия 3.0 в app2:**
```bash
helm install myapp-v3 ./myapp \
  --namespace app2 \
  --set appVersion="3.0" \
  --set frontend.image.tag="alpine" \
  --set replicaCount=1
```

## Проверка результатов

### Список Helm релизов

```bash
$ helm list --all-namespaces
NAME    	NAMESPACE	REVISION	UPDATED                             	STATUS  	CHART      	APP VERSION
myapp-v1	app1     	1       	2026-01-13 17:41:33.215466 +0700 +07	deployed	myapp-0.1.0	1.0
myapp-v2	app1     	1       	2026-01-13 17:41:53.35381 +0700 +07 	deployed	myapp-0.1.0	1.0
myapp-v3	app2     	2       	2026-01-13 17:43:11.477234 +0700 +07	deployed	myapp-0.1.0	1.0
```

### Ресурсы в namespace app1

```bash
$ kubectl get all -n app1
NAME                                     READY   STATUS    RESTARTS   AGE
pod/myapp-v1-backend-77fb644556-vn98p    1/1     Running   0          2m
pod/myapp-v1-frontend-6b7d4c8b9b-ljtmb   1/1     Running   0          2m
pod/myapp-v2-backend-7cb4dc67fd-7rxpb    1/1     Running   0          105s
pod/myapp-v2-frontend-767d8b84c7-v6lqc   1/1     Running   0          105s

NAME                        TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
service/myapp-v1-backend    ClusterIP   34.118.229.150   <none>        8080/TCP   2m
service/myapp-v1-frontend   ClusterIP   34.118.236.119   <none>        80/TCP     2m
service/myapp-v2-backend    ClusterIP   34.118.235.145   <none>        8080/TCP   106s
service/myapp-v2-frontend   ClusterIP   34.118.234.45    <none>        80/TCP     106s

NAME                                READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/myapp-v1-backend    1/1     1            1           2m
deployment.apps/myapp-v1-frontend   1/1     1            1           2m
deployment.apps/myapp-v2-backend    1/1     1            1           106s
deployment.apps/myapp-v2-frontend   1/1     1            1           106s
```

### Ресурсы в namespace app2

```bash
$ kubectl get all -n app2
NAME                                READY   STATUS    RESTARTS   AGE
pod/myapp-v3-backend-55fbcbf67b-sh5p9   1/1     Running   0          90s
pod/myapp-v3-frontend-998c67b97-ntp9r   1/1     Running   0          90s

NAME                        TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
service/myapp-v3-backend    ClusterIP   34.118.227.135   <none>        8080/TCP   91s
service/myapp-v3-frontend   ClusterIP   34.118.233.2     <none>        80/TCP     91s

NAME                                READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/myapp-v3-backend    1/1     1            1           91s
deployment.apps/myapp-v3-frontend   1/1     1            1           91s
```

### Версии приложений через labels

**Namespace app1:**
```bash
$ kubectl get pods -n app1 -L version
NAME                                 READY   STATUS    RESTARTS   AGE   VERSION
myapp-v1-backend-77fb644556-vn98p    1/1     Running   0          3m    1.0
myapp-v1-frontend-6b7d4c8b9b-ljtmb   1/1     Running   0          3m    1.0
myapp-v2-backend-7cb4dc67fd-7rxpb    1/1     Running   0          2m    2.0
myapp-v2-frontend-767d8b84c7-v6lqc   1/1     Running   0          2m    2.0
```

**Namespace app2:**
```bash
$ kubectl get pods -n app2 -L version
NAME                                READY   STATUS    RESTARTS   AGE   VERSION
myapp-v3-backend-55fbcbf67b-sh5p9   1/1     Running   0          2m    3.0
myapp-v3-frontend-998c67b97-ntp9r   1/1     Running   0          2m    3.0
```

## Альтернативный способ установки через values файлы

Вместо `--set` можно использовать готовые values файлы:

```bash
helm install myapp-v1 ./myapp -n app1 -f myapp/values-v1.yaml
helm install myapp-v2 ./myapp -n app1 -f myapp/values-v2.yaml
helm install myapp-v3 ./myapp -n app2 -f myapp/values-v3.yaml
```

## Дополнительные операции

### Обновление релиза

```bash
helm upgrade myapp-v3 ./myapp -n app2 --set replicaCount=1
```

### Просмотр истории

```bash
$ helm history myapp-v3 -n app2
REVISION	UPDATED                 	STATUS    	CHART      	APP VERSION	DESCRIPTION
1       	Tue Jan 13 17:42:08 2026	superseded	myapp-0.1.0	1.0        	Install complete
2       	Tue Jan 13 17:43:11 2026	deployed  	myapp-0.1.0	1.0        	Upgrade complete
```

### Экспорт манифестов

```bash
helm get manifest myapp-v1 -n app1 > app1-v1-manifests.yaml
helm get manifest myapp-v2 -n app1 > app1-v2-manifests.yaml
helm get manifest myapp-v3 -n app2 > app2-v3-manifests.yaml
```

## Проверка работы приложений

Через port-forward можно проверить работу каждой версии:

```bash
# Версия 1.0
kubectl port-forward -n app1 svc/myapp-v1-frontend 8081:80

# Версия 2.0
kubectl port-forward -n app1 svc/myapp-v2-frontend 8082:80

# Версия 3.0
kubectl port-forward -n app2 svc/myapp-v3-frontend 8083:80
```

## Удаление ресурсов

```bash
# Удалить релизы
helm uninstall myapp-v1 -n app1
helm uninstall myapp-v2 -n app1
helm uninstall myapp-v3 -n app2

# Удалить namespace
kubectl delete namespace app1 app2

# Удалить кластер
gcloud container clusters delete k8s-homework-2-4 \
  --zone us-central1-a \
  --project upheld-rookery-471109-b0 \
  --quiet
```

## Ключевые моменты

- **Helm chart** - шаблон для упаковки Kubernetes приложений
- **values.yaml** - параметры которые можно менять при установке
- **Версионирование** - через appVersion и image tags
- **Namespace** - изоляция релизов
- **Labels** - для идентификации версий приложения
- В одном namespace могут быть несколько релизов одного chart

## Ссылки

- [Задание на GitHub](https://github.com/netology-code/kuber-homeworks/blob/shkuber-16/2.4/2.4.md)
