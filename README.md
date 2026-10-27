# Домашнее задание к занятию «Disaster recovery и Keepalived»

Данное руководство описывает процесс настройки отказоустойчивого кластера (Active-Passive) на базе Keepalived и Nginx с использованием Bash-скрипта для отслеживания состояния веб-сервера.

### Шаг 1. Установка пакетов (на обеих ВМ)

Установите веб-сервер Nginx и сервис Keepalived на обе виртуальные машины.

* **Команда:** `sudo apt update && sudo apt install nginx keepalived -y`
* **Пояснение:** Nginx автоматически создаст корневую директорию `/var/www/html/` с файлом `index.html` и займет порт 80, который потребуется для проверки доступности. Для наглядности работы стенда рекомендуется изменить содержимое файла `index.html` на резервном сервере (например, написать "This is the BACKUP web server").

### Шаг 2. Создание скрипта проверки (на обеих ВМ)

Создайте Bash-скрипт, который будет отслеживать доступность веб-сервера.

* **Команда:** `sudo nano /etc/keepalived/check_web.sh`
* **Содержимое:**
  
  ```bash
  #!/bin/bash
  # Check: port 80 is listening, and index.html exists
  if ss -tln | grep -q ":80 " && [ -f /var/www/html/index.html ]; then
      exit 0
  else
      exit 1
  fi
  ```
* **Выдача прав на исполнение:** `sudo chmod +x /etc/keepalived/check_web.sh`
* **Пояснение:** Скрипт использует `ss` для проверки активности 80 порта и утилиту `[ -f ]` для проверки наличия файла `index.html`. При успехе возвращается `0`, при ошибке — `1` (что послужит триггером для Keepalived). 

### Шаг 3. Настройка ВМ1 (Узел MASTER)

Примените конфигурацию для основной машины.

* **Команда:** `sudo nano /etc/keepalived/keepalived.conf`
* **Содержимое:**
  
  ```nginx
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

### Шаг 4. Настройка ВМ2 (Узел BACKUP)

Примените конфигурацию для резервной машины.

* **Команда:** `sudo nano /etc/keepalived/keepalived.conf`
* **Содержимое:**
  
  ```nginx
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
      priority 100
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
* **Пояснение:** Конфигурация ВМ2 аналогична ВМ1, но приоритет снижен до `100` (у ВМ1 он `255`). Из-за разницы приоритетов ВМ2 будет выступать в роли резервного узла (BACKUP).

### Шаг 5. Применение настроек и проверка работы (Failover)

**1. Запуск сервисов (на обеих ВМ):**
```bash
sudo systemctl restart nginx keepalived
sudo systemctl enable nginx keepalived
```

**2. Проверка штатного режима:**
* На узле **MASTER** выполните `ip a | grep 192.168.1.121`. Вы увидите, что виртуальный IP-адрес `192.168.1.121` успешно назначен интерфейсу.
* Команда `sudo systemctl status keepalived` на мастере покажет успешное выполнение скрипта (`VRRP_Script(check_web) succeeded`) и состояние `MASTER STATE`.

**3. Имитация аварии:**
* На узле **MASTER** остановите веб-сервер командой: `sudo systemctl stop nginx`.
* Проверьте статус Keepalived на мастере: скрипт вернет ошибку (`exited with status 1`), узел перейдет в состояние `FAULT STATE` и сбросит виртуальный IP (вывод `ip a | grep 192.168.1.121` станет пустым).

**4. Проверка переезда (Failover):**
* Перейдите на узел **BACKUP**. Выполните `sudo systemctl status keepalived` — в логах будет зафиксирован переход в `MASTER STATE`.
* Выполните `ip a | grep 192.168.1.121`. Виртуальный адрес теперь находится на резервном сервере.
* Откройте браузер и перейдите по адресу `http://192.168.1.121`. Вы должны увидеть страницу резервного сервера (например, "This is the BACKUP web server"), что подтверждает успешное переключение трафика.
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

```
Router2>enable
Router2#conf term
Enter configuration
commands, one per line. End with CNTL/Z.
Router2 (config) #int g
Router2 (config) #int gigabitEthernet 0/1
Router2 (config-if) #standby 1 track g
Router2 (config-if) #standby 1 track gigabitEthernet 0/0
Router2 (config-if) #|
```

---
