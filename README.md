# Referencia Rápida - Proyecto GitOps

## Flujo GitOps actual

Cada push a `main` construye una imagen con el SHA del commit, por ejemplo
`adanleon/app-gitops:abc123...`. El Workflow actualiza esa etiqueta en
`k8s/deployment.yaml` y hace un commit automático con `[skip build]`. Argo CD
detecta el manifiesto actualizado y crea un Pod con esa imagen exacta.

El secreto `github-token` del namespace `argo` debe contener un fine-grained
personal access token de GitHub con permiso **Contents: Read and write** sobre
este repositorio. Nunca lo añadas a Git.

## Estado Actual
✅ **Proyecto completamente funcional**

El flujo end-to-end está probado y funcionando:
- Cambio en código → Webhook → EventSource → Sensor → Workflow → Nueva imagen → Kubernetes → Página actualizada

---

## Cómo Hacer un Cambio (Método Manual - Funciona Ahora)

### 1. Editar el código

```bash
# Edita index.html o Dockerfile
code /Users/adanleon/Desktop/proyecto-gitops/index.html
```

### 2. Hacer commit y push

```bash
cd /Users/adanleon/Desktop/proyecto-gitops
git add -A
git commit -m "Tu mensaje descriptivo"
git push
```

### 3. Disparar el webhook manualmente (necesario en ambiente local)

```bash
# Opción A: Desde dentro del cluster
kubectl run test --image=curlimages/curl --rm -it -n argo -- curl -X POST http://github-eventsource-service:12000/push -H "Content-Type: application/json" -d '{"ref":"refs/heads/main"}'

# Opción B: Con port-forward local
kubectl port-forward -n argo svc/github-eventsource-service 12000:12000 &
curl -X POST http://localhost:12000/push -H "Content-Type: application/json" -d '{"ref":"refs/heads/main"}'
```

### 4. Monitorear el progreso

```bash
# Ver Workflows siendo creados
kubectl get workflows -n argo --watch

# Ver logs del Workflow
kubectl logs -n argo [WORKFLOW_NAME] -c main -f

# Esperar a que complete (típicamente 30-60 segundos)
```

### 5. Ver el cambio en vivo

```bash
# Opción A: Port-forward
kubectl port-forward -n default svc/app-gitops-service 8080:80 &
open http://localhost:8080

# Opción B: Acceder directamente (en Docker Desktop)
open http://localhost
```

---

## Cómo Activar Webhooks Automáticos de GitHub

Ver [GUIA-WEBHOOK-GITHUB.md](GUIA-WEBHOOK-GITHUB.md)

**Resumen**: Usa **ngrok** para exponer tu cluster a internet → Configura webhook en GitHub → ¡Ya es automático!

---

## Archivos Importantes

| Archivo | Función |
|---------|---------|
| `index.html` | Contenido web que ves en el navegador |
| `Dockerfile` | Cómo se compila la imagen Docker |
| `k8s/deployment.yaml` | Cómo Kubernetes ejecuta la app |
| `k8s/service.yaml` | Cómo se expone la app al exterior |
| `eventsource.yaml` | Dónde recibe GitHub webhooks |
| `eventbus.yaml` | Cómo se comunican los eventos |
| `sensor.yaml` | Lógica para disparar Workflows |
| `eventsource-service.yaml` | Cómo se expone el webhook |

---

## Comandos Útiles

```bash
# Ver estado de todo
kubectl get all -n argo
kubectl get all -n default
kubectl get applications -n argocd

# Ver logs
kubectl logs -n argo -l sensor-name=github-sensor -f
kubectl logs -n argo -l eventsource-name=github-eventsource -f

# Ver imágenes en Docker Hub (desde tu navegador)
# https://hub.docker.com/r/adanleon/app-gitops/tags

# Limpiar Workflows viejos
kubectl delete workflow -n argo --all

# Forzar redeploy de la app
kubectl rollout restart deployment/app-gitops -n default

# Ver toda la configuración de un recurso
kubectl get deployment app-gitops -n default -o yaml
kubectl get sensor github-sensor -n argo -o yaml
kubectl get eventsource github-eventsource -n argo -o yaml
```

---

## Diferencias: Local vs Producción

| Aspecto | Local (Docker Desktop) | Producción |
|--------|--------|---------|
| Webhooks de GitHub | Manuales (ngrok) | Automáticos |
| Pull de imágenes | Local | Desde registry remoto |
| Persistencia | Volúmenes locales | PVC o NFS |
| SSL/TLS | ngrok proporciona | Gestión manual |
| Monitoreo | Logs en terminal | Prometheus/Grafana |
| Escalabilidad | 1 réplica | Múltiples replicas |

---

## Entender el Flujo (Arquitectura)

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. TÚ EDITAS index.html O Dockerfile                            │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. Ejecutas: git add + git commit + git push                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. GitHub envía webhook (manual en local, automático en prod)   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 4. Argo Events (EventSource) recibe el webhook                  │
│    y publica un evento en el EventBus (NATS)                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 5. Argo Sensor escucha el evento y activa triggers              │
│    Crea un Workflow de Argo                                     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 6. Argo Workflow ejecuta Kaniko                                 │
│    - Descarga el código de GitHub                              │
│    - Compila Dockerfile con Docker                             │
│    - Sube imagen a Docker Hub (adanleon/app-gitops:latest)    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 7. Kubernetes ve que Deployment solicita imagen :latest         │
│    con imagePullPolicy: Always                                  │
│    Descarga la nueva imagen de Docker Hub                       │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 8. Kubernetes termina el pod viejo y crea uno nuevo            │
│    con la imagen actualizada                                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 9. Argo CD (opcional) monitorea GitHub y sincroniza si hay      │
│    cambios en k8s/*.yaml                                        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 10. ¡TÚ ABRES EL NAVEGADOR Y VES TU CAMBIO! 🚀               │
└─────────────────────────────────────────────────────────────────┘
```

---

## Próximas Mejoras

1. **Webhooks automáticos**: Configura ngrok (ver guía arriba)
2. **Versionado de imágenes**: Cambiar `latest` a tags numéricos (v1, v2, etc.)
3. **Rollback automático**: Argo CD puede revertir cambios fallidos
4. **Testing automático**: Agregar tests en el Workflow antes de compilar
5. **Notificaciones**: Configurar Slack/Email para notificar cambios
6. **Monitoreo**: Agregar Prometheus + Grafana para métricas
7. **Multi-environment**: Staging + Producción con Argo CD

---

## Troubleshooting

### El Workflow falla
```bash
kubectl logs [WORKFLOW_NAME] -n argo -c main
# Busca errores de compilación o credenciales
```

### La imagen no se actualiza
```bash
kubectl rollout restart deployment/app-gitops -n default
# Fuerza a Kubernetes que recree los pods
```

### El webhook no llega
```bash
# Verificar que el EventSource está escuchando
kubectl logs -n argo -l eventsource-name=github-eventsource -f

# Verificar endpoints del servicio
kubectl get endpoints -n argo github-eventsource-service
```

### La app no es accesible
```bash
kubectl port-forward -n default svc/app-gitops-service 8080:80
open http://localhost:8080
```

---

## Contacto / Preguntas

Revisa los archivos:
- [ARQUITECTURA.md](ARQUITECTURA.md) - Explicación detallada de cada componente
- [GUIA-WEBHOOK-GITHUB.md](GUIA-WEBHOOK-GITHUB.md) - Cómo configurar webhooks automáticos
