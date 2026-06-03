describe('Flujo de Checkout y WhatsApp', () => {
  beforeEach(() => {
    // Interceptar llamadas de GET products
    cy.intercept('GET', '**/rest/v1/products*', {
      statusCode: 200,
      body: [
        {
          id: 'f53c6a4a-cfe0-47ee-8595-7fbdff21de59',
          created_at: '2026-05-22T22:42:33.80258+00:00',
          name: 'Funda Aura Case Magnética - iPhone 15 Pro',
          slug: 'funda-aura-case-iphone-15-pro',
          description: 'Funda con tecnología MagSafe, bordes elevados para protección de cámara.',
          price: 14.99,
          old_price: 19.99,
          offer_ends_at: null,
          offer_starts_at: null,
          is_active: true,
          category: 'accesorios-celular',
          images: [ 'https://via.placeholder.com/300' ],
          image_path: null,
          tags: [ 'Premium', 'Nuevo' ],
          updated_at: '2026-05-22T22:42:33.80258+00:00',
          category_id: '64c4651b-b6c5-42ec-a128-c548e74b20e4',
          categories: {
            name: 'Accesorios de Celular',
            icon: 'phone_iphone',
            slug: 'accesorios-celular'
          }
        }
      ]
    }).as('getProducts');

    // Interceptar llamadas de GET categories
    cy.intercept('GET', '**/rest/v1/categories*', {
      statusCode: 200,
      body: [
        {
          id: '64c4651b-b6c5-42ec-a128-c548e74b20e4',
          created_at: '2026-05-22T22:42:33.80258+00:00',
          name: 'Accesorios de Celular',
          slug: 'accesorios-celular',
          description: 'Fundas, protectores, cargadores y más para tu smartphone.',
          icon: 'phone_iphone',
          featured: true
        }
      ]
    }).as('getCategories');

    // Interceptar llamadas de GET store_settings
    cy.intercept('GET', '**/rest/v1/store_settings*', {
      statusCode: 200,
      body: [
        {
          id: '9976e75a-0a0a-4b16-8dad-58aac0cc47fc',
          created_at: '2026-05-22T22:42:33.80258+00:00',
          updated_at: '2026-05-22T22:42:33.80258+00:00',
          hero_title: "Padilla's Store",
          hero_subtitle: 'Tu destino premium para joyería y accesorios de celular en El Salvador.',
          hero_image_url: 'https://via.placeholder.com/800x400',
          contact_email: 'padillastoresv@gmail.com',
          contact_phone: '+50373117312',
          social_facebook: null,
          social_instagram: null,
          social_tiktok: null
        }
      ]
    }).as('getSettings');

    // Interceptar llamadas de GET profiles
    cy.intercept('GET', '**/rest/v1/profiles*', {
      statusCode: 200,
      body: { id: 'test-user-id', role: 'user' }
    }).as('profileFetch');

    // Interceptar llamadas de GET y POST user_favorites
    cy.intercept('GET', '**/rest/v1/user_favorites*', {
      statusCode: 200,
      body: []
    }).as('getFavorites');
    cy.intercept('POST', '**/rest/v1/user_favorites*', {
      statusCode: 200,
      body: {}
    }).as('postFavorites');

    // Interceptar llamadas de GET y POST user_carts
    cy.intercept('GET', '**/rest/v1/user_carts*', {
      statusCode: 200,
      body: []
    }).as('getUserCarts');
    cy.intercept('POST', '**/rest/v1/user_carts*', {
      statusCode: 200,
      body: {}
    }).as('userCartsUpsert');

    // Interceptar llamadas de POST system_logs
    cy.intercept('POST', '**/rest/v1/system_logs*', {
      statusCode: 200,
      body: {}
    }).as('systemLogs');

    // Interceptar llamadas de RPC generate_whatsapp_message
    cy.intercept('POST', '**/rest/v1/rpc/generate_whatsapp_message*', {
      statusCode: 200,
      body: JSON.stringify('Hola, me gustaría hacer un pedido:\n- 1x Funda Aura Case Magnética - iPhone 15 Pro ($14.99)')
    }).as('rpcGenerateMessage');

    // Interceptar la llamada a window.open para verificar la URL de WhatsApp generada sin salir de la página
    cy.visit('/', {
      onBeforeLoad(win) {
        cy.stub(win, 'open').as('windowOpen');
        cy.spy(win.console, 'error').as('consoleError');
        cy.spy(win.console, 'log').as('consoleLog');
        
        // Mockear sesión de usuario en sessionStorage para pasar la validación !user
        const mockUser = {
          id: 'test-user-id',
          email: 'test@example.com',
          user_metadata: { name: 'Test User', full_name: 'Test User' }
        };
        win.sessionStorage.setItem('pages_user', JSON.stringify(mockUser));
        win.sessionStorage.setItem('pages_profile', JSON.stringify({
          id: 'test-user-id',
          role: 'user'
        }));
        win.sessionStorage.setItem('pages_auth_cache_time', Date.now().toString());

        // Mockear la sesión persistente en localStorage para que Supabase no la borre al cargar
        const mockSession = {
          access_token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjk5OTk5OTk5OTksInN1YiI6InRlc3QtdXNlci1pZCIsImVtYWlsIjoidGVzdEBleGFtcGxlLmNvbSIsInJvbGUiOiJhdXRoZW50aWNhdGVkIn0.signature',
          refresh_token: 'mock-refresh-token',
          expires_in: 3600,
          expires_at: Math.floor(Date.now() / 1000) + 3600,
          token_type: 'bearer',
          user: mockUser
        };
        win.localStorage.setItem('pages-auth', JSON.stringify(mockSession));
        win.localStorage.setItem('cookie_consent', 'true');
      }
    });
  });

  afterEach(function() {
    if (this.currentTest.state === 'failed') {
      let logContent = 'TEST FAILED\n\n';
      cy.get('@consoleError').then((errorSpy) => {
        logContent += '--- CONSOLE ERRORS ---\n';
        errorSpy.args.forEach((args) => {
          logContent += args.map(a => typeof a === 'object' ? JSON.stringify(a) : a).join(' ') + '\n';
        });
        
        cy.get('@consoleLog').then((logSpy) => {
          logContent += '\n--- CONSOLE LOGS ---\n';
          logSpy.args.forEach((args) => {
            logContent += args.map(a => typeof a === 'object' ? JSON.stringify(a) : a).join(' ') + '\n';
          });
          
          cy.writeFile('cypress_console.log', logContent);
        });
      });
    }
  });

  it('debería agregar productos al carrito y generar URL de WhatsApp correctamente', () => {
    // Esperar a que los productos carguen
    cy.get('[data-testid="product-card"]').first().should('be.visible');

    // Moverse al carrito vacio
    cy.get('[data-testid="cart-button"]').click();
    cy.get('[data-testid="cart-drawer"]').should('be.visible');
    cy.get('[data-testid="cart-drawer"]').contains('vacío', { matchCase: false });
    cy.get('[data-testid="close-cart"]').click();

    // Agregar primer producto (botón de agregar)
    cy.get('[data-testid="product-card"]').first().find('button[aria-label="Añadir al carrito"]').click();
    
    // El drawer debería abrirse al agregar (o mostar toast, ajustar según UI real)
    cy.get('[data-testid="cart-button"]').click();
    cy.get('[data-testid="cart-item"]').should('have.length', 1);

    // Proceder al checkout (botón "Pedir por WhatsApp")
    cy.get('[data-testid="checkout-button"]').click();

    // Hacer clic en "Confirmar e Ir a WhatsApp"
    cy.contains('Confirmar e Ir a WhatsApp').click();

    // Test the generated URL
    cy.get('@windowOpen').should('have.been.calledTwice');
    cy.get('@windowOpen').then((stub) => {
      const calls = stub.getCalls();
      const whatsappCall = calls.find(call => call.args[0] && call.args[0].includes('whatsapp.com/send'));
      expect(whatsappCall, 'Debería haberse llamado a window.open con la URL de WhatsApp').to.not.be.undefined;
      const url = whatsappCall.args[0];
      expect(url).to.include('text=');
      // Verificar que la URL contiene "Hola" o información del pedido
      expect(decodeURIComponent(url)).to.include('Hola');
    });
  });
});
