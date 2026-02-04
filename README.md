# IR-VPN Management Panel

IR-VPN یک پنل مدیریت حرفه‌ای برای Xray/V2Ray است که نصب، کانفیگ و مدیریت سرور و کاربران را کاملاً اتوماتیک انجام می‌دهد.

## ویژگی‌ها

* نصب خودکار Backend (FastAPI)، Frontend (React/Next.js)، Bot تلگرام، Xray/V2Ray، SSL، و systemd services
* مدیریت کاربران: ایجاد، ویرایش، حذف، تولید UUID، فعال/غیرفعال کردن، محدودیت حجم، تاریخ انقضا
* مدیریت پروتکل‌ها: VLESS, VMess, Trojan, Shadowsocks
* Transport: TCP, WS, gRPC
* TLS: اتوماسیون Let’s Encrypt و مدیریت چند دامنه
* مانیتورینگ: CPU, RAM, Disk و ترافیک کاربران با خروجی CSV و نمودار زنده
* امنیت: JWT Auth، 2FA، نقش‌محور، IP whitelist، محدودیت درخواست‌ها، لاگ کامل
* UI گرافیکی مدرن با انیمیشن، Dark/Light، کارت‌ها و نمودارهای متحرک
* ربات تلگرام Admin/User برای مدیریت و مشاهده اطلاعات
* Installer Bash برنددار با Rollback کامل و بررسی Root/OS/Port

## ساختار پروژه

```
xray-management/
├── backend/
├── frontend/
├── bot/
├── installer/
├── config/
└── monitoring/
```

## نصب و راه‌اندازی

1. سرور Ubuntu 20.04 یا بالاتر
2. کلون پروژه به `/opt/ir-vpn`
3. اجرای Installer:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/IR-DevCo/ir-vpn-Panel/main/install.sh)
```

4. وارد کردن دامنه برای SSL
5. پس از اتمام، Frontend در `https://your_domain` در دسترس خواهد بود

## اجرای Monitoring

* **Server metrics**:

```bash
python3 monitoring/server_monitor.py
```

* **User traffic**:

```bash
python3 monitoring/traffic_monitor.py
```

## اجرای Bot تلگرام

* **Admin Bot**:

```bash
python3 bot/admin_bot.py
```

* **User Bot**:

```bash
python3 bot/user_bot.py
```

## اتصال Frontend به Backend

* API در `http://localhost:8000/api`
* WebSocket برای Realtime Metrics: `http://localhost:8000`

## فایل‌های پیکربندی

* `config/xray_config.json` – کانفیگ Xray/V2Ray
* `bot/config.py` – توکن و URL API

## امنیت و مجوزها

* تمامی سرویس‌ها با systemd و دسترسی root امن شده‌اند
* HTTPS و TLS فعال
* JWT و 2FA برای پنل مدیریت

## پشتیبانی

برای هر گونه مشکل یا سوال، لطفاً از طریق ربات Admin تلگرام یا ایمیل admin@your_domain تماس بگیرید.
