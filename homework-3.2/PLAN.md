# План выполнения домашнего задания 3.2 - Установка Kubernetes

## Задание

Установить кластер Kubernetes с использованием kubeadm в режиме HA:

**Основное задание:**
- Состав: 5 нод (1 master + 4 worker)
- Container Runtime: containerd
- etcd: на master ноде

**Дополнительное задание (HA):**
- Режим High Availability
- 3 master ноды (нечетное количество)
- keepalived для управления виртуальным IP
- etcd кластер на 3 master нодах

**Итоговая конфигурация (выполняем оба задания):**
- **Состав кластера**: 7 нод (3 master + 4 worker)
- **Container Runtime**: containerd
- **etcd**: кластер на 3 master нодах (stacked etcd)
- **HA решение**: HAProxy + keepalived
- **ОС**: Ubuntu 20.04 LTS

## Этапы выполнения

### Этап 1: Подготовка инфраструктуры на GCP

**Создать 7 виртуальных машин:**
- 3× master ноды: e2-medium (2 vCPU, 4 GB RAM)
- 4× worker ноды: e2-medium (2 vCPU, 4 GB RAM)
- ОС: Ubuntu 20.04 LTS
- Регион: us-central1-a

**Конфигурация сети:**
- VPC с приватной подсетью
- Firewall правила для:
  - Kubernetes API (6443)
  - etcd (2379-2380)
  - Kubelet API (10250)
  - NodePort Services (30000-32767)
  - Calico BGP (179)
  - VXLAN (4789)

**Инструменты:**
- Terraform для создания инфраструктуры
- gcloud для управления GCP

### Этап 2: Установка containerd на всех нодах

**На всех 5 нодах выполнить:**

1. Загрузить необходимые модули ядра:
```bash
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
```

2. Настроить параметры sysctl:
```bash
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system
```

3. Установить containerd:
```bash
sudo apt-get update
sudo apt-get install -y containerd

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# Включить SystemdCgroup
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd
```

### Этап 3: Установка kubeadm, kubelet, kubectl

**На всех 5 нодах:**

1. Отключить swap:
```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
```

2. Установить зависимости:
```bash
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
```

3. Добавить репозиторий Kubernetes:
```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

4. Установить пакеты:
```bash
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

### Этап 4: Настройка HAProxy и keepalived (HA)

**На всех 3 master нодах установить HAProxy:**

1. Установить HAProxy:
```bash
sudo apt-get update
sudo apt-get install -y haproxy
```

2. Настроить HAProxy (`/etc/haproxy/haproxy.cfg`):
```bash
cat <<EOF | sudo tee /etc/haproxy/haproxy.cfg
global
    log /dev/log local0
    log /dev/log local1 notice
    daemon

defaults
    log global
    mode tcp
    option tcplog
    option dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

frontend kubernetes-apiserver
    bind *:6443
    mode tcp
    option tcplog
    default_backend kubernetes-master

backend kubernetes-master
    mode tcp
    option tcp-check
    balance roundrobin
    server master1 <MASTER1_IP>:6443 check fall 3 rise 2
    server master2 <MASTER2_IP>:6443 check fall 3 rise 2
    server master3 <MASTER3_IP>:6443 check fall 3 rise 2
EOF

sudo systemctl enable haproxy
sudo systemctl restart haproxy
```

**На всех 3 master нодах установить keepalived:**

1. Установить keepalived:
```bash
sudo apt-get install -y keepalived
```

2. Настроить keepalived (на master1):
```bash
cat <<EOF | sudo tee /etc/keepalived/keepalived.conf
vrrp_script check_haproxy {
    script "/usr/bin/killall -0 haproxy"
    interval 2
    weight 2
}

vrrp_instance VI_1 {
    state MASTER
    interface ens4
    virtual_router_id 51
    priority 101
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1234
    }
    virtual_ipaddress {
        <VIP_ADDRESS>
    }
    track_script {
        check_haproxy
    }
}
EOF
```

3. Настроить keepalived (на master2 и master3):
```bash
# То же самое, но:
# state BACKUP
# priority 100 (на master2) и 99 (на master3)
```

4. Запустить keepalived:
```bash
sudo systemctl enable keepalived
sudo systemctl start keepalived
```

### Этап 5: Инициализация первого master узла (HA)

**Только на master1:**

1. Создать конфигурационный файл kubeadm:
```bash
cat <<EOF > kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.28.0
controlPlaneEndpoint: "<VIP_ADDRESS>:6443"
networking:
  podSubnet: "192.168.0.0/16"
etcd:
  local:
    dataDir: /var/lib/etcd
apiServer:
  certSANs:
  - "<VIP_ADDRESS>"
  - "<MASTER1_IP>"
  - "<MASTER2_IP>"
  - "<MASTER3_IP>"
EOF
```

2. Инициализировать кластер:
```bash
sudo kubeadm init --config kubeadm-config.yaml --upload-certs
```

3. Настроить kubectl:
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

4. Сохранить команды join:
```bash
# После kubeadm init будет 2 команды:
# 1. Для присоединения control-plane нод (master2, master3)
# 2. Для присоединения worker нод

# Сохранить обе команды!
```

### Этап 6: Присоединение остальных master нод

**На master2 и master3:**

Выполнить команду join для control-plane нод (с флагом --control-plane):
```bash
sudo kubeadm join <VIP>:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH> \
  --control-plane \
  --certificate-key <CERT_KEY>
```

После join на каждой ноде настроить kubectl:
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### Этап 7: Установка CNI (Calico)

**На любой master ноде:**

```bash
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

Дождаться запуска всех подов:
```bash
kubectl get pods -n kube-system -w
```

### Этап 8: Присоединение worker нод

**На каждой из 4 worker нод:**

Выполнить команду join для worker нод (без --control-plane):
```bash
sudo kubeadm join <VIP>:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

### Этап 9: Проверка HA кластера

**На любой master ноде:**

1. Проверить статус нод:
```bash
kubectl get nodes
kubectl get nodes -o wide
```

Все 7 нод должны быть в статусе Ready (3 master + 4 worker).

2. Проверить control-plane ноды:
```bash
kubectl get nodes --selector='node-role.kubernetes.io/control-plane'
```

Должны быть видны все 3 master ноды.

3. Проверить системные поды:
```bash
kubectl get pods -n kube-system -o wide
```

4. Проверить etcd кластер:
```bash
# На любой master ноде
sudo ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member list
```

Должны быть видны все 3 члена etcd кластера.

5. Проверить keepalived VIP:
```bash
# На любой машине
ping <VIP_ADDRESS>

# На master нодах проверить кто владеет VIP
ip addr show | grep <VIP>
```

6. Проверить HAProxy:
```bash
# На любой master ноде
sudo systemctl status haproxy
curl -k https://<VIP>:6443/healthz
```

7. Проверить компоненты кластера:
```bash
kubectl cluster-info
kubectl get componentstatuses
```

8. Развернуть тестовое приложение:
```bash
kubectl create deployment nginx --image=nginx --replicas=3
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl get pods,svc -o wide
```

9. Тест отказоустойчивости HA:
```bash
# Остановить одну master ноду
# На master2 например:
sudo shutdown now

# Убедиться что кластер продолжает работать
kubectl get nodes
kubectl get pods -A

# VIP должен переключиться на другую master ноду
```

### Этап 10: Документация

**Создать README.md с:**

1. Описание процесса установки HA кластера
2. Конфигурация кластера:
   - Количество нод (3 master + 4 worker)
   - Версии компонентов
   - CNI плагин (Calico)
   - Container runtime (containerd)
   - HA решение (HAProxy + keepalived)
   - etcd (stacked etcd на master нодах)

3. Скриншоты:
   - `kubectl get nodes` (все 7 нод)
   - `kubectl get nodes -o wide`
   - `kubectl get pods -n kube-system -o wide`
   - Список control-plane нод
   - etcd member list
   - keepalived status и VIP
   - HAProxy status
   - Тестовое приложение
   - Тест отказоустойчивости (отключение одной master ноды)

4. Инструкции по:
   - Подключению к кластеру через VIP
   - Добавлению новых master нод
   - Добавлению новых worker нод
   - Проверке состояния HA
   - Удалению нод
   - Очистке кластера

5. Конфигурационные файлы:
   - Terraform манифесты для 7 ВМ
   - Скрипты установки
   - kubeadm-config.yaml
   - HAProxy конфигурация
   - keepalived конфигурация

### Этап 11: Terraform для автоматизации (опционально)

**Создать Terraform конфигурацию:**

```
homework-3.2/terraform/
├── main.tf              # Основная конфигурация
├── variables.tf         # Переменные
├── outputs.tf           # Выходные данные (IPs нод, VIP)
├── network.tf           # Настройка сети
├── instances.tf         # Создание 7 ВМ
└── firewall.tf          # Правила firewall
```

**Основные ресурсы:**
- google_compute_network
- google_compute_subnetwork
- google_compute_firewall
- google_compute_instance (7 штук: 3 master + 4 worker)
- google_compute_address (для резервирования VIP)

**Outputs:**
- master_ips (3 IP адреса)
- worker_ips (4 IP адреса)
- vip_address (виртуальный IP)

### Этап 12: Коммит и push

```bash
git add homework-3.2/
git commit -m "Complete homework 3.2: Install Kubernetes HA cluster with kubeadm

Main task (5 nodes):
- 1 master + 4 workers on GCP
- containerd as CRI
- Kubernetes v1.28
- Calico CNI

Additional HA task:
- 3 master nodes in HA mode
- HAProxy for API server load balancing
- keepalived for VIP management
- stacked etcd cluster on masters
- Tested failover by shutting down one master

Total: 7 nodes (3 masters + 4 workers) all in Ready state"

git push origin homework-3.2
```

## Важные моменты

### Требования к нодам

**Master нода:**
- Минимум 2 CPU
- Минимум 2 GB RAM
- Полный доступ к сети

**Worker ноды:**
- Минимум 1 CPU (рекомендуется 2)
- Минимум 1 GB RAM (рекомендуется 2)

### Порты для firewall

**Master нода:**
- 6443: Kubernetes API server
- 2379-2380: etcd
- 10250: Kubelet API
- 10259: kube-scheduler
- 10257: kube-controller-manager

**Worker ноды:**
- 10250: Kubelet API
- 30000-32767: NodePort Services

**Calico:**
- 179: BGP
- 4789: VXLAN

### Версии

- Kubernetes: v1.28.x (стабильная версия)
- containerd: latest stable
- Calico: latest stable
- Ubuntu: 20.04 LTS

### Альтернативы

**CNI плагины (вместо Calico):**
- Flannel (проще, но меньше функций)
- Weave Net
- Cilium (более продвинутый)

**Container Runtime:**
- Используем containerd (рекомендуется)
- Альтернативы: CRI-O

### Troubleshooting

**Если ноды не переходят в Ready:**
```bash
# Проверить логи kubelet
sudo journalctl -u kubelet -f

# Проверить состояние containerd
sudo systemctl status containerd

# Проверить CNI поды
kubectl get pods -n kube-system | grep calico
```

**Если join не работает:**
```bash
# Создать новый токен на master
kubeadm token create --print-join-command

# Сбросить конфигурацию на worker
sudo kubeadm reset
sudo rm -rf /etc/cni/net.d
```

**Проверка сети:**
```bash
# На master
kubectl get nodes -o wide

# Пинг между нодами
ping <worker-ip>

# Проверка DNS
kubectl run test --image=busybox --rm -it --restart=Never -- nslookup kubernetes
```

## Структура итогового проекта

```
homework-3.2/
├── README.md                    # Основная документация с HA
├── PLAN.md                      # Этот план
├── terraform/                   # Terraform для 7 ВМ
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── network.tf
│   ├── instances.tf
│   └── firewall.tf
├── scripts/                     # Скрипты установки
│   ├── install-containerd.sh
│   ├── install-kubernetes.sh
│   ├── setup-haproxy.sh        # HAProxy конфигурация
│   ├── setup-keepalived.sh     # keepalived конфигурация
│   ├── init-first-master.sh    # Инициализация первого master
│   ├── join-master.sh          # Присоединение master нод
│   └── join-worker.sh          # Присоединение worker нод
├── configs/                     # Конфигурационные файлы
│   ├── kubeadm-config.yaml     # kubeadm конфиг для HA
│   ├── haproxy.cfg             # HAProxy конфиг
│   └── keepalived.conf         # keepalived конфиг (для каждой master)
├── manifests/                   # Kubernetes манифесты
│   └── test-nginx.yaml
└── screenshots/                 # Скриншоты
    ├── 01-kubectl-get-nodes.png
    ├── 02-kubectl-get-nodes-wide.png
    ├── 03-control-plane-nodes.png
    ├── 04-system-pods.png
    ├── 05-etcd-members.png
    ├── 06-keepalived-vip.png
    ├── 07-haproxy-status.png
    ├── 08-test-app.png
    └── 09-ha-failover-test.png
```

## Ожидаемый результат

В конце должно быть:
1. **Основное задание выполнено**:
   - Кластер из 5+ нод (у нас 7)
   - containerd как CRI
   - etcd работает

2. **Дополнительное HA задание выполнено**:
   - 3 master ноды (нечетное количество)
   - HAProxy для балансировки API сервера
   - keepalived для управления VIP
   - stacked etcd кластер на 3 мастерах

3. **Функциональность**:
   - Все 7 нод в статусе Ready
   - Системные поды работают на всех master нодах
   - Можно деплоить приложения
   - Networking работает между подами
   - При отказе одной master ноды кластер продолжает работать
   - VIP автоматически переключается между master нодами

4. **Документация**:
   - Полный README с процессом установки
   - Скриншоты всех этапов
   - Конфигурационные файлы
   - Инструкции по проверке HA
