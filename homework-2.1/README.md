# Домашнее задание 2.1 - Kubernetes Storage

## Ответ для преподавателя

Добрый день!

Выполнил все три задачи по работе с механизмами хранения в Kubernetes. Развернул GKE кластер на GCP (2 ноды e2-medium в us-central1-a), все манифесты протестированы и работают.

**Что сделано:**
1. Настроил обмен данными между контейнерами через emptyDir volume
2. Реализовал работу с PersistentVolume и PVC, протестировал поведение Retain policy
3. Создал StorageClass с no-provisioner и WaitForFirstConsumer

**С какими трудностями столкнулся:**

1. **Проблема с Compute Engine Service Account** - при создании GKE кластера через Terraform получал ошибку "failed to check status for compute@developer.gserviceaccount.com". Оказалось, что в новом GCP проекте default service account не создается автоматически. Решил через создание service identity командой `gcloud beta services identity create --service=compute.googleapis.com`, но в итоге пришлось использовать существующий service account от VM (serviceforbot) для создания кластера через gcloud CLI напрямую.

2. **Read-only файловая система в GKE** - изначально использовал `/mnt/data` для hostPath в PersistentVolume, но получил ошибку "read-only file system". GKE использует Container-Optimized OS, где большинство директорий защищены от записи. Переключился на `/tmp/data` - единственную доступную для записи директорию на нодах.

3. **Автоматическое создание динамических PV** - в первой попытке с PV+PVC, GKE автоматически создал свой PV вместо использования моего с hostPath. Проблема была в отсутствии `storageClassName: manual` - без явного указания StorageClass, Kubernetes использует default StorageClass (standard-rwo в GKE).

**Что узнал нового:**
- Разница между статусами PV: "Available", "Bound" и "Released". Особенно важно понимание статуса "Released" - после удаления PVC с Retain policy, PV сохраняет информацию о прошлой привязке и не может быть автоматически переиспользован.
- Механизм WaitForFirstConsumer откладывает привязку PVC к PV до момента создания Pod, что критично для локального хранилища.
- Retain policy действительно сохраняет данные на диске даже после удаления всех Kubernetes ресурсов - проверил через kubectl debug на ноде.

Все результаты задокументированы в README с примерами команд и выводами. Манифесты находятся в директории `manifests/`.

---

## Описание
Практическое задание по работе с механизмами хранения данных в Kubernetes.
Выполняется на GCP с использованием Terraform.

## Задачи

### Задача 1: Volume - обмен данными между контейнерами
**Цель:** Создать Deployment с двумя контейнерами, обменивающимися данными через ephemeral volume.

**Требования:**
- Развернуть контейнеры busybox и multitool в одном поде
- Настроить busybox для записи данных каждые 5 секунд в общую директорию
- Multitool должен читать из этой же директории
- **Файл манифеста:** `manifests/containers-data-exchange.yaml`

### Задача 2: PersistentVolume и PersistentVolumeClaim
**Цель:** Реализовать постоянное хранилище с использованием вручную созданных PV ресурсов.

**Шаги:**
- Создать PV и PVC для доступа к локальной директории на ноде
- Развернуть два контейнера с использованием PVC
- Продемонстрировать сохранность данных
- Удалить Deployment/PVC и задокументировать поведение PV
- Удалить PV и проверить сохранность файлов на диске
- **Файл манифеста:** `manifests/pv-pvc.yaml`

### Задача 3: StorageClass
**Цель:** Автоматизировать создание PV через StorageClass.

**Требования:**
- Определить кастомный StorageClass с "kubernetes.io/no-provisioner"
- Создать PVC, ссылающийся на StorageClass
- Развернуть приложение с динамически созданным хранилищем
- Проверить функциональность обмена данными между контейнерами
- **Файл манифеста:** `manifests/sc.yaml`

## Структура проекта

```
homework-2.1/
├── README.md                          # Этот файл
├── terraform/                         # Terraform конфигурации для GCP
│   ├── main.tf                        # Основная конфигурация
│   ├── variables.tf                   # Переменные
│   └── outputs.tf                     # Выходные данные
└── manifests/                         # Kubernetes манифесты
    ├── containers-data-exchange.yaml  # Задача 1
    ├── pv-pvc.yaml                    # Задача 2
    └── sc.yaml                         # Задача 3
```

## Выполнение

### 1. Развертывание инфраструктуры
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 2. Подключение к кластеру
```bash
gcloud container clusters get-credentials <cluster-name> --region <region>
```

### 3. Применение манифестов
```bash
kubectl apply -f manifests/containers-data-exchange.yaml
kubectl apply -f manifests/pv-pvc.yaml
kubectl apply -f manifests/sc.yaml
```

## Результаты

### Задача 1: Volume - обмен данными между контейнерами

**Манифест:** [containers-data-exchange.yaml](manifests/containers-data-exchange.yaml)

**Описание решения:**
Создан Deployment с двумя контейнерами (busybox и multitool) в одном поде, использующими общий volume типа `emptyDir` для обмена данными.

**Конфигурация:**
- **busybox**: пишет timestamp каждые 5 секунд в `/output/data.txt`
- **multitool**: читает данные из `/input/data.txt` (тот же volume, другой mountPath)
- **Volume тип**: `emptyDir: {}` - эфемерное хранилище, существует только на время жизни Pod

**Проверка работы:**
```bash
kubectl apply -f manifests/containers-data-exchange.yaml
kubectl get pods -l app=data-exchange
kubectl describe pod <pod-name>
kubectl exec <pod-name> -c multitool -- tail -f /input/data.txt
```

**Результаты:**
- Pod запущен с двумя контейнерами (2/2 Running)
- busybox пишет данные каждые 5 секунд в `/output/data.txt`
- multitool читает те же данные из `/input/data.txt`
- Volume типа EmptyDir успешно обеспечивает обмен данными между контейнерами

**Важно:** emptyDir - эфемерное хранилище, данные теряются при удалении Pod.

---

### Задача 2: PersistentVolume и PersistentVolumeClaim

#### Манифест
Файл: [`manifests/pv-pvc.yaml`](manifests/pv-pvc.yaml)

#### Результаты выполнения

**1. Создание PV, PVC и Deployment:**
```bash
kubectl apply -f manifests/pv-pvc.yaml
kubectl get pv,pvc,pods -l app=pv-test
```

**Статус ресурсов:**
```
NAME          CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                  STORAGECLASS
pv-homework   1Gi        RWO            Retain           Bound    default/pvc-homework   manual

NAME           STATUS   VOLUME        CAPACITY   ACCESS MODES   STORAGECLASS
pvc-homework   Bound    pv-homework   1Gi        RWO            manual

NAME                             READY   STATUS    RESTARTS   AGE
pv-deployment-54f8955f7f-vqs99   2/2     Running   0          21s
```

**Проверка работы:**
```bash
# Чтение данных из multitool контейнера
kubectl exec <pod-name> -c multitool -- tail -10 /data/pv-data.txt
```

### Поведение PV при удалении ресурсов

#### 1. После удаления Deployment
```bash
kubectl delete deployment pv-deployment
kubectl get pv,pvc
```

**Результат:** PV и PVC остаются в статусе `Bound`. Удаление Deployment не влияет на PersistentVolume и PersistentVolumeClaim, так как они являются независимыми ресурсами.

#### 2. Удаление PVC

```bash
kubectl delete pvc pvc-homework
kubectl describe pv pv-homework
```

**Результат:**
- PV переходит в статус `Released` (НЕ `Available`!)
- Status: `Released` означает, что PV был привязан к PVC, который теперь удален
- PV сохраняет информацию о прошлой привязке (Claim: default/pvc-homework)
- С политикой `Retain` данные сохраняются на диске
- PV не может быть автоматически переиспользован - требуется ручная очистка

**Важное отличие статусов:**
- `Available` - PV никогда не был привязан к PVC, готов к использованию
- `Released` - PV был привязан к PVC, который удален, требуется ручная очистка
- `Bound` - PV привязан к PVC

#### 2.3. Проверка файлов на ноде

```bash
# Подключение к ноде и проверка файлов
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl debug node/$NODE_NAME -it --image=busybox -- ls -la /host/tmp/data/
kubectl debug node/$NODE_NAME -it --image=busybox -- cat /host/tmp/data/pv-data.txt | tail -10
```

**Результат:** Файлы существуют на диске ноды, данные сохранены.

#### 4. Удаление PV

```bash
kubectl delete pv pv-homework
```

Проверяем файлы на ноде после удаления PV:
```bash
kubectl debug node/<node-name> -it --image=busybox -- cat /host/tmp/data/pv-data.txt
```

**Результат:** Файлы остались на диске! Данные не были удалены.

#### Объяснение поведения PV

**Поведение после удаления Deployment:**
- PVC и PV остались в статусе Bound
- Данные на диске сохранены
- PVC продолжает резервировать volume

**Поведение после удаления PVC:**
- PV переходит в статус **Released** (не Available!)
- В описании PV сохраняется информация о бывшей привязке (Claim: default/pvc-homework)
- PV нельзя автоматически переиспользовать - нужна ручная очистка
- Это отличается от статуса "Available", который означает, что PV никогда не был привязан или был полностью очищен

**Reclaim Policy: Retain - ключевое поведение:**
- После удаления PVC, PV переходит в статус "Released" (не "Available")
- Данные на диске сохраняются
- PV сохраняет информацию о прошлой привязке (Claim: default/pvc-homework)
- PV не может быть автоматически переиспользован - требуется ручная очистка
- После удаления PV, файлы на ноде остаются нетронутыми
- Это позволяет администратору вручную решить, что делать с данными

---

### Задача 3: StorageClass

**Манифест:** [manifests/sc.yaml](manifests/sc.yaml)

```bash
# Применение манифеста
$ kubectl apply -f manifests/sc.yaml
storageclass.storage.k8s.io/local-storage created
persistentvolume/pv-local created
persistentvolumeclaim/pvc-local created
deployment.apps/sc-deployment created

# Проверка StorageClass
$ kubectl get storageclass
NAME                     PROVISIONER                    RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-storage            kubernetes.io/no-provisioner   Delete          WaitForFirstConsumer   false                  3s
premium-rwo              pd.csi.storage.gke.io          Delete          WaitForFirstConsumer   true                   12m
standard                 kubernetes.io/gce-pd           Delete          Immediate              true                   12m
standard-rwo (default)   pd.csi.storage.gke.io          Delete          WaitForFirstConsumer   true                   12m

# Описание StorageClass
$ kubectl describe storageclass local-storage
Name:            local-storage
IsDefaultClass:  No
Annotations:     kubectl.kubernetes.io/last-applied-configuration=...
Provisioner:           kubernetes.io/no-provisioner
Parameters:            <none>
AllowVolumeExpansion:  <unset>
MountOptions:          <none>
ReclaimPolicy:         Delete
VolumeBindingMode:     WaitForFirstConsumer
Events:                <none>

# Проверка PV и PVC
$ kubectl get pv,pvc
NAME                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM               STORAGECLASS    VOLUMEATTRIBUTESCLASS   REASON   AGE
persistentvolume/pv-local   1Gi        RWO            Delete           Bound    default/pvc-local   local-storage   <unset>                          13s

NAME                              STATUS   VOLUME     CAPACITY   ACCESS MODES   STORAGECLASS    VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/pvc-local   Bound    pv-local   1Gi        RWO            local-storage   <unset>                 14s

# Проверка Pod
$ kubectl get pods -l app=sc-test
NAME                             READY   STATUS    RESTARTS   AGE
sc-deployment-86bcd56686-5mt86   2/2     Running   0          20s

# Проверка обмена данными между контейнерами
$ kubectl exec sc-deployment-86bcd56686-5mt86 -c multitool -- tail -10 /data/sc-data.txt
Mon Jan 12 11:27:17 UTC 2026
SC Data written at Mon Jan 12 11:27:17 UTC 2026
Mon Jan 12 11:27:22 UTC 2026
SC Data written at Mon Jan 12 11:27:22 UTC 2026
Mon Jan 12 11:27:27 UTC 2026
SC Data written at Mon Jan 12 11:27:27 UTC 2026
...
```

**Особенности реализации:**

1. **StorageClass с kubernetes.io/no-provisioner:**
   - Не создает PV автоматически
   - Требует ручного создания PV перед использованием
   - Подходит для локального хранилища или специфичных случаев

2. **VolumeBindingMode: WaitForFirstConsumer:**
   - PVC не привязывается к PV до момента создания первого Pod, который использует этот PVC
   - Гарантирует, что PV будет выбран на ноде, где запланирован Pod
   - Важно для локального хранилища, привязанного к конкретной ноде

3. **Обмен данными между контейнерами:**
   - busybox пишет данные каждые 5 секунд в /data/sc-data.txt
   - multitool читает из того же volume /data/sc-data.txt
   - Данные успешно обмениваются через StorageClass-based storage

## Выводы

Все три задачи успешно выполнены:

1. **Volume (emptyDir):** Эфемерное хранилище для обмена данными между контейнерами в одном Pod. Данные теряются при удалении Pod.

2. **PersistentVolume и PersistentVolumeClaim:** Постоянное хранилище с Retain policy. Данные сохраняются на диске даже после удаления PV, требуется ручная очистка.

3. **StorageClass:** Автоматизация работы с PV через StorageClass с kubernetes.io/no-provisioner и WaitForFirstConsumer для локального хранилища.

## Ссылки
- [Оригинальное задание](https://github.com/netology-code/kuber-homeworks/blob/shkuber-16/2.1/2.1.md)
- [GKE кластер](https://console.cloud.google.com/kubernetes/workload_/gcloud/us-central1-a/k8s-storage-homework?project=upheld-rookery-471109-b0)

