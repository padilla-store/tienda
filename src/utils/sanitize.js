// ──────────────────────────────────────────────────────────────
// SANITIZACIÓN DE INPUTS Y URLS
// ──────────────────────────────────────────────────────────────
// Primera línea de defensa contra XSS en el frontend.
// NO reemplaza la sanitización server-side (RLS + triggers en
// Supabase), pero reduce la superficie de ataque en renders.
//
// DOMPurify se usa para HTML porque es el estándar de la industria.
// Las funciones de URL añaden validación de protocolo para evitar
// ataques `javascript:` y data URIs maliciosos.
// ──────────────────────────────────────────────────────────────
import DOMPurify from 'dompurify';

/**
 * Sanitiza texto de input del usuario.
 * Elimina TODO el HTML — no permite ni <b> ni nada.
 * Se usa antes de enviar datos al servidor (contacto, notas, etc.)
 * y al renderizar contenido del usuario.
 */
export const sanitizeInput = (input) => {
  if (typeof input !== 'string') return '';
  return DOMPurify.sanitize(input, { ALLOWED_TAGS: [] }).trim();
};

/**
 * Sanitiza una URL. Bloquea protocolos peligrosos (javascript:, data:, vbscript:).
 * Retorna string vacío si la URL es sospechosa — nunca retorna la URL original
 * sin validar para evitar bypasses con mayúsculas/espacios.
 *
 * OJO: no valida que la URL sea alcanzable, solo que el protocolo sea seguro.
 * Imágenes externas siguen dependiendo del CSP en vercel.json.
 */
export const sanitizeUrl = (url) => {
  if (!url || typeof url !== 'string') return '';
  const trimmed = url.trim();
  
  // Permite rutas relativas
  if (trimmed.startsWith('/')) {
    return trimmed;
  }
  
  try {
    const parsed = new URL(trimmed);
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
      return '';
    }
    
    const host = parsed.hostname.toLowerCase();
    const isWhitelisted = 
      host === 'images.unsplash.com' ||
      host === 'lh3.googleusercontent.com' ||
      host.endsWith('.googleusercontent.com') ||
      host === 'via.placeholder.com' ||
      host === 'placehold.co' ||
      host === 'padillastore.com' ||
      host.endsWith('.supabase.co') ||
      host === 'localhost' ||
      host === '127.0.0.1';
      
    if (isWhitelisted) {
      return trimmed;
    }
  } catch {
    // URL malformada
  }
  
  return '';
};

/**
 * Valida formato UUID v4. Se usa para validar IDs antes de
 * enviarlos a Supabase — previene inyección en consultas.
 */
export const isValidUUID = (str) => {
  if (!str || typeof str !== 'string') return false;
  return /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(str);
};
