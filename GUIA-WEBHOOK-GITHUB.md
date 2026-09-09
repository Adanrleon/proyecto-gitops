# Guía: Configurar GitHub Webhooks Automáticos

## Problema
En ambiente local (Docker Desktop), GitHub no puede enviar webhooks a `localhost` porque no es una dirección pública en internet.

## Soluciones

### Opción 1: Usar ngrok (Recomendado para Desarrollo)

**ngrok** crea un túnel seguro que expone tu localhost a internet.

#### Instalación

```bash
# En macOS con Homebrew
brew install ngrok

# O descarga desde: https://ngrok.com/download
```

#### Uso

1. **Obtener token de autenticación** (en https://dashboard.ngrok.com/auth/your-authtoken)

```bash
ngrok config add-authtoken TU_TOKEN_AQUI
```

2. **Exponer tu EventSource** a través de ngrok

```bash
# En una nueva terminal
ngrok http 12000
```

Verás una salida como:
```
Session Status                online
Account                       tu_email@example.com
Version                       3.3.0
Region                        us-california
Latency                        36ms
Web Interface                  http://127.0.0.1:4040
Forwarding                     https://abc123xyz.ngrok.io -> http://localhost:12000
```

3. **Configurar GitHub Webhook**

Ves a tu repositorio en GitHub → Settings → Webhooks → Add webhook

- **Payload URL**: `https://abc123xyz.ngrok.io/push`
- **Content type**: `application/json`
- **Events**: Selecciona "Push events"
- **Active**: ✓

4. **Prueba**

Haz un cambio, commit y push. GitHub debería enviar el webhook y verás:
- El evento llegará a tu EventSource
- El Sensor creará un Workflow
- Kaniko compilará la imagen
- Kubernetes se actualizará automáticamente

### Opción 2: GitHub Codespaces (Desarrollo en la Nube)

Si usas GitHub Codespaces, tienes una URL pública automáticamente:

1. En Codespaces, tu puerto 12000 estará expuesto públicamente
2. GitHub puede enviarte webhooks directamente
3. Todo funciona sin necesidad de ngrok

### Opción 3: Usar un Dominio Real

Si tienes un dominio y dirección IP pública:

1. Apunta tu dominio a tu IP pública
2. Configura port forwarding en tu router (puerto 12000)
3. Configura HTTPS con Let's Encrypt
4. Usa tu dominio público en el webhook de GitHub

---

## Verificar que el Webhook Funciona

Después de configurar el webhook en GitHub:

1. **Ver los eventos enviados**
   - En GitHub → Settings → Webhooks → Tu webhook
   - Scroll down a "Recent Deliveries"
   - Verás los eventos y si fueron exitosos (código 200)

2. **Monitorear Argo Events**

```bash
# Ver logs del EventSource
kubectl logs -n argo -l eventsource-name=github-eventsource -f

# Ver logs del Sensor
kubectl logs -n argo -l sensor-name=github-sensor -f

# Ver Workflows creados
kubectl get workflows -n argo --watch
```

---

## Flujo Completamente Automático

Una vez configurado el webhook:

```
1. Editas código en VS Code
2. Haces git push
3. GitHub envía webhook automáticamente
4. EventSource recibe el evento
5. Sensor dispara Workflow
6. Kaniko compila imagen
7. Imagen se sube a Docker Hub
8. Argo CD sincroniza automáticamente
9. Kubernetes actualiza el Deployment
10. ¡Tu cambio está en vivo en segundos!
```

---

## Debugging

Si el webhook no funciona:

```bash
# 1. Verificar que ngrok está corriendo
# Terminal donde ejecutaste: ngrok http 12000

# 2. Ver eventos en EventSource
kubectl logs -n argo -l eventsource-name=github-eventsource --tail=30

# 3. Verificar que el Sensor está escuchando
kubectl logs -n argo -l sensor-name=github-sensor --tail=30

# 4. Verificar Service endpoints
kubectl get endpoints -n argo github-eventsource-service

# 5. Hacer prueba manual dentro del cluster
kubectl run test --image=curlimages/curl --rm -it -- curl -X POST http://github-eventsource-service:12000/push -H "Content-Type: application/json" -d '{"ref":"refs/heads/main"}'
```

---

## Notas Importantes

- **ngrok URL cambia cada vez** que reinicia (usa ngrok Pro para URL fija)
- **El webhook debe ser HTTPS** (ngrok proporciona HTTPS automáticamente)
- **GitHub intenta reintentar** los webhooks fallidos
- **Verifica firewall y permisos** de red si hay problemas
