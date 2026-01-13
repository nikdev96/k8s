# Домашнее задание 2.3 - ConfigMaps, Secrets и RBAC

Практика по работе с конфигурацией и безопасностью в Kubernetes. Делал на GKE кластере в GCP.

## Что нужно было сделать

Три задачи:
1. **ConfigMaps** - вынести конфигурацию приложения в отдельный ресурс
2. **Secrets + Ingress** - настроить HTTPS с TLS сертификатом
3. **RBAC** - создать пользователя с ограниченными правами

## Структура файлов

```
homework-2.3/
├── terraform/                      # конфиги для GCP
├── manifests/
│   ├── configmap-web.yaml          # задача 1
│   ├── deployment-task1.yaml
│   ├── secret-tls.yaml             # задача 2
│   ├── deployment-task2.yaml
│   ├── ingress-tls.yaml
│   ├── role-pod-reader.yaml        # задача 3
│   └── rolebinding-developer.yaml
├── developer.crt                   # сертификаты для RBAC
├── developer.csr
└── tls.crt                         # TLS сертификат для Ingress
```

## Задача 1: ConfigMap с HTML страницей

Идея простая - создать ConfigMap с HTML файлом и примонтировать его в nginx.

Создал ConfigMap с базовой HTML страницей в `configmap-web.yaml`, потом Deployment с двумя контейнерами:
- nginx - показывает страницу
- multitool - для отладки если что

Применил манифесты:
```bash
$ kubectl apply -f manifests/configmap-web.yaml
configmap/web-content created

$ kubectl apply -f manifests/deployment-task1.yaml
deployment.apps/web-app created
service/web-app-service created
```

Проверил что поднялось:
```bash
$ kubectl get pods -l app=web-app
NAME                       READY   STATUS    RESTARTS   AGE
web-app-6bb7b8b5f7-lnjj8   2/2     Running   0          2m

$ kubectl get svc web-app-service
NAME              TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)        AGE
web-app-service   LoadBalancer   34.118.238.62   34.136.85.252   80:30166/TCP   2m
```

Зашел на внешний IP и вот что получилось:
```bash
$ curl http://34.136.85.252
<!DOCTYPE html>
<html>
<head>
    <title>Kubernetes ConfigMap Demo</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .info {
            background-color: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            color: #326ce5;
        }
    </style>
</head>
<body>
    <div class="info">
        <h1>Hello from Kubernetes ConfigMap!</h1>
        <p>This HTML page is served from a Kubernetes ConfigMap resource.</p>
        <p><strong>Homework:</strong> 2.3 - Task 1</p>
        <p><strong>Container:</strong> nginx</p>
        <p><strong>Mount path:</strong> /usr/share/nginx/html</p>
    </div>
</body>
</html>
```

Работает! Страница грузится из ConfigMap.

---

## Задача 2: HTTPS через Ingress с TLS

Тут посложнее - нужно настроить Ingress с TLS сертификатом.

Сначала сгенерировал self-signed сертификат:
```bash
$ openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=homework.example.com/O=netology"
```

Создал Secret из сертификата:
```bash
$ kubectl create secret tls homework-tls \
  --cert=tls.crt --key=tls.key \
  --dry-run=client -o yaml > manifests/secret-tls.yaml
```

Применил все манифесты:
```bash
$ kubectl apply -f manifests/secret-tls.yaml
secret/homework-tls created

$ kubectl apply -f manifests/deployment-task2.yaml
deployment.apps/https-app created
service/https-app-service created

$ kubectl apply -f manifests/ingress-tls.yaml
ingress.networking.k8s.io/homework-ingress created
```

Ingress получил IP:
```bash
$ kubectl get ingress homework-ingress
NAME               CLASS    HOSTS                  ADDRESS          PORTS     AGE
homework-ingress   <none>   homework.example.com   136.110.144.96   80, 443   5m
```

Проверил что backend сервис работает:
```bash
$ kubectl get pods -l app=https-app
NAME                        READY   STATUS    RESTARTS   AGE
https-app-55d754884-796hk   1/1     Running   0          5m

$ kubectl get svc https-app-service
NAME                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
https-app-service   ClusterIP   34.118.234.65   <none>        80/TCP    5m
```

Проверил изнутри кластера - nginx отвечает:
```bash
$ kubectl run test-pod --image=curlimages/curl:latest --rm -i --restart=Never -- curl -s http://https-app-service
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

Для HTTPS можно проверить так:
```bash
$ INGRESS_IP=$(kubectl get ingress homework-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
$ curl -k --resolve homework.example.com:443:$INGRESS_IP https://homework.example.com
```

> **Важно:** GKE Load Balancer долго инициализируется (5-10 минут) - проверки здоровья, роутинг и все такое. Backend может показывать "Unknown" пока не пройдет health check. Но сам сервис работает.

---

## Задача 3: RBAC - ограничение прав пользователя

Самая интересная задача. Нужно создать пользователя который может только смотреть поды и логи, но ничего не менять.

### Генерация сертификата

Сначала создал приватный ключ и certificate request:
```bash
$ openssl genrsa -out developer.key 2048

$ openssl req -new -key developer.key -out developer.csr -subj "/CN=developer/O=netology"
```

Потом отправил CSR в Kubernetes для подписи:
```bash
$ cat <<EOF | kubectl apply -f -
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
```

Подтвердил CSR и получил сертификат:
```bash
$ kubectl certificate approve developer
certificatesigningrequest.certificates.k8s.io/developer approved

$ kubectl get csr developer -o jsonpath='{.status.certificate}' | base64 -d > developer.crt
```

### Настройка прав

Создал Role с правами на просмотр подов:
```bash
$ kubectl apply -f manifests/role-pod-reader.yaml
role.rbac.authorization.k8s.io/pod-reader created
```

Привязал роль к пользователю:
```bash
$ kubectl apply -f manifests/rolebinding-developer.yaml
rolebinding.rbac.authorization.k8s.io/developer-pod-reader created
```

### Проверка доступа

Что разрешено - смотреть поды:
```bash
$ kubectl get pods --as=developer
NAME                        READY   STATUS    RESTARTS   AGE
https-app-55d754884-796hk   1/1     Running   0          10m
test-pod                    1/1     Running   0          5m
web-app-6bb7b8b5f7-lnjj8    2/2     Running   0          15m
```

И логи тоже можно:
```bash
$ POD_NAME=$(kubectl get pods -l app=web-app -o jsonpath='{.items[0].metadata.name}')
$ kubectl logs $POD_NAME -c nginx --as=developer --tail=5
2026/01/13 05:33:16 [error] 29#29: *3 open() "/usr/share/nginx/html/favicon.ico" failed...
10.112.0.1 - - [13/Jan/2026:05:35:18 +0000] "GET / HTTP/1.1" 200 788 "-" "curl/8.11.1" "-"
```

А вот deployments смотреть нельзя:
```bash
$ kubectl get deployments --as=developer
Error from server (Forbidden): deployments.apps is forbidden: User "developer" cannot list resource "deployments" in API group "apps" in the namespace "default"
```

И удалять тоже нельзя:
```bash
$ kubectl delete pod test-pod --as=developer
Error from server (Forbidden): pods "test-pod" is forbidden: User "developer" cannot delete resource "pods" in API group "" in the namespace "default"
```

Все работает как задумано - пользователь может только читать информацию о подах, но не управлять ими.

---

## Как запустить

### Поднять кластер
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# вписать свой project_id
terraform init
terraform apply
```

### Подключиться
```bash
gcloud container clusters get-credentials k8s-homework-2-3 --zone us-central1-a --project <project-id>
```

### Применить манифесты
```bash
kubectl apply -f manifests/
```

## Ссылки
- [Задание на GitHub](https://github.com/netology-code/kuber-homeworks/blob/shkuber-16/2.3/2.3.md)
