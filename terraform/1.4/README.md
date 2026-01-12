# Домашнее задание 1.4: Сетевое взаимодействие в Kubernetes

## Описание

Выполнение домашнего задания по теме "Сетевое взаимодействие в Kubernetes" на GKE кластере, развернутом через Terraform.

## Инфраструктура

- **Облачный провайдер**: Google Cloud Platform (GCP)
- **Регион**: us-central1
- **Зона**: us-central1-a
- **Кластер**: GKE (Google Kubernetes Engine)
- **Инструмент развертывания**: Terraform
- **Количество нод**: 1
- **Тип машины**: e2-small

## Развертывание инфраструктуры

```bash
cd terraform
terraform init
terraform apply -auto-approve
```

Подключение к кластеру:
```bash
gcloud container clusters get-credentials netology-k8s-cluster --zone us-central1-a --project original-future-476512-f0
```

## Задание 1: Настройка Service (ClusterIP и NodePort)

### Манифесты

1. **deployment-multi-container.yaml** - Deployment с двумя контейнерами (nginx:80, multitool:8080), 3 реплики
2. **service-clusterip.yaml** - Service типа ClusterIP с портами 9001 (nginx) и 9002 (multitool)
3. **service-nodeport.yaml** - Service типа NodePort для доступа к nginx снаружи (порт 30080)

### Применение манифестов

```bash
kubectl apply -f terraform/1.4/manifests/deployment-multi-container.yaml
kubectl apply -f terraform/1.4/manifests/service-clusterip.yaml
kubectl apply -f terraform/1.4/manifests/service-nodeport.yaml
```

### Проверка работы

#### Проверка статуса ресурсов

```bash
kubectl get deployments,pods,services
```

Результат:
```
NAME                                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/multi-container-deployment   3/3     3            3           29m

NAME                                              READY   STATUS    RESTARTS   AGE
pod/multi-container-deployment-75887d4486-5l4m8   2/2     Running   0          29m
pod/multi-container-deployment-75887d4486-7c9cb   2/2     Running   0          29m
pod/multi-container-deployment-75887d4486-t2lc2   2/2     Running   0          29m

NAME                                TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)             AGE
service/multi-container-clusterip   ClusterIP   34.118.232.101   <none>        9001/TCP,9002/TCP   29m
service/multi-container-nodeport    NodePort    34.118.238.1     <none>        80:30080/TCP        29m
```

#### Тестирование ClusterIP (доступ изнутри кластера)

```bash
kubectl run test-pod --image=curlimages/curl:latest --rm -it --restart=Never -- sh -c \
  "curl -s http://multi-container-clusterip:9001 | head -5 && echo '---' && \
   curl -s http://multi-container-clusterip:9002"
```

Результат:
```
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
---
WBITT Network MultiTool (with NGINX) - multi-container-deployment-75887d4486-t2lc2 - 10.56.0.14 - HTTP: 8080 , HTTPS: 443
```

**Вывод**: ClusterIP Service работает корректно, nginx доступен на порту 9001, multitool на порту 9002.

#### Тестирование NodePort (доступ снаружи кластера)

Получение внешнего IP ноды:
```bash
kubectl get nodes -o wide
```

Результат:
```
NAME                                                  STATUS   ROLES    AGE   EXTERNAL-IP
gke-netology-k8s-clu-netology-k8s-clu-71939b77-vn7f   Ready    <none>   9m    34.122.117.194
```

Настройка firewall правила:
```bash
gcloud compute firewall-rules create allow-nodeport \
  --allow tcp:30080 \
  --source-ranges 0.0.0.0/0 \
  --target-tags k8s-training \
  --project original-future-476512-f0
```

Тестирование доступа:
```bash
curl http://34.122.117.194:30080
```

Результат:
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

**Вывод**: NodePort Service работает корректно, nginx доступен на порту 30080 с внешнего адреса.

---

## Задание 2: Настройка Ingress

### Манифесты

1. **deployment-frontend.yaml** - Deployment для frontend (nginx), 2 реплики
2. **deployment-backend.yaml** - Deployment для backend (multitool), 2 реплики
3. **service-frontend.yaml** - ClusterIP Service для frontend
4. **service-backend.yaml** - ClusterIP Service для backend
5. **ingress.yaml** - Ingress с маршрутизацией: `/` → frontend, `/api` → backend

### Установка Ingress контроллера

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
```

Ожидание готовности контроллера:
```bash
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

### Применение манифестов

```bash
kubectl apply -f terraform/1.4/manifests/deployment-frontend.yaml
kubectl apply -f terraform/1.4/manifests/deployment-backend.yaml
kubectl apply -f terraform/1.4/manifests/service-frontend.yaml
kubectl apply -f terraform/1.4/manifests/service-backend.yaml
kubectl apply -f terraform/1.4/manifests/ingress.yaml
```

### Проверка работы

#### Проверка статуса ресурсов

```bash
kubectl get deployments,services,ingress
```

Результат:
```
NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/backend   2/2     2            2           18m
deployment.apps/frontend  2/2     2            2           18m

NAME               TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
service/backend    ClusterIP   34.118.230.142   <none>        80/TCP    18m
service/frontend   ClusterIP   34.118.233.83    <none>        80/TCP    18m

NAME                                CLASS   HOSTS   ADDRESS         PORTS   AGE
ingress.networking.k8s.io/app-ingress   nginx   *       34.60.217.244   80      104s
```

#### Получение внешнего IP Ingress

```bash
kubectl get ingress
```

Результат:
```
NAME          CLASS   HOSTS   ADDRESS         PORTS   AGE
app-ingress   nginx   *       34.60.217.244   80      104s
```

**Внешний адрес Ingress**: 34.60.217.244

#### Тестирование маршрутизации

**Тест 1: Frontend (путь `/`)**
```bash
curl http://34.60.217.244/
```

Результат:
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

**Тест 2: Backend (путь `/api`)**
```bash
curl http://34.60.217.244/api
```

Результат:
```
WBITT Network MultiTool (with NGINX) - backend-7c657cfcbc-58r7q - 10.56.0.20 - HTTP: 8080 , HTTPS: 443
```

**Вывод**: Ingress работает корректно:
- Запросы на `/` направляются на frontend (nginx)
- Запросы на `/api` направляются на backend (multitool)

---

## Итоговое состояние кластера

```bash
kubectl get all,ingress
```

Результат:
```
NAME                                              READY   STATUS    RESTARTS   AGE
pod/backend-7c657cfcbc-58r7q                      1/1     Running   0          18m
pod/backend-7c657cfcbc-dg4xx                      1/1     Running   0          18m
pod/frontend-777d6745c9-45kvr                     1/1     Running   0          18m
pod/frontend-777d6745c9-bklhv                     1/1     Running   0          18m
pod/multi-container-deployment-75887d4486-5l4m8   2/2     Running   0          29m
pod/multi-container-deployment-75887d4486-7c9cb   2/2     Running   0          29m
pod/multi-container-deployment-75887d4486-t2lc2   2/2     Running   0          29m

NAME                                TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)             AGE
service/backend                     ClusterIP   34.118.230.142   <none>        80/TCP              18m
service/frontend                    ClusterIP   34.118.233.83    <none>        80/TCP              18m
service/kubernetes                  ClusterIP   34.118.224.1     <none>        443/TCP             36m
service/multi-container-clusterip   ClusterIP   34.118.232.101   <none>        9001/TCP,9002/TCP   29m
service/multi-container-nodeport    NodePort    34.118.238.1     <none>        80:30080/TCP        29m

NAME                                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/backend                      2/2     2            2           18m
deployment.apps/frontend                     2/2     2            2           18m
deployment.apps/multi-container-deployment   3/3     3            3           29m

NAME                                                    DESIRED   CURRENT   READY   AGE
replicaset.apps/backend-7c657cfcbc                      2         2         2       18m
replicaset.apps/frontend-777d6745c9                     2         2         2       18m
replicaset.apps/multi-container-deployment-75887d4486   3         3         3       29m

NAME                                    CLASS   HOSTS   ADDRESS         PORTS   AGE
ingress.networking.k8s.io/app-ingress   nginx   *       34.60.217.244   80      104s
```

## Выводы

1. **Задание 1** выполнено полностью:
   - Развернут Deployment с мультиконтейнерными подами (nginx + multitool)
   - Настроен ClusterIP Service для внутреннего доступа
   - Настроен NodePort Service для внешнего доступа
   - Доступ протестирован и подтвержден

2. **Задание 2** выполнено полностью:
   - Развернуты отдельные Deployment для frontend и backend
   - Настроены ClusterIP Services для каждого приложения
   - Установлен и настроен Ingress контроллер (nginx)
   - Настроена маршрутизация через Ingress
   - Доступ к приложениям через Ingress протестирован и подтвержден

3. **Инфраструктура** развернута на GKE через Terraform, что обеспечивает:
   - Воспроизводимость окружения
   - Версионирование инфраструктуры
   - Простое управление жизненным циклом кластера

## Очистка ресурсов

Для удаления всех созданных ресурсов:

```bash
# Удаление Kubernetes ресурсов
kubectl delete -f terraform/1.4/manifests/

# Удаление Ingress контроллера
kubectl delete namespace ingress-nginx

# Удаление firewall правила
gcloud compute firewall-rules delete allow-nodeport --project original-future-476512-f0

# Удаление GKE кластера
cd terraform
terraform destroy -auto-approve
```
