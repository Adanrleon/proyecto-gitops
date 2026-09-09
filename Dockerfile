# Usamos una imagen oficial de Nginx en su version "alpine" (muy ligera)
FROM nginx:alpine

# Copiamos nuestro archivo index.html a la ruta donde Nginx lee los archivos web
COPY index.html /usr/share/nginx/html/