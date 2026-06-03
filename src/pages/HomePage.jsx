import { Link } from 'react-router-dom';
import { useSettings } from '@/context/SettingsContext';
import ProductCard from '@/components/ProductCard';
import { useProducts } from '@/hooks/useProducts';
import { Helmet } from 'react-helmet-async';
import { BASE_URL, SITE_NAME, FOUNDER_NAME } from '@/config/constants';
import { useEffect, useRef, useState, useCallback } from 'react';
import lottie from 'lottie-web';
import StructuredData, { createFAQSchema, createBreadcrumbSchema, createLocalBusinessSchema, createWebSiteSchema } from '@/components/StructuredData';
import { useModal } from '@/hooks/useModal';
import { useBodyScrollLock } from '@/hooks/useBodyScrollLock';

const FALLBACK_HERO_IMG = 'https://lh3.googleusercontent.com/aida-public/AB6AXuC2utPyicqN_kUOlg_KMlF2AA1cqvefgwLmDWPoStz9OLaD7KrTngV5Z330vaSwZf_Ad-Va2vFoDwEj4lBCqcQF_O4oZyxM7HrmORUD6zpvKgOA0z6fzdO1HZ6FDAI6BOHCIeCRWCSiZu8u9TJ79hmbPK0DLNbKphBr3g-E6flprEImzUkY0AIKfn31wWv1HhkMfxaEYUmAZAXARQ2wqx1GSswK_9grPpT5H48RI4n8rkAexrzyjQuq7HR3Lyfy-voEibkI1gYHm5I';

const ANIMATION_PATH = '/new-animation.json';

// ── Datos FAQ (del TXT maestro) ──────────────────────────
const FAQ_ITEMS = [
  {
    question: '¿Los productos de Padilla Store son originales?',
    answer: 'Sí. En Padilla Store comercializamos productos de calidad con garantía local. Cada artículo es seleccionado cuidadosamente para garantizar que nuestros clientes reciban productos auténticos y duraderos. Si tienes dudas sobre un producto específico, contáctanos directamente por WhatsApp y te brindamos toda la información.'
  },
  {
    question: '¿De qué material está elaborada la bisutería?',
    answer: 'Nuestra bisutería fina está elaborada principalmente en acero y plata. Estos materiales ofrecen alta durabilidad, resistencia y un acabado elegante. Todos nuestros anillos, collares y aretes están diseñados para uso diario manteniendo su brillo y calidad.'
  },
  {
    question: '¿La bisutería de Padilla Store se oxida?',
    answer: 'La bisutería de acero es altamente resistente a la oxidación. Para mantener tus piezas en óptimas condiciones, te recomendamos: no aplicar perfumes directamente sobre la joyería, evitar el uso durante actividades físicas intensas, y limpiar las piezas con paños ecológicos suaves.'
  },
  {
    question: '¿Cuáles son los métodos de pago disponibles?',
    answer: 'Aceptamos transferencia bancaria a Banco Agrícola, transferencia a BAC, y pago en efectivo contra entrega. El proceso de pago es sencillo y seguro: seleccionas tu producto, nos contactas por WhatsApp, te enviamos los datos de pago y procesamos tu orden de inmediato.'
  },
  {
    question: '¿Cuánto cuesta el envío y cuánto tarda la entrega?',
    answer: 'El costo de envío va desde $1.00 hasta $3.00, dependiendo de la ubicación. El tiempo estimado de entrega es de 24 horas. Realizamos entregas a domicilio en San Miguel y zonas aledañas con motorista propio, lo que nos permite un mayor control del proceso y comunicación directa contigo.'
  },
  {
    question: '¿Cuál es la política de cambios y devoluciones?',
    answer: 'Los cambios pueden solicitarse dentro de los primeros 5 días posteriores a la compra. No realizamos devoluciones en efectivo; cuando corresponda, se otorga saldo a favor para futuras compras. Si tu pedido llega dañado, envíanos fotografías o videos, validamos la incidencia y realizamos el reemplazo correspondiente.'
  },
  {
    question: '¿Cómo puedo realizar un pedido en Padilla Store?',
    answer: 'El proceso es muy sencillo: (1) Selecciona el producto que deseas. (2) Inicia una conversación con nosotros por WhatsApp. (3) Te calculamos el costo de envío. (4) Te facilitamos los datos de pago. (5) Procesamos tu orden. (6) Coordinamos la entrega a domicilio. (7) Recibes tu comprobante PDF y factura electrónica.'
  }
];

export default function HomePage() {
  const { products: homeProducts, loading } = useProducts({ limit: 5 });
  const { settings } = useSettings();

  const [isCatalogModalOpen, setIsCatalogModalOpen] = useState(false);
  const { modalRef, handleOverlayClick } = useModal({
    isOpen: isCatalogModalOpen,
    onClose: () => setIsCatalogModalOpen(false)
  });
  useBodyScrollLock(isCatalogModalOpen);

  // Desktop animation ref
  const lottieRef = useRef(null);
  const animInstance = useRef(null);

  // Mobile animation ref
  const lottieMobileRef = useRef(null);
  const animMobileInstance = useRef(null);

  // Load a lottie animation into a container
  const loadAnim = useCallback((container, path) => {
    if (!container) return null;
    return lottie.loadAnimation({
      container,
      renderer: 'svg',
      loop: true,
      autoplay: true,
      path,
    });
  }, []);

  // Initialize animation on mount
  useEffect(() => {
    animInstance.current = loadAnim(lottieRef.current, ANIMATION_PATH);
    animMobileInstance.current = loadAnim(lottieMobileRef.current, ANIMATION_PATH);

    return () => {
      animInstance.current?.destroy();
      animMobileInstance.current?.destroy();
    };
  }, [loadAnim]);



  useEffect(() => {
    const observerOptions = {
      root: null,
      rootMargin: '0px',
      threshold: 0.1
    };

    const observer = new IntersectionObserver((entries, observer) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('visible');
          observer.unobserve(entry.target);
        }
      });
    }, observerOptions);

    const elements = document.querySelectorAll('.fade-in-up');
    elements.forEach(element => {
      observer.observe(element);
    });

    return () => {
      elements.forEach(element => {
        observer.unobserve(element);
      });
    };
  }, []);

  // Estado para FAQ abierta
  const [openFaq, setOpenFaq] = useState(null);

  return (
    <>
      <Helmet>
        <title>Cases para Celular, Cargadores y Joyeria de Acero | Padilla Store — Envío 24h San Miguel</title>
        <meta name="description" content="Padilla Store: tienda en línea en San Miguel, El Salvador. Bisutería fina de acero y plata, fundas para celular, cargadores, audífonos y electrónicos. Entrega a domicilio en 24 horas. Compra fácil por WhatsApp." />
        <meta property="og:title" content="Padilla Store — Accesorios para Celular, Bisutería Fina y Electrónicos en San Miguel" />
        <meta property="og:description" content="Tienda en línea de accesorios tecnológicos, bisutería de acero y plata con entrega a domicilio en 24h en San Miguel, El Salvador." />
        <meta property="og:image" content={settings?.hero_image_url || FALLBACK_HERO_IMG} />
        <meta property="og:url" content={BASE_URL} />
        <meta property="og:type" content="website" />
        <meta property="og:site_name" content={SITE_NAME} />
        <link rel="canonical" href={`${BASE_URL}/`} />
        <link rel="preload" as="image" href={settings?.hero_image_url || FALLBACK_HERO_IMG} />
        <style>{`
          @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800;900&display=swap');
          
          @media (prefers-reduced-motion: no-preference) {
            .fade-in-up {
                opacity: 0;
                transform: translateY(20px);
                transition: opacity 0.6s ease-out, transform 0.6s ease-out;
            }
            .fade-in-up.visible {
                opacity: 1;
                transform: translateY(0);
            }
            @keyframes float {
              0%, 100% { transform: translateY(0); }
              50% { transform: translateY(-12px); }
            }
            .animate-float {
              animation: float 6s ease-in-out infinite;
            }
          }
          @media (prefers-reduced-motion: reduce) {
            .fade-in-up {
                opacity: 1;
                transform: translateY(0);
            }
          }
          
          .main-banner {
            margin-top: calc(-1 * var(--navbar-height));
            padding: calc(var(--space-xl) + var(--navbar-height)) 0px var(--space-xl) 0px;
            background-color: var(--color-background-light);
            background-image: none;
            position: relative;
            overflow: hidden;
            font-family: 'Plus Jakarta Sans', sans-serif;
          }
          .dark .main-banner {
            background-color: var(--color-background-dark);
            background-image: none;
          }
        `}</style>
      </Helmet>

      {/* FAQ Structured Data */}
      <StructuredData data={createFAQSchema(FAQ_ITEMS)} />
      {/* Breadcrumb: Inicio */}
      <StructuredData data={createBreadcrumbSchema([{ name: 'Inicio', url: '/' }])} />
      {/* Site and LocalBusiness Structured Data */}
      <StructuredData data={createWebSiteSchema()} />
      <StructuredData data={createLocalBusinessSchema(settings)} />

      {/* Hero Section — Modern & Executive Redesign */}
      <section className="main-banner relative w-full overflow-hidden">
        {/* Main Hero Container — Spaced and responsive */}
        <div className="max-w-[1440px] mx-auto relative z-[2] w-full px-[20px] md:px-[64px]">
          <div className="flex flex-col lg:flex-row-reverse items-center w-full" style={{ gap: 'var(--space-2xl)' }}>
            {/* Left Column: Typography & Actions (Aligned and Clean) */}
            <div className="w-full lg:w-1/2 flex flex-col justify-center items-center lg:items-start text-center lg:text-left relative z-10">
              {/* Contenedor Tarjeta Liquid Glass para el Título */}
              <div className="w-full bg-white/40 dark:bg-slate-900/40 backdrop-blur-xl border-2 border-dotted border-slate-400/70 dark:border-slate-600/70 rounded-3xl p-6 md:p-8 shadow-2xl shadow-primary/5 relative overflow-hidden mb-6">
                {/* Glow líquido interno */}
                <div className="absolute -right-16 -top-16 w-32 h-32 rounded-full bg-primary/20 blur-3xl pointer-events-none" />
                <div className="absolute -left-16 -bottom-16 w-32 h-32 rounded-full bg-indigo-500/20 blur-3xl pointer-events-none" />

                <h1 className="tracking-tight text-slate-900 dark:text-white w-full lg:w-auto flex flex-col items-stretch mx-auto lg:mx-0 font-bold font-brand text-3xl sm:text-4xl md:text-5xl lg:text-6xl" style={{ lineHeight: 1.15, fontFamily: 'var(--font-brand)' }}>
                  <span className="block font-brand w-full lg:text-balance" style={{ fontFamily: 'var(--font-brand)' }}>
                    {settings?.hero_title || "Protege tu celular. Luce tu estilo."}
                  </span>
                  <span className="block text-base md:text-xl lg:text-2xl mt-3 font-sans font-medium text-slate-500 dark:text-slate-400">
                    {settings?.hero_subtitle || "Cases premium, cargadores rápidos y joyería de acero en San Miguel"}
                  </span>
                </h1>
              </div>

              {/* Mobile Animation */}
              <div className="lg:hidden w-full max-w-[340px] aspect-square mx-auto z-[20] relative" style={{ marginTop: 'var(--space-lg)', marginBottom: 'var(--space-lg)' }}>
                <div
                  ref={lottieMobileRef}
                  className="w-full h-full absolute inset-0"
                  aria-label="Animación decorativa de Padilla Store"
                  role="img"
                />
              </div>

              {/* Subtítulo — Nivel corporativo con SEO */}
              <p className="text-slate-500 dark:text-slate-400 font-normal italic mb-8 w-full px-6 md:px-8" style={{ fontSize: 'var(--text-base)', lineHeight: 1.6 }}>
                {settings?.hero_description || "Accesorios de alta gama para tu celular, cargadores de carga rápida y joyería fina de acero y plata para elevar tu estilo diario. Haz tu pedido hoy y recíbelo en menos de 24 horas en San Miguel."}
              </p>

              {/* Botones de Acción de Alta Gama */}
              <div className="flex flex-row w-full" style={{ gap: 'var(--space-sm)' }}>
                <Link
                  to="/links"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex-1 inline-flex items-center justify-center bg-white/50 dark:bg-slate-950/40 hover:bg-slate-100/80 dark:hover:bg-slate-900/60 text-slate-800 dark:text-slate-200 border border-slate-200/80 dark:border-slate-800/80 shadow-sm hover:scale-[1.02] active:scale-[0.98] transition-all duration-300 cursor-pointer rounded-xl backdrop-blur-md text-center"
                  style={{ padding: 'var(--space-md) var(--space-md)', fontSize: 'var(--text-sm)' }}
                >
                  Redes Sociales
                </Link>
                <Link
                  to="/contact"
                  className="flex-1 inline-flex items-center justify-center bg-slate-900 dark:bg-white text-white dark:text-slate-900 hover:bg-slate-800 dark:hover:bg-slate-100 font-bold rounded-xl hover:scale-[1.02] shadow-lg shadow-slate-900/10 dark:shadow-white/5 active:scale-[0.98] transition-all duration-300 cursor-pointer border border-transparent"
                  style={{ padding: 'var(--space-md) var(--space-md)', fontSize: 'var(--text-sm)', gap: 'var(--space-xs)' }}
                >
                  Contáctanos
                  <span className="material-symbols-outlined" style={{ fontSize: 'var(--icon-sm)' }} aria-hidden="true">chat</span>
                </Link>
              </div>
            </div>

            {/* Animation Column (Left logically due to flex-row-reverse) */}
            <div className="hidden lg:flex w-full lg:w-1/2 p-0 justify-start">
              <div className="relative z-[20] mt-[30px] lg:mt-0 w-full max-w-[500px] aspect-square" style={{ minHeight: '350px' }}>
                <div
                  ref={lottieRef}
                  className="w-full h-full absolute inset-0"
                  aria-label="Animación decorativa de Padilla Store"
                  role="img"
                />
              </div>
            </div>
          </div>

          {/* Trust Strip - Modern Floating Card Transition */}
          <div className="mt-10 lg:mt-14 bg-white dark:bg-slate-900/50 backdrop-blur-md rounded-2xl border border-slate-200/60 dark:border-slate-800/60 p-6 lg:p-8 shadow-sm grid grid-cols-2 md:grid-cols-4 gap-x-4 gap-y-8 md:gap-0 text-center md:text-left">
            <div className="flex flex-col md:flex-row items-center md:items-start gap-4 px-4 md:px-6">
              <div className="w-11 h-11 rounded-xl bg-slate-100 dark:bg-slate-900/80 text-primary flex items-center justify-center shrink-0 border border-slate-200/40 dark:border-slate-800/40 shadow-sm">
                <span className="material-symbols-outlined text-[20px]">local_shipping</span>
              </div>
              <div>
                <h2 className="text-sm font-bold text-slate-900 dark:text-white tracking-tight">Entrega a domicilio en 24 horas</h2>
                <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">Envío con motorista propio en San Miguel y zonas aledañas desde $1.00.</p>
              </div>
            </div>

            <div className="flex flex-col md:flex-row items-center md:items-start gap-4 px-4 md:px-6 md:border-l border-slate-200/40 dark:border-slate-800/40">
              <div className="w-11 h-11 rounded-xl bg-slate-100 dark:bg-slate-900/80 text-primary flex items-center justify-center shrink-0 border border-slate-200/40 dark:border-slate-800/40 shadow-sm">
                <span className="material-symbols-outlined text-[20px]">verified</span>
              </div>
              <div>
                <h2 className="text-sm font-bold text-slate-900 dark:text-white tracking-tight">Garantía local en todos los productos</h2>
                <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">Bisutería de acero y plata, fundas, cargadores y accesorios con respaldo directo.</p>
              </div>
            </div>

            <div className="flex flex-col md:flex-row items-center md:items-start gap-4 px-4 md:px-6 md:border-l border-slate-200/40 dark:border-slate-800/40">
              <div className="w-11 h-11 rounded-xl bg-slate-100 dark:bg-slate-900/80 text-primary flex items-center justify-center shrink-0 border border-slate-200/40 dark:border-slate-800/40 shadow-sm">
                <span className="material-symbols-outlined text-[20px]">chat</span>
              </div>
              <div>
                <h2 className="text-sm font-bold text-slate-900 dark:text-white tracking-tight">Compra directa por WhatsApp</h2>
                <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">Atención personalizada con {FOUNDER_NAME}. Proceso sencillo, rápido y sin complicaciones.</p>
              </div>
            </div>

            <div className="flex flex-col md:flex-row items-center md:items-start gap-4 px-4 md:px-6 md:border-l border-slate-200/40 dark:border-slate-800/40">
              <div className="w-11 h-11 rounded-xl bg-slate-100 dark:bg-slate-900/80 text-primary flex items-center justify-center shrink-0 border border-slate-200/40 dark:border-slate-800/40 shadow-sm">
                <span className="material-symbols-outlined text-[20px]">redeem</span>
              </div>
              <div>
                <h2 className="text-sm font-bold text-slate-900 dark:text-white tracking-tight">Empaque protector premium</h2>
                <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">Entregado en caja rígida con logotipo corporativo y papel de seda protector.</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <main className="max-w-[1440px] mx-auto bg-background-light dark:bg-background-dark text-[#1c1b1b] dark:text-slate-100 font-sans">


        {/* Featured Products */}
        <section className="mb-[80px] px-[20px] md:px-[64px] fade-in-up" id="shop">
          <div className="flex justify-between items-end mb-8">
            <h2 className="text-2xl md:text-3xl font-bold tracking-tight text-slate-900 dark:text-white font-brand" style={{ fontFamily: 'var(--font-brand)' }}>Los Más Deseados</h2>
            <button
              onClick={() => setIsCatalogModalOpen(true)}
              className="inline-flex items-center gap-1 px-4 py-1.5 rounded-full text-xs font-bold bg-white dark:bg-slate-900/50 text-slate-700 dark:text-slate-300 border border-slate-200/60 dark:border-slate-800/60 shadow-sm hover:bg-primary hover:text-white hover:border-primary dark:hover:bg-primary dark:hover:border-primary transition-all duration-300 group cursor-pointer"
            >
              Más
              <span className="material-symbols-outlined text-[14px] transition-transform group-hover:translate-x-0.5" aria-hidden="true">arrow_forward</span>
            </button>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4">
            {loading ? (
              <div className="col-span-full py-12 flex justify-center"><div className="animate-spin w-8 h-8 border-4 border-primary border-t-transparent rounded-full"></div></div>
            ) : homeProducts.length > 0 ? (
              homeProducts.map(p => (
                <ProductCard key={p.id} product={p} />
              ))
            ) : (
              <div className="col-span-full py-12 text-center text-slate-500">Pronto llegarán nuevos productos.</div>
            )}
          </div>
        </section>

        {/* ── Sobre Padilla Store (EEAT) ──────────────────────── */}
        <section className="mb-[80px] px-[20px] md:px-[64px] fade-in-up" id="sobre-nosotros">
          <article>
            <h2 className="text-2xl md:text-3xl font-bold tracking-tight text-slate-900 dark:text-white mb-6 text-left font-brand" style={{ fontFamily: 'var(--font-brand)' }}>Sobre Padilla Store</h2>
            <div className="bg-white dark:bg-slate-900/50 border border-slate-200/60 dark:border-slate-800/60 shadow-sm rounded-2xl p-8 md:p-12">
              <div className="grid grid-cols-1 lg:grid-cols-12 gap-10 lg:gap-16">
                {/* Left Column: History & Mission */}
                <div className="lg:col-span-7 space-y-6">
                  <p className="text-[16px] leading-[26px] text-slate-600 dark:text-slate-400">
                    <strong className="text-slate-900 dark:text-white">Padilla Store</strong> es una tienda en línea especializada en la comercialización de accesorios tecnológicos, accesorios para teléfonos celulares, productos electrónicos y bisutería fina. Operamos desde <strong className="text-slate-900 dark:text-white">San Miguel, El Salvador</strong>, bajo la razón social <strong className="text-slate-900 dark:text-white">Padilla S.A. de C.V.</strong>, con un modelo de negocio orientado a facilitar el proceso de compra sin necesidad de desplazamientos.
                  </p>
                  <p className="text-[16px] leading-[26px] text-slate-600 dark:text-slate-400">
                    La empresa fue fundada por <strong className="text-slate-900 dark:text-white">{FOUNDER_NAME}</strong> con el propósito de simplificar la experiencia de compra de productos tecnológicos y accesorios personales. La idea nace al identificar la necesidad de muchas personas de adquirir productos de calidad sin abandonar sus actividades diarias, evitando desplazamientos innecesarios y optimizando el tiempo.
                  </p>

                  <div className="pt-4 border-t border-slate-100 dark:border-slate-800/60">
                    <h3 className="text-[18px] leading-[28px] font-bold text-slate-900 dark:text-white mb-3 font-brand" style={{ fontFamily: 'var(--font-brand)' }}>Nuestra misión</h3>
                    <p className="text-[16px] leading-[26px] text-slate-600 dark:text-slate-400">
                      Facilitar el acceso a productos electrónicos, accesorios tecnológicos y bisutería fina mediante un proceso de compra cómodo, rápido y confiable, permitiendo que nuestros clientes realicen sus compras desde la comodidad de su hogar y reciban sus pedidos en el menor tiempo posible.
                    </p>
                  </div>
                </div>

                {/* Right Column: Differentiators & Values */}
                <div className="lg:col-span-5 space-y-8 lg:border-l lg:border-slate-200/60 lg:dark:border-slate-800/60 lg:pl-10">
                  <div>
                    <h3 className="text-[18px] leading-[28px] font-bold text-slate-900 dark:text-white mb-4 font-brand" style={{ fontFamily: 'var(--font-brand)' }}>¿Por qué elegir Padilla Store?</h3>
                    <ul className="space-y-3 text-[14px] leading-[22px] text-slate-600 dark:text-slate-400">
                      {[
                        { title: 'Atención personalizada', text: 'Comunicación directa con el negocio a través de WhatsApp.' },
                        { title: 'Entrega en 24 horas', text: 'Motorista propio para mayor control y seguimiento local.' },
                        { title: 'Garantía local', text: 'Respaldo directo en todos los productos adquiridos.' },
                        { title: 'Empaque premium', text: 'Caja rígida con logotipo corporativo y papel protector.' },
                        { title: 'Comprobante y factura', text: 'Transparencia y formalidad total en cada compra.' },
                      ].map((item, i) => (
                        <li key={i} className="flex items-start gap-2.5">
                          <span className="material-symbols-outlined text-primary text-[18px] mt-0.5 shrink-0" aria-hidden="true">check_circle</span>
                          <span><strong className="text-slate-900 dark:text-white">{item.title}</strong> — {item.text}</span>
                        </li>
                      ))}
                    </ul>
                  </div>

                  <div className="pt-6 border-t border-slate-100 dark:border-slate-800/60">
                    <h3 className="text-[18px] leading-[28px] font-bold text-slate-900 dark:text-white mb-4 font-brand" style={{ fontFamily: 'var(--font-brand)' }}>Nuestros valores</h3>
                    <dl className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                      {[
                        { val: 'Honestidad', desc: 'Transparencia en información, entregas y condiciones.' },
                        { val: 'Servicio', desc: 'Consultas atendidas con enfoque en la solución.' },
                        { val: 'Compromiso', desc: 'Respuestas ágiles ante cada requerimiento.' },
                        { val: 'Confianza', desc: 'Garantía local y contacto personalizado.' },
                      ].map((item, i) => (
                        <div key={i}>
                          <dt className="font-bold text-slate-900 dark:text-white text-[14px]">{item.val}</dt>
                          <dd className="text-[12px] leading-[18px] text-slate-500 dark:text-slate-400 mt-0.5">{item.desc}</dd>
                        </div>
                      ))}
                    </dl>
                  </div>
                </div>
              </div>
            </div>
          </article>
        </section>

        {/* ── Cómo Comprar ──────────────────────────────────── */}
        <section className="mb-[80px] px-[20px] md:px-[64px] fade-in-up" id="como-comprar">
          <h2 className="text-2xl md:text-3xl font-bold tracking-tight text-slate-900 dark:text-white mb-4 text-left font-brand" style={{ fontFamily: 'var(--font-brand)' }}>Cómo comprar en Padilla Store</h2>
          <p className="text-left text-slate-500 dark:text-slate-400 max-w-2xl mb-8 text-sm md:text-base leading-relaxed font-normal italic">
            Comprar en Padilla Store es rápido y sencillo. Todo el proceso se realiza a través de WhatsApp con atención personalizada.
          </p>
          <ol className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-[16px] md:gap-6 list-none p-0 m-0">
            {[
              { step: '01', icon: 'touch_app', title: 'Selecciona tu producto', desc: 'Explora nuestro catálogo y elige los productos que más te gusten.' },
              { step: '02', icon: 'chat', title: 'Escríbenos por WhatsApp', desc: 'Inicia una conversación con nosotros para confirmar tu pedido y calcular el envío.' },
              { step: '03', icon: 'payments', title: 'Realiza tu pago', desc: 'Paga por transferencia a Banco Agrícola, BAC o efectivo contra entrega.' },
              { step: '04', icon: 'package_2', title: 'Recibe en tu domicilio', desc: 'Entregamos en 24 horas en San Miguel con motorista propio. Recibes comprobante PDF y factura electrónica.' },
            ].map(item => (
              <li key={item.step} className="bg-white dark:bg-slate-900/50 border border-slate-200/60 dark:border-slate-800/60 shadow-sm p-6 rounded-2xl flex flex-col items-start text-left gap-4 hover:-translate-y-1 hover:shadow-md transition-all duration-300 relative overflow-hidden group">
                {/* Elegant Subtle Step Number */}
                <span className="absolute top-4 right-6 text-4xl font-extrabold text-slate-400 dark:text-slate-500 select-none font-brand tracking-tight transition-transform group-hover:scale-105 duration-300">
                  {item.step}
                </span>

                {/* Premium Icon Container */}
                <div className="w-12 h-12 rounded-xl bg-slate-50 dark:bg-slate-900 text-primary flex items-center justify-center shrink-0 border border-slate-200/40 dark:border-slate-800/40 shadow-sm transition-colors group-hover:bg-primary/5 dark:group-hover:bg-primary/10">
                  <span className="material-symbols-outlined text-[24px]" aria-hidden="true">{item.icon}</span>
                </div>

                {/* Text Content */}
                <div className="space-y-2">
                  <h3 className="text-[16px] leading-[24px] font-bold text-slate-900 dark:text-white">{item.title}</h3>
                  <p className="text-[14px] leading-[22px] text-slate-500 dark:text-slate-400 font-normal">{item.desc}</p>
                </div>
              </li>
            ))}
          </ol>
        </section>

        {/* ── Cobertura de Envío (SEO Local) ──────────────────── */}
        <section className="mb-[80px] px-[20px] md:px-[64px] fade-in-up" id="cobertura">
          <div className="bg-white dark:bg-slate-900/50 border border-slate-200/60 dark:border-slate-800/60 shadow-sm rounded-2xl p-8 md:p-12">
            <div className="grid grid-cols-1 lg:grid-cols-12 gap-10 lg:gap-16 items-center">
              {/* Left Column: Heading and description */}
              <div className="lg:col-span-5 space-y-4">
                <h2 className="text-2xl md:text-3xl font-bold tracking-tight text-slate-900 dark:text-white font-brand" style={{ fontFamily: 'var(--font-brand)' }}>Cobertura de envío en San Miguel</h2>
                <p className="text-[16px] leading-[26px] text-slate-500 dark:text-slate-400 italic">
                  Padilla Store realiza entregas a domicilio en <strong className="text-slate-900 dark:text-white">San Miguel, municipios cercanos y zonas aledañas</strong>. Nuestro servicio de envío cuenta con motorista propio, lo que garantiza mayor control del proceso, comunicación directa y entrega personalizada.
                </p>
              </div>

              {/* Right Column: Grid metrics */}
              <div className="lg:col-span-7 lg:border-l lg:border-slate-200/60 lg:dark:border-slate-800/60 lg:pl-12">
                <div className="grid grid-cols-2 gap-x-8 gap-y-8 text-left">
                  <div>
                    <div className="text-3xl md:text-4xl font-extrabold text-primary font-sans tracking-tight">24h</div>
                    <p className="text-sm font-semibold text-slate-900 dark:text-white mt-1.5">Tiempo de entrega</p>
                    <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">Estimado para San Miguel y zonas aledañas.</p>
                  </div>
                  <div>
                    <div className="text-3xl md:text-4xl font-extrabold text-primary font-sans tracking-tight">$1–$3</div>
                    <p className="text-sm font-semibold text-slate-900 dark:text-white mt-1.5">Costo de envío</p>
                    <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">Tarifa económica según la ubicación exacta.</p>
                  </div>
                  <div>
                    <div className="text-3xl md:text-4xl font-extrabold text-primary font-sans tracking-tight">Propio</div>
                    <p className="text-sm font-semibold text-slate-900 dark:text-white mt-1.5">Motorista personal</p>
                    <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">Mayor control del proceso y entrega segura.</p>
                  </div>
                  <div>
                    <div className="text-3xl md:text-4xl font-extrabold text-primary font-sans tracking-tight">Directo</div>
                    <p className="text-sm font-semibold text-slate-900 dark:text-white mt-1.5">Chat de WhatsApp</p>
                    <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">Coordinación de entrega y soporte al instante.</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* ── Preguntas Frecuentes (FAQ + Schema) ─────────────── */}
        <section className="mb-[80px] px-[20px] md:px-[64px] fade-in-up" id="preguntas-frecuentes">
          <h2 className="text-2xl md:text-3xl font-bold tracking-tight text-slate-900 dark:text-white mb-4 text-left font-brand" style={{ fontFamily: 'var(--font-brand)' }}>Preguntas frecuentes</h2>
          <p className="text-left text-slate-500 dark:text-slate-400 max-w-2xl mb-8 text-sm md:text-base leading-relaxed font-normal italic">
            Resolvemos las dudas más comunes de nuestros clientes en San Miguel y El Salvador sobre productos, envíos, pagos y garantías.
          </p>

          <div className="space-y-3 w-full">
            {FAQ_ITEMS.map((item, index) => (
              <div key={index} className="bg-white dark:bg-slate-900/50 border border-slate-200/60 dark:border-slate-800/60 shadow-sm rounded-xl overflow-hidden">
                <button
                  type="button"
                  onClick={() => setOpenFaq(openFaq === index ? null : index)}
                  className="w-full flex items-center justify-between p-5 text-left cursor-pointer"
                  aria-expanded={openFaq === index}
                  aria-controls={`faq-answer-${index}`}
                >
                  <h3 className="text-[16px] leading-[24px] font-semibold text-[#1c1b1b] dark:text-white pr-4">{item.question}</h3>
                  <span className={`material-symbols-outlined text-[20px] text-slate-500 transition-transform duration-200 shrink-0 ${openFaq === index ? 'rotate-180' : ''}`} aria-hidden="true">expand_more</span>
                </button>
                <div
                  id={`faq-answer-${index}`}
                  className={`overflow-hidden transition-all duration-300 ${openFaq === index ? 'max-h-96 pb-5' : 'max-h-0'}`}
                  role="region"
                  aria-labelledby={`faq-question-${index}`}
                >
                  <p className="px-5 text-[15px] leading-[24px] text-[#444748] dark:text-slate-400">{item.answer}</p>
                </div>
              </div>
            ))}
          </div>
        </section>
      </main>

      {/* Modal de Catálogos */}
      {isCatalogModalOpen && (
        <div 
          className="fixed inset-0 z-[999] flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm transition-all duration-300 animate-in fade-in"
          onClick={handleOverlayClick}
        >
          <div
            ref={modalRef}
            role="dialog"
            aria-modal="true"
            aria-labelledby="catalog-modal-title"
            className="relative w-full max-w-md bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800/80 rounded-3xl shadow-2xl p-6 md:p-8 animate-in fade-in zoom-in duration-300"
          >
            {/* Botón Cerrar */}
            <button
              onClick={() => setIsCatalogModalOpen(false)}
              className="absolute top-4 right-4 w-8 h-8 flex items-center justify-center rounded-full bg-slate-100 dark:bg-slate-850 text-slate-500 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white transition-colors cursor-pointer border border-transparent"
              aria-label="Cerrar modal"
            >
              <span className="material-symbols-outlined" style={{ fontSize: '20px' }}>close</span>
            </button>

            {/* Encabezado */}
            <div className="text-center mb-6">
              <h3 id="catalog-modal-title" className="text-xl md:text-2xl font-bold text-slate-900 dark:text-white font-brand" style={{ fontFamily: 'var(--font-brand)' }}>
                Nuestros Catálogos
              </h3>
              <p className="text-sm text-slate-500 dark:text-slate-400 mt-2">
                Elige la categoría que deseas explorar hoy
              </p>
            </div>

            {/* Opciones de Catálogo */}
            <div className="flex flex-col gap-4">
              <Link
                to="/catalog-tecnologia"
                onClick={() => setIsCatalogModalOpen(false)}
                className="flex items-center gap-4 p-4 rounded-2xl bg-slate-50 dark:bg-slate-800/30 hover:bg-primary/5 dark:hover:bg-primary/10 border border-slate-100 dark:border-slate-800/60 hover:border-primary/30 dark:hover:border-primary/30 transition-all duration-300 group cursor-pointer"
              >
                <div className="w-12 h-12 rounded-xl bg-primary/10 text-primary flex items-center justify-center shrink-0 group-hover:scale-110 transition-transform duration-300">
                  <span className="material-symbols-outlined text-[24px]">devices</span>
                </div>
                <div className="text-left">
                  <h4 className="font-bold text-slate-900 dark:text-white text-base">Catálogo Tecnología</h4>
                  <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">Cases para celular, cargadores rápidos y accesorios.</p>
                </div>
                <span className="material-symbols-outlined text-slate-400 dark:text-slate-600 ml-auto group-hover:translate-x-1 transition-transform" style={{ fontSize: '18px' }}>arrow_forward</span>
              </Link>

              <Link
                to="/catalog-joyeria"
                onClick={() => setIsCatalogModalOpen(false)}
                className="flex items-center gap-4 p-4 rounded-2xl bg-slate-50 dark:bg-slate-800/30 hover:bg-primary/5 dark:hover:bg-primary/10 border border-slate-100 dark:border-slate-800/60 hover:border-primary/30 dark:hover:border-primary/30 transition-all duration-300 group cursor-pointer"
              >
                <div className="w-12 h-12 rounded-xl bg-primary/10 text-primary flex items-center justify-center shrink-0 group-hover:scale-110 transition-transform duration-300">
                  <span className="material-symbols-outlined text-[24px]">diamond</span>
                </div>
                <div className="text-left">
                  <h4 className="font-bold text-slate-900 dark:text-white text-base">Catálogo Joyería</h4>
                  <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">Bisutería fina en acero y plata de alta durabilidad.</p>
                </div>
                <span className="material-symbols-outlined text-slate-400 dark:text-slate-600 ml-auto group-hover:translate-x-1 transition-transform" style={{ fontSize: '18px' }}>arrow_forward</span>
              </Link>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
