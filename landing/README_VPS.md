# 🚀 Guía de Despliegue en VPS para OffData Landing Page

Esta carpeta contiene todo lo necesario para alojar la landing page informativa y permitir la descarga directa de la APK de **OffData** desde tu propio servidor VPS.

---

## 📂 Contenido del Directorio

- `index.html`: Página web informativa moderna y responsive.
- `styles.css`: Estilos en modo oscuro a juego con la app.
- `app.js`: Interactividad y soporte para botones.
- `assets/app_logo.png`: Logo oficial de OffData.
- `downloads/offdata.apk`: Archivo ejecutable APK de la aplicación listo para descarga.
- `Dockerfile` & `docker-compose.yml`: Despliegue con contenedor Nginx.
- `vps-deploy.sh`: Script de instalación automática de 1 paso.

---

## ⚡ Opción 1: Despliegue Automático con Docker (Recomendado)

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

4. **¡Listo!** Abre `http://TU_IP_VPS` en tu navegador y verás la landing con el botón de descarga funcionando.

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
