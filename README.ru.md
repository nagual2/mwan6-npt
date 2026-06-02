# mwan6-npt

**Русский** | [English](README.md) | [Deutsch](README.de.md)

Поддержка NPTv6 (трансляция сетевых префиксов IPv6) для нескольких WAN-интерфейсов на OpenWrt.

## Обзор

mwan6-npt автоматически управляет правилами трансляции IPv6-префиксов для активных туннелей/интерфейсов, обеспечивая бесшовный IPv6 multi-homing с сохранением LAN-префикса при коммуникации через разные WAN-префиксы.

## Возможности

- **Конфигурация UCI**: Стандартный интерфейс конфигурации OpenWrt
- **Hotplug-интеграция**: Автоматическая перегенерация правил при up/down событиях интерфейса
- **Поддержка procd**: Правильный init-скрипт с триггерами сервиса
- **Совместимость с nftables/fw4**: Использует систему фаервола OpenWrt 22.03+
- **Поддержка нескольких WAN**: Конфигурация множества интерфейсов с разными префиксами
- **Источник LAN-префикса**: Один интерфейс отмечается как источник LAN-префикса для трансляции NPTv6

## Установка

### Установка из IPK (Рекомендуется)

Скачайте последний пакет `.ipk` из [Releases](https://github.com/nagual2/mwan6-npt/releases) и установите:

```bash
# Скачать на роутер
wget https://github.com/nagual2/mwan6-npt/releases/download/v1.1.1/mwan6-npt_1.1.1-1_all.ipk -O /tmp/mwan6-npt.ipk

# OpenWrt 23.x (opkg)
opkg install /tmp/mwan6-npt.ipk

# OpenWrt 25.12+ (apk)
wget https://github.com/nagual2/mwan6-npt/releases/download/v1.1.1/mwan6-npt-1.1.1-r1.apk -O /tmp/mwan6-npt.apk
apk add --allow-untrusted /tmp/mwan6-npt.apk
# или: ./scripts/install-apk.sh 192.168.1.1
```

**Pin (apk):** после `apk add --allow-untrusted` в `/etc/apk/world` появляется `mwan6-npt><Q1hash…` — feeds не заменят fork при `apk upgrade`. См. [luci-app-mwan3 — Pinning](https://github.com/nagual2/luci-app-mwan3#pinning-the-nagual2-fork-apk).

После установки проверьте `/etc/config/mwan6-npt`, затем выполните `reload` сервиса:

При **первой установке** (`/etc/uci-defaults/99-mwan6-npt`): секция `lan`, сервис **выключен** (`globals.enabled=0`); `detect-lan-prefix.sh` заполняет `lan.wan_prefix`, если PD уже есть в `network`; `import-from-mwan3.sh` добавляет WAN-секции из настроенного **mwan3** (IPv6, enabled). Если PD настраиваете позже — `sync-lan-prefix.sh`. Подробно: [docs/INSTALL-stack.ru.md](docs/INSTALL-stack.ru.md) §3.6–3.8.

```bash
# Сначала проверьте конфигурацию
vi /etc/config/mwan6-npt

# Сгенерировать правила и перегрузить firewall
/etc/init.d/mwan6-npt reload

# Необязательно: включить/запустить procd-сервис после настройки globals.enabled
/etc/init.d/mwan6-npt enable
/etc/init.d/mwan6-npt start
```

### Сборка IPK из исходников

```bash
# Клонировать репозиторий
git clone https://github.com/nagual2/mwan6-npt.git
cd mwan6-npt

# Собрать пакет (требуется make и ar)
make -f Makefile.build ipk

# Копировать на роутер
scp dist/mwan6-npt_*.ipk root@openwrt:/tmp/
```

### Сборка из OpenWrt SDK

```bash
cd $TOPDIR/package
mkdir -p custom
cp -r /path/to/mwan6-npt ./custom/
make menuconfig  # Выбрать Network -> mwan6-npt
make package/mwan6-npt/compile
```

### Ручная установка

Копирование файлов на роутер:

```bash
# Копирование файлов пакета
scp -r files/* root@openwrt:/

# Установка прав
ssh root@openwrt '
  chmod +x /etc/init.d/mwan6-npt
  chmod +x /etc/hotplug.d/iface/25-mwan6-npt
  chmod +x /usr/sbin/mwan6-npt
  chmod +x /usr/share/mwan6-npt/functions.sh
'
```

Включение и запуск:

```bash
/etc/init.d/mwan6-npt enable
/etc/init.d/mwan6-npt start
```

## Конфигурация

Редактирование `/etc/config/mwan6-npt`:

```uci
config globals 'globals'
	option enabled '0'

config interface 'lan'
	option enabled '1'
	option wan_prefix '2001:db8::/56'
	option default '1'

config interface 'tb62'
	option enabled '1'
	option wan_prefix '2001:db8:1::/56'
	option default '0'
```

Секция `lan` создаётся при установке; WAN-секции (например `tb62`) добавляются администратором через LuCI или UCI.

### Опции

**Секция globals:**
- `enabled`: Включает запуск через procd-сервис (0/1)

**Секция interface:**
- `enabled`: Включает этот интерфейс в обработку NPT (0/1)
- `wan_prefix`: IPv6-префикс для этого интерфейса
- `default`: Отмечает секцию, которая предоставляет исходный LAN-префикс для NPTv6 (только одна должна иметь `1`)
  - Секция с `default=1` не выбирает default gateway
  - Секция с `default=1` предоставляет LAN/source prefix для трансляции
  - Все остальные интерфейсы транслируют в/из этого префикса

### Сценарий с маршрутизируемым префиксом

Если один WAN-туннель уже несет маршрутизируемый LAN-префикс и LAN-клиенты получают его напрямую через RA/SLAAC, не нужно выполнять трансляцию через этот туннель.

Пример:

```uci
config interface 'lan'
	option enabled '1'
	option wan_prefix '<routed-lan-prefix>'
	option default '1'

config interface 'tb64'
	option enabled '0'
	option wan_prefix '<tb64-wan-prefix>'
	option default '0'
```

В этом сценарии:
- `lan.wan_prefix` хранит маршрутизируемый LAN-префикс
- `tb64.enabled='0'` исключает `tb64` из трансляции, потому что для этого пути NPT не нужна
- Другие WAN/туннельные интерфейсы, которым нужна трансляция префикса, остаются с `enabled='1'`

## Использование

### CLI-команды

```bash
# Ручное обновление правил
/usr/sbin/mwan6-npt update

# Проверка статуса
/usr/sbin/mwan6-npt status

# Очистка всех правил
/usr/sbin/mwan6-npt flush

# Управление сервисом
/etc/init.d/mwan6-npt {start|stop|restart|reload|enable|disable}
```

### Команды UCI

```bash
# Добавление нового WAN-интерфейса
uci add mwan6-npt interface
uci set mwan6-npt.@interface[-1].name='tb64'
uci set mwan6-npt.@interface[-1].wan_prefix='fd00:eeee:ffff:1f5::/64'
uci set mwan6-npt.@interface[-1].enabled='1'
uci set mwan6-npt.@interface[-1].default='0'

# Включение логики сервиса
uci set mwan6-npt.globals=globals
uci set mwan6-npt.globals.enabled='1'

# Исключить туннель из трансляции, если он уже несет маршрутизируемый LAN-префикс
uci set mwan6-npt.tb64.enabled='0'

# Применение изменений
uci commit mwan6-npt
/etc/init.d/mwan6-npt reload
```

## Проверка

Проверка активных правил:

```bash
# Список правил NPTv6 в nftables
nft list chain inet fw4 srcnat | grep -E 'snat prefix'
nft list chain inet fw4 dstnat | grep -E 'dnat prefix'

# Проверка сгенерированных файлов
cat /usr/share/nftables.d/chain-post/srcnat/99-mwan6-npt.nft
cat /usr/share/nftables.d/chain-post/dstnat/99-mwan6-npt.nft

# Тест с LAN-устройства
ping6 fd00:aaaa:bbbb:14f::1
# Должно работать через NPTv6-трансляцию
```

## Архитектура

```
Интерфейс UP/DOWN
       ↓
hotplug.d/iface/25-mwan6-npt
       ↓
/usr/sbin/mwan6-npt update
       ↓
/etc/config/mwan6-npt (UCI)
       ↓
generates → /usr/share/nftables.d/chain-post/{srcnat,dstnat}/99-mwan6-npt.nft
       ↓
fw4 reload → активные правила nftables
```

## Тестирование с ULA

Для тестирования на лабораторном роутере используйте ULA-префиксы (fd00::/8):

```bash
# LAN-префикс (ULA) — от default/source LAN-секции
fd00:1111:2222:f000::/64

# WAN-префиксы (ULA)
fd00:aaaa:bbbb:14f::/64
fd00:aaaa:bbbb:1b8::/64
fd00:cccc:dddd:1f4::/64
```

ULA-адреса не требуют реального IPv6-соединения и безопасны для лабораторного тестирования.

## Требования

- OpenWrt 22.03+ (fw4/nftables)
- Пакет `nftables`
- Пакет `ip-full`

## Связанные пакеты

| Пакет | Репозиторий |
|-------|-------------|
| mwan3 (fork) | [nagual2/mwan3](https://github.com/nagual2/mwan3) |
| luci-app-mwan3 | [nagual2/luci-app-mwan3](https://github.com/nagual2/luci-app-mwan3) |
| luci mwan6-npt | [nagual2/mwan6-npt-luci](https://github.com/nagual2/mwan6-npt-luci) |

**Установка всего стека вместе:** [docs/INSTALL-stack.ru.md](docs/INSTALL-stack.ru.md) (на роутере: `/usr/share/doc/mwan6-npt/INSTALL-stack.ru.md`).

## Документация

Триязычные README и инструкция по стеку устанавливаются в `/usr/share/doc/mwan6-npt/` (`README.en.md`, `README.ru.md`, `README.de.md`, `INSTALL-stack.ru.md`, `INSTALL-stack.en.md`, `INSTALL-stack.de.md`).

## Лицензия

Apache-2.0 (как у [LuCI](https://github.com/openwrt/luci)). См. `LICENSE` и `NOTICE` в репозитории и на роутере.

## Автор

OpenWrt Community
