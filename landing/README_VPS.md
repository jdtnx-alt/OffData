# 🚀 Guía de Despliegue en VPS para OffData (Landing Page & APK)

Esta carpeta contiene todo lo necesario para alojar la landing page informativa y permitir la descarga directa de la APK optimizada de **OffData** desde tu servidor VPS.

---

## 👥 Credenciales de Acceso Incluidas en la App

La aplicación cuenta con sistema multi-rol (**Administrador** y **Encuestador**):

| Rol | Correo Electrónico | Contraseña | Permisos |
| :--- | :--- | :--- | :--- |
| 👑 **Administrador** | `admin@offdata.com` | `OffData2026*` | Acceso a todas las personas, detector de duplicados, gestión de encuestadores (crear/editar/eliminar) y estadísticas de sync por encuestador. |
| 📋 **Encuestador 1** | `encuestador1@offdata.com` | `Encuestador2026*` | Registro en campo, visualización únicamente de sus registros y sincronización offline propia. |
| 📋 **Encuestador 2** | `encuestador2@offdata.com` | `Encuestador2026*` | Registro en campo, visualización únicamente de sus registros y sincronización offline propia. |

---

## 📦 Compilación Ligera de la APK (Para reducir peso)

Para generar la APK de producción optimizada y ligera (~20MB a 35MB):

```bash
# Opción A: APK Release universal optimizada
flutter build apk --release

# Opción B: APK optimizada por arquitectura (aún más ligera, ~15MB)
flutter build apk --release --split-per-abi
```

Una vez compilada, copia el archivo generado (`build/app/outputs/flutter-apk/app-release.apk`) a:
```
landing/downloads/offdata.apk
```

---

## ⚡ Opción 1: Despliegue Automático en VPS con Docker (Recomendado)

1. **Sube la carpeta `landing` a tu VPS** usando `scp` o FileZilla:
   ```bash
   scp -r landing/ root@TU_IP_VPS:/root/offdata-landing
   ```

2. **Entra a tu servidor VPS por SSH**:
   ```bash
   ssh root@TU_IP_VPS
   cd /root/offdata-landing
   ```

3. **Ejecuta el script de despliegue**:
   ```bash
   chmod +x vps-deploy.sh
   ./vps-deploy.sh
   ```

4. **¡Listo!** Abre `http://TU_IP_VPS` en tu navegador y verás la landing con descarga directa de la APK.

---

## 🌐 Opción 2: Despliegue con Nginx Tradicional

Si ya tienes Nginx instalado en tu VPS:

1. Copia los archivos a tu carpeta web pública:
   ```bash
   sudo cp -r landing/* /var/www/html/
   ```

2. Asegura los permisos correctos:
   ```bash
   sudo chown -R www-data:www-data /var/www/html/
   sudo chmod -R 755 /var/www/html/
   ```

3. Reinicia Nginx:
   ```bash
   sudo systemctl restart nginx
   ```
