import React, { useState } from 'react';
import { Helmet } from 'react-helmet-async';
import { SITE_NAME, WHATSAPP_NUMBER } from '../config/constants';
import { useSettings } from '@/context/SettingsContext';

const LinksPage = () => {
  const { settings } = useSettings();
  const [copied, setCopied] = useState(false);

  // Fallbacks para renderizado "estático" sin spinners
  const bioHeaderName = settings?.bio_header_name || SITE_NAME;
  const bioName = settings?.bio_name || SITE_NAME;
  const bioDescription = settings?.bio_description || 'Accesorios tecnológicos, bisutería fina de acero y plata en San Miguel. Entrega a domicilio en 24h.';
  const bioImageUrl = settings?.bio_image_url || '/logo.svg';
  
  // Por defecto (si no ha cargado settings), usar un array vacío.
  // Cuando cargue, se filtran los que estén activos.
  const bioLinks = (settings?.bio_links || []).filter(link => link.is_active);

  const copyLink = (e) => {
    e.preventDefault();
    navigator.clipboard.writeText(window.location.href).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2500);
    });
  };

  const openWhatsAppHandler = (phone, url, e) => {
    // Si la url ya tiene api.whatsapp, simplemente redirige. 
    // Si es un id especial de whatsapp, formatea el teléfono.
    e.preventDefault();
    const cleanPhone = phone ? phone.replace(/\D/g, '') : (WHATSAPP_NUMBER ? WHATSAPP_NUMBER.replace(/\D/g, '') : '50374866909');
    
    const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
    if (isMobile) {
      window.location.assign(`whatsapp://send?phone=${cleanPhone}`);
    } else {
      window.open(url || `https://api.whatsapp.com/send?phone=${cleanPhone}`, '_blank');
    }
  };

  return (
    <>
      <Helmet>
        <title>{bioName} | Links</title>
        <meta name="description" content={bioDescription} />
        <meta property="og:title" content={`${bioName} | Links`} />
        <meta property="og:description" content={bioDescription} />
        <meta property="og:image" content={bioImageUrl} />
        <meta property="og:type" content="profile" />
        <meta name="twitter:card" content="summary_large_image" />
        <meta name="twitter:title" content={`${bioName} | Links`} />
        <meta name="twitter:description" content={bioDescription} />
        <meta name="twitter:image" content={bioImageUrl} />
        <link rel="canonical" href={typeof window !== 'undefined' ? window.location.href : 'https://padillastore.com/links'} />
        
        {/* Schema.org JSON-LD para ProfilePage / Organization */}
        <script type="application/ld+json">
          {JSON.stringify({
            "@context": "https://schema.org",
            "@type": "ProfilePage",
            "mainEntity": {
              "@type": "Organization",
              "name": bioName,
              "description": bioDescription,
              "image": bioImageUrl,
              "sameAs": bioLinks.filter(link => !link.id.includes('whatsapp') && !link.id.includes('location')).map(link => link.url)
            }
          })}
        </script>
        <style>{`
          .links-page-container {
            font-family: 'Plus Jakarta Sans', sans-serif;
            background: linear-gradient(180deg, #faf5ff, #f3e8ff);
            min-height: max(884px, 100dvh);
            color: #32323b;
          }
        `}</style>
      </Helmet>

      <div className="links-page-container flex flex-col items-center w-full">
        {/* TopAppBar */}
        <header className="sticky top-0 z-50 flex items-center justify-between px-6 py-3 max-w-lg mx-auto w-full bg-[#faf5ff]/60 backdrop-blur-2xl rounded-full mt-4 shadow-[0_8px_32px_rgba(50,50,59,0.06)] border-none">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-full flex items-center justify-center shadow-md overflow-hidden bg-white border border-[#7c3aed]/20">
              <img src={bioImageUrl} alt="Icon" className="w-full h-full object-cover" />
            </div>
            <span className="text-lg font-bold text-[#32323b] tracking-[-0.02em]">{bioHeaderName}</span>
          </div>
          <button
            onClick={copyLink}
            className="text-[#7c3aed] hover:opacity-80 transition-opacity active:scale-95 duration-200"
          >
            <span className="material-symbols-outlined" style={{ fontVariationSettings: '"FILL" 0, "wght" 400, "GRAD" 0, "opsz" 24' }}>share</span>
          </button>
        </header>

        <main className="w-full max-w-lg px-6 pt-12 pb-24 flex flex-col items-center relative">
          {/* Profile Section */}
          <div className="relative mb-8 flex flex-col items-center text-center">
            <div className="w-32 h-32 rounded-full p-1 bg-gradient-to-tr from-[#7c3aed] to-[#a78bfa] shadow-xl mb-6">
              <div
                className="w-full h-full rounded-full overflow-hidden border-4 flex items-center justify-center bg-white"
                style={{ borderColor: 'white' }}
              >
                <img
                  alt="Profile Headshot"
                  className="w-full h-full object-cover"
                  src={bioImageUrl}
                />
              </div>
            </div>
            <h1 className="text-3xl font-extrabold tracking-[-0.03em] mb-2 text-[#32323b]">{bioName}</h1>
            <p className="text-[#5f5e68] leading-relaxed max-w-xs font-medium">
              {bioDescription}
            </p>
          </div>

          {/* Social Links Cluster */}
          <div className="w-full space-y-4">
            {bioLinks.map((link) => {
              const isWhatsapp = link.id === 'whatsapp' || link.url?.includes('whatsapp');
              return (
                <a
                  key={link.id}
                  className="group flex items-center justify-between px-4 py-3 bg-white rounded-full shadow-[0_4px_20px_rgba(50,50,59,0.04)] hover:shadow-[0_8px_32px_rgba(50,50,59,0.08)] transition-all duration-300 active:scale-95"
                  href={isWhatsapp ? '#' : link.url}
                  onClick={isWhatsapp ? (e) => openWhatsAppHandler(settings?.contact_phone, link.url, e) : undefined}
                  target={isWhatsapp ? undefined : "_blank"}
                  rel={isWhatsapp ? undefined : "noopener noreferrer"}
                >
                  <div className="flex items-center gap-4">
                    <div className="w-12 h-12 rounded-full bg-[#f5f3ff] flex items-center justify-center text-[#7c3aed]">
                      <i className={`${link.icon} text-2xl ${link.iconColor || ''}`}></i>
                    </div>
                    <div className="flex flex-col text-left">
                      <span className="font-bold text-[#32323b] text-[15px]">{link.name}</span>
                    </div>
                  </div>
                  <span className="material-symbols-outlined text-[#b2b1bc] group-hover:text-[#7c3aed] transition-colors">arrow_forward_ios</span>
                </a>
              );
            })}

            {(!settings && bioLinks.length === 0) && (
              <div className="text-center text-sm text-slate-500 italic mt-8">Cargando enlaces...</div>
            )}
          </div>
        </main>

        {/* Footer */}
        <footer className="flex flex-col items-center justify-center w-full mt-auto pb-8 pt-4 bg-transparent text-center">
          <div className="w-full text-center px-6">
            <a 
              href="https://www.confeccionesliss.com/" 
              target="_blank" 
              rel="noopener noreferrer" 
              className="inline-block hover:opacity-80 transition-opacity"
            >
              <code 
                className="font-mono bg-[#e3e1ed]/50 backdrop-blur-md shadow-[0_4px_12px_rgba(50,50,59,0.05)] border border-[#b2b1bc]/30 py-1.5 px-3 rounded-full text-[#7a7a84] inline-block text-xs"
              >
                &lt;<span className="text-[#7c3aed] font-bold">Patrocinado</span> <span className="text-pink-500 font-medium ml-1">por</span>=<span className="font-semibold bg-gradient-to-r from-[#7c3aed] to-pink-500 bg-clip-text text-transparent">"Confecciones Liss"</span> /&gt;
              </code>
            </a>
          </div>
        </footer>

        {/* Toast Modal for Copy Link */}
        <div
          className={`fixed bottom-10 left-1/2 transform -translate-x-1/2 bg-[#0e0e12] text-[#9e9ca2] px-6 py-3 rounded-full shadow-2xl text-sm font-semibold z-[110] transition-all duration-300 flex items-center gap-2 border border-white/10 ${
            copied ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4 pointer-events-none'
          }`}
        >
          <i className="fa-solid fa-check-circle text-[#10b981] text-lg"></i>
          <span>Enlace copiado</span>
        </div>
      </div>
    </>
  );
};

export default LinksPage;
