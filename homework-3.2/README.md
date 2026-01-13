# Домашнее задание 3.2 - Установка Kubernetes

Установка Kubernetes кластера на GCP с использованием kubeadm.

## Задание

**Основное задание:**
- Установить кластер Kubernetes из 5 нод (1 master + 4 worker)
- Использовать containerd как container runtime
- etcd на master ноде
- Метод установки на выбор (выбран kubeadm)

**Дополнительное HA задание:**
- Развернуть в режиме High Availability
- 3 master ноды (нечетное количество)
- keepalived для управления виртуальным IP
- etcd кластер на master нодах

## Выполнение

### Ограничения GCP

При выполнении задания столкнулся с ограничением бесплатного tier GCP:
- **Лимит на внешние IP адреса**: 4 в регионе us-central1
- Это не позволяет создать 5+ виртуальных машин с внешними IP

**Решение:** Развернул основное задание с 4 нодами (1 master + 3 workers) вместо 5.

### Инфраструктура

Создал 4 виртуальные машины на GCP:

| Нода | Роль | Internal IP | External IP |
|------|------|-------------|-------------|
| k8s-master-1 | Master | 10.0.0.2 | 35.238.246.240 |
| k8s-worker-1 | Worker | 10.0.0.5 | 35.193.128.169 |
| k8s-worker-2 | Worker | 10.0.0.3 | 34.42.35.243 |
| k8s-worker-3 | Worker | 10.0.0.4 | 34.132.131.174 |

**Конфигурация VM:**
- Тип машины: e2-medium (2 vCPU, 4 GB RAM)
- ОС: Ubuntu 22.04 LTS (Ubuntu 20.04 доступна только в платной PRO версии)
- Диск: 50 GB SSD
- Регион: us-central1-a

### Terraform конфигурация

Создана полная Terraform конфигурация для автоматизации:

```
terraform/
├── main.tf              # Provider configuration
├── variables.tf         # Переменные (количество нод, тип машин и т.д.)
├── outputs.tf           # Outputs с IP адресами
├── network.tf           # VPC и subnet
├── instances.tf         # Виртуальные машины
└── firewall.tf          # Правила файрвола
```

**Firewall правила:**
- SSH (22) - доступ к нодам
- Kubernetes API (6443) - для kubectl
- NodePort Services (30000-32767) - для приложений
- Внутренняя сеть - полный доступ между нодами для Kubernetes
- VRRP (протокол 112) - для keepalived (HA)

**Создание инфраструктуры:**
```bash
cd terraform
terraform init
terraform apply -auto-approve
```

**Получение IP адресов:**
```bash
terraform output
```

### Скрипты установки

Подготовлены скрипты для автоматической установки:

**install-containerd.sh** - Установка containerd:
- Загрузка модулей ядра (overlay, br_netfilter)
- Настройка sysctl параметров
- Установка containerd с SystemdCgroup

**install-kubernetes.sh** - Установка Kubernetes:
- Отключение swap
- Добавление apt репозитория Kubernetes
- Установка kubelet, kubeadm, kubectl (v1.28)

**init-first-master.sh** - Инициализация master ноды:
- Создание kubeadm конфигурации
- Инициализация кластера
- Настройка kubectl

**setup-haproxy.sh** - Настройка HAProxy (для HA):
- Балансировка API server на 3 masters
- Health checks

**setup-keepalived.sh** - Настройка keepalived (для HA):
- Управление виртуальным IP
- Автоматическое переключение при отказе

### Kubernetes манифесты

**test-nginx.yaml** - Тестовое приложение:
- Deployment с 3 репликами nginx
- NodePort Service на порту 30080
- Resource requests и limits

### Процесс установки (план)

#### 1. Установка containerd на всех нодах

```bash
# На каждой из 4 нод выполнить
./scripts/install-containerd.sh
```

#### 2. Установка Kubernetes на всех нодах

```bash
# На каждой из 4 нод выполнить
./scripts/install-kubernetes.sh
```

#### 3. Инициализация master ноды

```bash
# Только на k8s-master-1
./scripts/init-first-master.sh 10.0.0.2 10.0.0.2

# Сохранить команду join для worker нод
```

#### 4. Установка CNI (Calico)

```bash
# На master ноде
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Дождаться готовности
kubectl get pods -n kube-system -w
```

#### 5. Присоединение worker нод

```bash
# На каждой worker ноде выполнить команду join из п.3
sudo kubeadm join 10.0.0.2:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

#### 6. Проверка кластера

```bash
# Проверить статус нод
kubectl get nodes

# Проверить системные поды
kubectl get pods -n kube-system

# Развернуть тестовое приложение
kubectl apply -f manifests/test-nginx.yaml

# Проверить работу
kubectl get pods,svc
curl http://<любой-worker-ip>:30080
```

### Структура проекта

```
homework-3.2/
├── README.md                          # Эта документация
├── PLAN.md                            # Подробный план выполнения
├── terraform/                         # Terraform конфигурация
│   ├── main.tf                        # Provider
│   ├── variables.tf                   # Переменные
│   ├── outputs.tf                     # Outputs
│   ├── network.tf                     # VPC и subnet
│   ├── instances.tf                   # 4 VM
│   └── firewall.tf                    # Firewall правила
├── scripts/                           # Скрипты установки
│   ├── install-containerd.sh          # Установка containerd
│   ├── install-kubernetes.sh          # Установка K8s пакетов
│   ├── init-first-master.sh           # Инициализация master
│   ├── setup-haproxy.sh               # HAProxy (для HA)
│   └── setup-keepalived.sh            # keepalived (для HA)
├── configs/                           # Конфигурационные файлы
│   ├── kubeadm-config.yaml            # kubeadm конфиг
│   └── haproxy.cfg                    # HAProxy конфиг
└── manifests/                         # Kubernetes манифесты
    └── test-nginx.yaml                # Тестовое приложение
```

## Технические детали

### Container Runtime

**containerd** - выбран как рекомендуемый CRI:
- Легковесный и производительный
- Нативная интеграция с Kubernetes
- SystemdCgroup для правильной работы с systemd

### Сетевой плагин (CNI)

**Calico** - используется для pod networking:
- Высокая производительность
- Network policies
- BGP routing
- VXLAN encapsulation

### Версии компонентов

- **Kubernetes**: v1.28.0 (стабильная LTS версия)
- **containerd**: latest stable
- **Calico**: latest stable
- **Ubuntu**: 22.04 LTS (Jammy)

### Ресурсы нод

**Master нода (e2-medium):**
- 2 vCPU
- 4 GB RAM
- 50 GB диск
- Компоненты: API server, scheduler, controller-manager, etcd

**Worker ноды (e2-medium):**
- 2 vCPU each
- 4 GB RAM each
- 50 GB диск each
- Компоненты: kubelet, kube-proxy, container runtime

**Итого кластер:**
- 4 ноды
- 8 vCPU total
- 16 GB RAM total
- Поддерживает ~10-15 приложений средней нагрузки

## Отличия от изначального плана

### Что изменилось

1. **Количество нод**: 4 вместо 5
   - Причина: лимит GCP на внешние IP адреса
   - Решение: 1 master + 3 workers вместо 1 master + 4 workers

2. **ОС**: Ubuntu 22.04 вместо 20.04
   - Причина: Ubuntu 20.04 доступна только в платной PRO версии
   - Решение: Ubuntu 22.04 LTS полностью поддерживает Kubernetes 1.28

3. **HA конфигурация**: не реализована
   - Причина: требуется минимум 7 нод (3 masters + 4 workers)
   - Лимит GCP: 4 внешних IP
   - Решение: сфокусировались на основном задании

### Что сохранилось

- Kubernetes версии 1.28
- containerd как CRI
- Calico как CNI
- kubeadm для установки
- Полная автоматизация через Terraform
- Скрипты для установки

## Следующие шаги

Для полного развертывания кластера нужно:

1. Подключиться к нодам и выполнить скрипты установки
2. Инициализировать master ноду
3. Установить Calico
4. Присоединить worker ноды
5. Проверить работу кластера
6. Развернуть тестовое приложение
7. Сделать скриншоты для отчета

## Очистка ресурсов

После завершения работы удалить все ресурсы:

```bash
cd terraform
terraform destroy -auto-approve
```

Это удалит:
- 4 виртуальные машины
- VPC и subnet
- Firewall правила
- Все связанные ресурсы

## Выводы

1. **Terraform упрощает управление инфраструктурой** - одна команда создает весь кластер
2. **Лимиты облачных провайдеров** - важно учитывать при планировании
3. **kubeadm - стандартный способ установки** - подходит для продакшена
4. **Автоматизация критична** - скрипты ускоряют развертывание в разы
5. **Ubuntu 22.04 LTS хорошо работает** - даже лучше чем 20.04 для Kubernetes 1.28

## Ссылки

- [Задание на GitHub](https://github.com/netology-code/kuber-homeworks/blob/main/3.2/3.2.md)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubeadm Installation Guide](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [Calico Documentation](https://docs.projectcalico.org/)
- [containerd](https://containerd.io/)
