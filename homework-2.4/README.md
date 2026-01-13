# Домашнее задание 2.4 - Helm

Задание про упаковку приложений в Helm charts. Нужно было создать chart и развернуть несколько версий приложения в разных окружениях.

## Что делал

Создал простое приложение из двух частей - frontend (nginx) и backend (multitool). Запаковал его в Helm chart и развернул три версии:
- **Версия 1.0** - в namespace app1 (nginx 1.25)
- **Версия 2.0** - тоже в app1 (nginx 1.26)
- **Версия 3.0** - в namespace app2 (nginx alpine)

Идея в том что Helm позволяет один раз написать шаблоны, а потом разворачивать их с разными параметрами. Удобно для разных окружений (dev, staging, prod).

## Структура проекта

```
myapp/
├── Chart.yaml              # описание чарта (название, версия)
├── values.yaml             # дефолтные значения переменных
├── values-v1.yaml          # параметры для версии 1.0
├── values-v2.yaml          # параметры для версии 2.0
├── values-v3.yaml          # параметры для версии 3.0
└── templates/
    ├── _helpers.tpl        # вспомогательные функции
    ├── frontend-deployment.yaml
    ├── frontend-service.yaml
    ├── backend-deployment.yaml
    └── backend-service.yaml
```

## Компоненты

**Frontend:**
- nginx на порту 80
- Меняется версия образа (1.25, 1.26, alpine)

**Backend:**
- multitool на порту 8080
- Просто для демонстрации что в чарте несколько компонентов

## Как развертывал

### Подготовка

Создал GKE кластер на 2 ноды:
```bash
gcloud container clusters create k8s-homework-2-4 \
  --zone us-central1-a \
  --num-nodes 2 \
  --machine-type e2-medium \
  --project upheld-rookery-471109-b0 \
  --service-account serviceforbot@upheld-rookery-471109-b0.iam.gserviceaccount.com
```

Создал namespace для изоляции версий:
```bash
kubectl create namespace app1
kubectl create namespace app2
```

### Установка версий

Сначала версия 1.0 в app1:
```bash
helm install myapp-v1 ./myapp \
  --namespace app1 \
  --set appVersion="1.0" \
  --set frontend.image.tag="1.25" \
  --set replicaCount=1
```

Потом версия 2.0 туда же (в app1):
```bash
helm install myapp-v2 ./myapp \
  --namespace app1 \
  --set appVersion="2.0" \
  --set frontend.image.tag="1.26" \
  --set replicaCount=1
```

И версия 3.0 в app2:
```bash
helm install myapp-v3 ./myapp \
  --namespace app2 \
  --set appVersion="3.0" \
  --set frontend.image.tag="alpine" \
  --set replicaCount=1
```

## Проверка что все работает

Смотрю список всех релизов:
```bash
$ helm list --all-namespaces
NAME    	NAMESPACE	REVISION	UPDATED                             	STATUS  	CHART      	APP VERSION
myapp-v1	app1     	1       	2026-01-13 17:41:33.215466 +0700 +07	deployed	myapp-0.1.0	1.0
myapp-v2	app1     	1       	2026-01-13 17:41:53.35381 +0700 +07 	deployed	myapp-0.1.0	1.0
myapp-v3	app2     	2       	2026-01-13 17:43:11.477234 +0700 +07	deployed	myapp-0.1.0	1.0
```

Три релиза развернуты: два в app1, один в app2.

### Ресурсы в app1

Тут две версии - v1 и v2:
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

Все поды в статусе Running. У каждого релиза свои Deployment и Service.

### Ресурсы в app2

А тут третья версия:
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

### Проверка версий через labels

Добавил в шаблоны label "version" чтобы видеть какая версия где работает.

**В namespace app1:**
```bash
$ kubectl get pods -n app1 -L version
NAME                                 READY   STATUS    RESTARTS   AGE   VERSION
myapp-v1-backend-77fb644556-vn98p    1/1     Running   0          3m    1.0
myapp-v1-frontend-6b7d4c8b9b-ljtmb   1/1     Running   0          3m    1.0
myapp-v2-backend-7cb4dc67fd-7rxpb    1/1     Running   0          2m    2.0
myapp-v2-frontend-767d8b84c7-v6lqc   1/1     Running   0          2m    2.0
```

Видно что в одном namespace работают версии 1.0 и 2.0 одновременно.

**В namespace app2:**
```bash
$ kubectl get pods -n app2 -L version
NAME                                READY   STATUS    RESTARTS   AGE   VERSION
myapp-v3-backend-55fbcbf67b-sh5p9   1/1     Running   0          2m    3.0
myapp-v3-frontend-998c67b97-ntp9r   1/1     Running   0          2m    3.0
```

Тут версия 3.0.

## Что понял про Helm

**Плюсы:**
- Можно переиспользовать один чарт для разных окружений
- Меняешь параметры через --set или values файлы
- Helm следит за версиями релизов (можно откатиться)
- В одном namespace могут жить несколько версий приложения

**Как это работает:**
1. Пишешь шаблоны с переменными типа `{{ .Values.frontend.image.tag }}`
2. При установке Helm подставляет значения из values.yaml
3. Можно переопределить через --set или свой values файл
4. Helm генерирует итоговые манифесты и применяет их

**Альтернативный способ установки:**

Вместо --set можно создать файлы с параметрами и передавать их через -f:
```bash
helm install myapp-v1 ./myapp -n app1 -f myapp/values-v1.yaml
helm install myapp-v2 ./myapp -n app1 -f myapp/values-v2.yaml
helm install myapp-v3 ./myapp -n app2 -f myapp/values-v3.yaml
```

Так удобнее когда параметров много.

## Дополнительно

### Обновление релиза

Если нужно изменить что-то в работающем релизе:
```bash
helm upgrade myapp-v3 ./myapp -n app2 --set replicaCount=1
```

Helm создаст новую ревизию.

### История изменений

Можно посмотреть что менялось:
```bash
$ helm history myapp-v3 -n app2
REVISION	UPDATED                 	STATUS    	CHART      	APP VERSION	DESCRIPTION
1       	Tue Jan 13 17:42:08 2026	superseded	myapp-0.1.0	1.0        	Install complete
2       	Tue Jan 13 17:43:11 2026	deployed  	myapp-0.1.0	1.0        	Upgrade complete
```

У меня было 2 ревизии потому что сначала поставил с replicaCount=2, а потом апгрейднул до 1 (не хватало ресурсов на кластере).

### Если нужны итоговые манифесты

Можно экспортировать что Helm реально применил:
```bash
helm get manifest myapp-v1 -n app1 > app1-v1-manifests.yaml
```

## Удаление

Удалил все чтобы не тратить деньги на GCP:
```bash
# Релизы
helm uninstall myapp-v1 -n app1
helm uninstall myapp-v2 -n app1
helm uninstall myapp-v3 -n app2

# Namespace
kubectl delete namespace app1 app2

# Кластер
gcloud container clusters delete k8s-homework-2-4 \
  --zone us-central1-a \
  --project upheld-rookery-471109-b0 \
  --quiet
```

## Выводы

Helm полезен когда нужно:
- Разворачивать одно приложение в разных окружениях
- Управлять версиями (rollback если что-то сломалось)
- Переиспользовать конфигурации

Основная идея - разделить шаблоны (которые не меняются) и параметры (которые меняются). Шаблоны пишешь один раз, а параметры подставляешь разные.

## Ссылки

[Задание на GitHub](https://github.com/netology-code/kuber-homeworks/blob/shkuber-16/2.4/2.4.md)
