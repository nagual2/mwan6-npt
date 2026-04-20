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
- **Интерфейс по умолчанию**: Один интерфейс отмечается как LAN для трансляции NPTv6

## Установка

### Сборка из исходников

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
config interface 'lan'
	option enabled '1'
	option wan_prefix 'fd00:1111:2222:f000::/64'
	option default '1'

config interface 'tb6'
	option enabled '1'
	option wan_prefix 'fd00:aaaa:bbbb:14f::/64'
	option default '0'

config interface 'tb62'
	option enabled '1'
	option wan_prefix 'fd00:aaaa:bbbb:1b8::/64'
	option default '0'
```

### Опции

**Секция interface:**
- `enabled`: Включить этот интерфейс (0/1)
- `wan_prefix`: IPv6-префикс для этого интерфейса (/64)
- `default`: Отметить как LAN/интерфейс по умолчанию (только один должен иметь `1`)
  - Интерфейс по умолчанию предоставляет LAN-префикс для трансляции NPTv6
  - Все остальные интерфейсы транслируют в/из этого префикса

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

# Переключение интерфейса по умолчанию (LAN)
uci set mwan6-npt.lan.default='0'
uci set mwan6-npt.tb6.default='1'

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

Для тестирования на `openwrt-dev` используйте ULA-префиксы (fd00::/8):

```bash
# LAN-префикс (ULA) — от интерфейса по умолчанию
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

## Лицензия

GPL-2.0

## Автор

OpenWrt Community
