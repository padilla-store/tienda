# Padilla Store

Tienda en línea de accesorios para celular en El Salvador. Encuentra los mejores cases, protectores de pantalla, cargadores, audífonos, cables, soportes y más.

## Arquitectura y Tecnologías
- **Frontend:** React 19, Vite 6, Tailwind CSS v4, Framer Motion
- **Backend/Base de Datos:** Supabase (Auth, Database, Storage)
- **Routing:** React Router DOM

## Requisitos Previos
- Node.js (v18+)
- npm (v9+)
- Proyecto de Supabase configurado

## Instalación y Configuración

1. Instalar dependencias:
   ```bash
   npm install
   ```

2. Configurar variables de entorno:
   - Copia `.env.example` a `.env`
   - Configura las variables correspondientes.

3. Iniciar entorno de desarrollo local:
   ```bash
   npm run dev
   ```

## Estructura de Carpetas

- `src/components`: Componentes UI reutilizables
- `src/pages`: Páginas completas
- `src/services`: Servicios de conexión
- `src/context`: React Context
- `src/hooks`: Custom Hooks de React
- `src/utils`: Utilidades generales
- `src/types`: Definiciones de Tipos o JSDoc

## Despliegue
Este proyecto está configurado para desplegarse en Vercel ejecutando el comando `npm run build`.