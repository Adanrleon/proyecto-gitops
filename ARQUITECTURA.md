# Arquitectura del Proyecto GitOps

## 🎯 Objetivo Final
Cuando hagas un cambio en el código y ejecutes `git push`, el cambio debe desplegarse automáticamente sin que hagas nada más.

---

## 📋 Componentes y su Función

### 1. **Docker & Dockerfile**
- **Archivo**: `Dockerfile`
- **Función**: Define cómo se construye la imagen de nuestra aplicación
- **En nuestro caso**: Usa nginx:alpine y copia el `index.html` dentro
- **Resultado**: Imagen Docker que sirve la página web

```
index.html → Dockerfile → Imagen Docker → Kaniko (compila)
```

---

### 2. **Kubernetes - Deployment**
- **Archivo**: `k8s/deployment.yaml`
- **Función**: Define cómo debe correrse nuestra aplicación en Kubernetes
- **Qué hace**:
  - Especifica que queremos 1 réplica (una copia) de la app
  - Dice qué imagen usar (`adanleon/app-gitops:latest`)
  - Expone el puerto 80
- **Resultado**: La aplicación está corriendo dentro del cluster

---

### 3. **Kubernetes - Service**
- **Archivo**: `k8s/service.yaml`
- **Función**: Expone la aplicación al exterior (a tu navegador)
- **Tipo**: LoadBalancer (en Docker Desktop, lo expone en localhost)
- **Resultado**: Puedes acceder a la app en `http://localhost`

---

### 4. **Argo Events - EventBus**
- **Archivo**: `eventbus.yaml`
- **Función**: Sistema de mensajería para comunicar eventos
- **En nuestro caso**: NATS (sistema de cola de mensajes)
- **Resultado**: Todos los componentes de Argo Events pueden comunicarse

```
GitHub Webhook → EventSource → EventBus → Sensor
```

---

### 5. **Argo Events - EventSource**
- **Archivo**: `eventsource.yaml`
- **Función**: Escucha eventos externos (webhooks de GitHub)
- **Qué hace**:
  - Abre un puerto (12000)
  - Espera a que GitHub envíe un webhook cuando haces push
  - Cuando lo recibe, crea un evento en el EventBus
- **Requisito**: GitHub debe estar configurado para enviar webhooks a tu cluster
- **Resultado**: El cluster se entera cuando haces cambios en GitHub

---

### 6. **Argo Events - Sensor**
- **Archivo**: `sensor.yaml`
- **Función**: Escucha eventos del EventBus y ejecuta acciones
- **Qué hace cuando recibe un evento**:
  1. Detecta que hubo un evento en el webhook de GitHub
  2. Crea automáticamente un Workflow de Argo para compilar la nueva imagen
  3. Pasa información al Workflow (cuál es la rama, de qué repo, dónde guardar la imagen, etc.)
- **Resultado**: Se ejecuta automáticamente el proceso de compilación

---

### 7. **Argo Workflows - Workflow (via Kaniko)**
- **Archivo**: `sensor.yaml` (contiene la definición del Workflow)
- **Función**: Automatiza los pasos técnicos de compilación
- **Qué hace**:
  1. Descarga el código de tu repositorio GitHub
  2. Usa Kaniko para compilar la imagen Docker
  3. Sube la imagen compilada a Docker Hub
  4. La nueva imagen queda lista en Docker Hub
- **Resultado**: Nueva imagen Docker compilada y lista en el registry

---

### 8. **Argo CD** (Configuración manual después)
- **Función**: Monitorea tu repositorio GitHub
- **Qué hace cuando ve cambios**:
  1. Se conecta a tu repositorio
  2. Lee los YAML de Kubernetes (`k8s/*.yaml`)
  3. Si el Deployment dice que use `adanleon/app-gitops:latest`, lo compara con lo que está corriendo
  4. Si hay diferencia, actualiza Kubernetes automáticamente
- **Resultado**: Kubernetes siempre ejecuta la versión más reciente

---

## 🔄 Flujo Completo de Actualización

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. Haces cambio en index.html y ejecutas git push              │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. GitHub envía webhook a tu cluster                            │
│    (a la dirección del EventSource en el puerto 12000)         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. EventSource recibe webhook y publica evento en EventBus      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 4. Sensor escucha evento, ve que hay cambios en GitHub          │
│    y crea automáticamente un Workflow                           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 5. Workflow (Kaniko) ejecuta:                                   │
│    - Descarga código de GitHub                                  │
│    - Compila imagen Docker                                      │
│    - Sube imagen a Docker Hub (adanleon/app-gitops:latest)     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 6. Argo CD monitorea GitHub y ve cambios                        │
│    Si deployment.yaml dice usar "latest", la nueva imagen       │
│    está lista, así que Kubernetes la descarga y la ejecuta      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 7. TÚ ABRES EL NAVEGADOR EN http://localhost                   │
│    Y VES TU CAMBIO DESPLEGADO AUTOMÁTICAMENTE ✅               │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔑 Datos Importantes

| Componente | Namespace | Función |
|-----------|-----------|---------|
| Kubernetes Deployment | default | Ejecuta la aplicación web |
| Argo Events | argo-events | Escucha webhooks de GitHub |
| Argo Workflows | argo | Compila la imagen |
| Argo CD | argocd | Sincroniza con GitHub |

---

## 📝 Próximos Pasos

1. **Aplicar la configuración a Kubernetes** (ya hecho)
2. **Configurar GitHub Webhooks** (para que envíe eventos)
3. **Hacer un cambio de prueba** en index.html
4. **Ejecutar git push** y observar que todo se actualiza automáticamente
5. **Validar en el navegador** que el cambio está visible

---

## ⚠️ Problemas Comunes y Soluciones

### Problema: "El Workflow falla"
- **Causa usual**: Las credenciales de Docker Hub no están bien configuradas
- **Solución**: Verificar que el Secret `docker-config` existe en el namespace `argo`

### Problema: "El webhook no llega"
- **Causa usual**: GitHub no conoce la dirección de tu cluster
- **Solución**: Configurar GitHub Webhook apuntando a la IP/dominio de tu EventSource

### Problema: "La imagen se compila pero Kubernetes no la actualiza"
- **Causa usual**: Argo CD no está sincronizando o el deployment no usa "latest"
- **Solución**: Verificar que Argo CD esté habilitado y que deployment.yaml use imagePullPolicy: Always

