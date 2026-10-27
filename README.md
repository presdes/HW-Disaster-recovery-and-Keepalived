# Домашнее задание к занятию «Disaster recovery и Keepalived»

## Задание 1
Краткое руководство по стенду Keepalived + Nginx
### 📁 Итоговые файлы

#### 1. `/etc/keepalived/check_web.sh` (на обеих ВМ)

```bash
#!/bin/bash
if ss -tln | grep -q ":80 " && [ -f /var/www/html/index.html ]; then
    exit 0
else
    exit 1
fi
```

Проверяет два условия: порт 80 слушается (`ss -tln`) и файл `index.html` существует. Возвращает `0` при успехе, `1` при любом сбое.

#### 2. `/etc/keepalived/keepalived.conf` — MASTER (`192.168.1.168`)

```bash
global_defs {
    router_id LVS_MASTER
    script_user root
    enable_script_security
}

vrrp_script check_web {
    script "/etc/keepalived/check_web.sh"
    interval 3
}

vrrp_instance VI_1 {
    state MASTER
    interface enp0s3
    virtual_router_id 15
    priority 255
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        192.168.1.121/24
    }
    track_script {
        check_web
    }
}
```

#### 3. `/etc/keepalived/keepalived.conf` — BACKUP (`192.168.1.107`)

Отличается только двумя строками:
- `router_id LVS_BACKUP`
- `state BACKUP`
- `priority 100`

---

## ⚙️ Ключевые моменты конфигурации

| Параметр | Значение | Пояснение |
|---|---|---|
| `priority` MASTER | `255` | Максимальный приоритет — MASTER всегда выигрывает выборы |
| `priority` BACKUP | `100` | Ниже MASTER, но достаточен для работы |
| `interval 3` | 3 сек | Скрипт запускается каждые 3 секунды (по заданию) |
| `weight` | **отсутствует** | При сбое скрипта узел переходит в **FAULT** и отдаёт VIP |
| `script_user root` + `enable_script_security` | — | Без этого Keepalived блокирует выполнение скриптов (SECURITY VIOLATION) |
| `virtual_router_id 15` | одинаковый | Должен совпадать на обоих узлах |

> 💡 **Почему без `weight` работает**: при отсутствии `weight` (или `weight 0`) сбой скрипта переводит узел в состояние **FAULT**, и VIP принудительно переходит на BACKUP. Это самый надёжный способ для учебного стенда.

---
## 🚀 Порядок развёртывания

**Шаг 1. На обеих ВМ:**
```bash
sudo apt update && sudo apt install -y nginx keepalived
sudo systemctl enable --now nginx
```

**Шаг 2. Создать скрипт** `/etc/keepalived/check_web.sh` и сделать исполняемым:
```bash
sudo chmod +x /etc/keepalived/check_web.sh
```

**Шаг 3. Разместить конфиги** (разные для MASTER и BACKUP) в `/etc/keepalived/keepalived.conf`.

**Шаг 4. Запустить:**
```bash
sudo systemctl restart keepalived
sudo journalctl -u keepalived -n 20 --no-pager
```

**Шаг 5. Проверить VIP на MASTER:**
```bash
ip a show enp0s3 | grep 192.168.1.121
```

---
## 🧪 Демонстрация переезда VIP (для скриншота)

**На MASTER** остановите nginx:
```bash
sudo systemctl stop nginx
```

Подождите ~6–8 секунд (2 цикла проверки по 3 сек). Проверьте:

```bash
# На MASTER — VIP должен исчезнуть
ip a show enp0s3 | grep 192.168.1.121

# На BACKUP — VIP должен появиться
ip a show enp0s3 | grep 192.168.1.121
```

**Скриншот**: два терминала рядом — MASTER без VIP, BACKUP с VIP. Дополнительно можно приложить `sudo journalctl -u keepalived -n 10 --no-pager` с обеих машин (там будет `VRRP_Script(check_web) failed` → `Entering FAULT STATE` на MASTER и `Entering MASTER STATE` на BACKUP).

**Возврат**: `sudo systemctl start nginx` на MASTER — VIP вернётся через несколько секунд (priority 255 > 100).

---
 📋 Что сдавать
1. `check_web.sh` — скрипт проверки.
2. `keepalived.conf` с MASTER и BACKUP.
3. Скриншот переезда VIP.

---
## Задание 2

```
Router1>enable
Router1#conf term
Enter configuration commands, one per line. End with CNTL/Z.
Router1 (config) #int g
Routerl (config) #int gigabitEthernet
Routerl (config-if) #standby 1 priority
Router1 (config-if) #standby 1 preempt
Router1 (config-if) #standby 1 track g
Routerl (config-if) #standby 1 track
Router1 (config-if) #
0/1
95
gigabitEthernet 0/0

```


---
