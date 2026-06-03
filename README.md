# Padilla Store 🛍️💎

> **Tu destino premium para joyería y accesorios de celular en El Salvador.**  
> E-commerce PWA de alto rendimiento construido con React, Vite y Supabase.

---

## 🌟 Características Principales

- **📱 Catálogo Dinámico:** Separación en colecciones de *Tecnología* y *Joyería*.
- **⚡ Altísimo Rendimiento:** Carga diferida de imágenes (Lazy Loading), división de código y optimización de assets para métricas de Web Vitals perfectas.
- **🛒 Carrito de Compras Persistente:** Almacenamiento local para sesiones de invitados y sincronización con base de datos para usuarios autenticados.
- **🔒 Panel Administrativo Protegido:** Gestión de inventario, categorías, mensajes y configuración del sistema directamente desde la app.
- **🤖 SEO Automático:** Inyección de esquemas JSON-LD estructurados (`LocalBusiness`, `WebSite`, `Product`) dinámicamente y sitemap autogenerado.
- **♿ Accesibilidad AAA:** Navegación por teclado impecable, control de foco (`FocusLock`) en modales y atributos semánticos.

---

## 🚀 Tecnologías y Stack

* **Frontend:** React 19, React Router v7, Tailwind CSS v4
* **Build Tool:** Vite
* **Backend as a Service (BaaS):** Supabase (PostgreSQL, Auth, Edge Functions)
* **SEO & Meta Tags:** React Helmet Async
* **Validación de Formularios:** Cloudflare Turnstile
* **Testing:** Cypress (E2E) & Vitest (Unidad)

---

## ⚙️ Requisitos Previos

Asegúrate de tener instalados:
- Node.js (v18.0.0 o superior)
- npm (v9.0.0 o superior)
- Una cuenta en [Supabase](https://supabase.com)

---

## 🛠️ Instalación y Configuración Local

1. **Clonar el repositorio:**
   ```bash
   git clone https://github.com/padilla-store/tienda.git
   cd tienda
   ```

2. **Instalar dependencias:**
   ```bash
   npm install
   ```

3. **Configurar variables de entorno:**  
   Duplica el archivo `.env.example` y renómbralo a `.env`. Rellena las credenciales de tu proyecto Supabase:
   ```env
   VITE_SUPABASE_URL=tu_supabase_url
   VITE_SUPABASE_ANON_KEY=tu_supabase_anon_key
   VITE_SITE_URL=http://localhost:5173
   VITE_TURNSTILE_SITE_KEY=tu_clave_de_sitio_turnstile
   ```

4. **Ejecutar servidor de desarrollo:**
   ```bash
   npm run dev
   ```

---

## 📦 Scripts Disponibles

En el directorio del proyecto puedes ejecutar:

| Comando | Descripción |
| :--- | :--- |
| `npm run dev` | Inicia el servidor de desarrollo local. |
| `npm run build` | Compila la aplicación para producción e inyecta el Sitemap dinámico. |
| `npm run preview` | Previsualiza el build de producción localmente. |
| `npm run lint` | Analiza el código con ESLint para encontrar problemas. |
| `npm run test` | Ejecuta pruebas unitarias con Vitest. |
| `npm run test:e2e` | Ejecuta Cypress para pruebas End-to-End. |

---

## 🔐 Seguridad y Despliegue

Este proyecto cuenta con un archivo `vercel.json` preconfigurado con políticas de seguridad estrictas (CSP, X-Frame-Options, HSTS). 
Para desplegar:
1. Conecta este repositorio en tu cuenta de **Vercel**.
2. Añade todas las variables de entorno requeridas en la configuración de Vercel.
3. El build se ejecutará automáticamente usando el comando `npm run build`.

---

## 📞 Contacto y Soporte

- **WhatsApp:** +503 7486-6909
- **Email:** padillastoresv@gmail.com
- **Operaciones:** San Miguel, El Salvador.

---

*Desarrollado y optimizado con 💙 para Padilla Store.*